import 'dart:async';
import 'dart:io' hide pid;
import 'dart:isolate';

import 'package:actors/actors.dart';
import 'package:conveniently/conveniently.dart';
import 'package:dartle/dartle.dart';
import 'package:logging/logging.dart';

import 'config.dart' show logger;
import 'output_consumer.dart';
import 'utils.dart';
import 'xml_rpc.dart';

typedef JBuildSender = Sendable<JavaCommand, Object?>;

class _Proc {
  final Process _process;
  final int port;
  final String authorizationHeader;
  bool _closed = false;

  bool get isClosed => _closed;

  Future<int> get exit => _process.exitCode;

  _Proc(this._process, this.port, String token)
      : authorizationHeader = 'Bearer $token';

  bool destroy() {
    if (_closed) return false;
    _closed = true;
    return _process.kill(ProcessSignal.sigkill);
  }
}

final class _JBuildActor implements Handler<JavaCommand, Object?> {
  final String _classpath;
  final Level _level;
  final List<String> _jvmArgs;

  // initialized on demand
  Future<_JBuildRpc>? _rpc;

  _JBuildActor(this._classpath, this._level, this._jvmArgs);

  @override
  void init() {
    activateLogging(_level);
  }

  Future<_JBuildRpc> _getRpc() {
    return _rpc.vmapOr((rpc) => rpc, () => _rpc = _startRpc());
  }

  Future<_JBuildRpc> _startRpc() async {
    rpcLogger.fine(
        () => 'Starting JBuild RPC on Isolate ${Isolate.current.debugName}');

    final proc = await Process.start(
        'java',
        [
          ..._jvmArgs,
          '-cp',
          _classpath,
          'jbuild.cli.RpcMain',
          if (logger.isLoggable(Level.FINE)) '-V',
        ],
        runInShell: true,
        workingDirectory: Directory.current.path);

    final pout = proc.stdout.lines().asBroadcastStream();
    final [port, token] = await pout.take(2).toList();
    final portNumber = int.tryParse(port);
    if (portNumber == null) {
      throw DartleException(
          message: 'Could not obtain port from RpcMain JBuild Process. '
              'Expected the port number to be printed, but got: "$port"');
    }

    final perr = proc.stderr.lines();
    final stdoutLogger = _RpcExecLogger('stdout', proc.pid);
    final stderrLogger = _RpcExecLogger('stderr', proc.pid);
    pout.listen(stdoutLogger);
    perr.listen(stderrLogger);

    return _JBuildRpc(_Proc(proc, portNumber, token), stdoutLogger);
  }

  @override
  Future<Object?> handle(JavaCommand command) async {
    final rpc = await _getRpc();
    final taskName = command.taskName;
    return switch (command) {
      RunJBuild jb => rpc.runJBuild(taskName, jb.args, jb.stdoutConsumer),
      RunJava(
        classpath: var classpath,
        className: var className,
        methodName: var methodName,
        args: var args,
      ) =>
        rpc.runJava(taskName, classpath, className, methodName, args),
    };
  }

  @override
  Future<void> close() async {
    await _rpc?.vmap((f) => f.then((rpc) => rpc.stop()));
  }
}

sealed class JavaCommand {
  final String taskName;

  const JavaCommand(this.taskName);
}

final class RunJBuild extends JavaCommand {
  final List<String> args;
  final Sendable<String, void>? stdoutConsumer;

  const RunJBuild(super.taskName, this.args, [this.stdoutConsumer]);
}

final class RunJava extends JavaCommand {
  final String classpath;
  final String className;
  final String methodName;
  final List<String> args;

  const RunJava(super.taskName, this.classpath, this.className, this.methodName,
      this.args);
}

/// Create a Java [Actor] which can be used to run JBuild commands and
/// arbitrary Java methods (for jb extensions).
///
/// The Actor sender returns whatever the Java method returned.
Actor<JavaCommand, Object?> createJavaActor(
    String classpath, Level level, List<String> javaCompilerArgs) {
  return Actor.create(() => _JBuildActor(classpath, level, javaCompilerArgs));
}

class _RpcRequestMetadata {
  final int id;
  final String logPrefix;
  final Sendable<String, void>? stdoutConsumer;

  const _RpcRequestMetadata(this.id, this.logPrefix, [this.stdoutConsumer]);

  void addTo(_RpcExecLogger logger) {
    logger.metadataByTrackId[id] = this;
  }

  void removeFrom(_RpcExecLogger logger) {
    logger.metadataByTrackId.remove(id);
  }
}

/// Class executed by the _JBuildActor in its own Isolate.
class _JBuildRpc {
  final _Proc proc;
  final client = HttpClient();
  final _RpcExecLogger stdoutLogger;
  int _currentMessageIndex = -65536;

  _JBuildRpc(this.proc, this.stdoutLogger);

  /// Run a JBuild command.
  Future<void> runJBuild(String taskName, List<String> args,
      Sendable<String, void>? stdoutConsumer) async {
    final trackId = _currentMessageIndex++;
    final result = await _runJava('runJBuild', [args],
        _RpcRequestMetadata(trackId, taskName, stdoutConsumer));
    if (result is! int) {
      throw DartleException(
          message: 'JBuild did not return an integer: $result');
    }
    if (result != 0) {
      throw DartleException(
          message: 'JBuild execution failed, exit code: $result');
    }
  }

  /// Run a particular class' method with the provided arguments.
  ///
  /// The classpath should include the class and its dependencies if it's not
  /// included in the JBuild jar.
  Future<Object?> runJava(String taskName, String classpath, String className,
      String methodName, List<String> args) async {
    // This class should run the JBuild RpcMain's run method:
    //Object run(String classpath, String className, String methodName, String... args)
    return _runJava('run', [classpath, className, methodName, args],
        _RpcRequestMetadata(_currentMessageIndex++, taskName));
  }

  Future<Object?> _runJava(String methodName, List<Object> args,
      _RpcRequestMetadata requestMetadata) async {
    final req = await client.post('localhost', proc.port, '/jbuild');
    req.headers
      ..add('Content-Type', 'text/xml; charset=utf-8')
      ..add('Authorization', proc.authorizationHeader)
      ..add('Track-Id', requestMetadata.id);

    req.add(createRpcMessage(methodName, args));
    requestMetadata.addTo(stdoutLogger);

    try {
      final resp = await req.close();
      if (resp.statusCode == 200) {
        return parseRpcResponse(resp);
      }
      throw DartleException(
          message:
              'RPC request failed (code=${resp.statusCode}): ${await resp.text()}');
    } catch (e) {
      throw DartleException(message: 'RPC request failed: $e');
    } finally {
      requestMetadata.removeFrom(stdoutLogger);
    }
  }

  Future<void> stop() async {
    await _sendStopMessage();
    proc.destroy();
  }

  Future<void> _sendStopMessage() async {
    try {
      final req = await client.delete('localhost', proc.port, '/jbuild');
      req.headers.add('Authorization', proc.authorizationHeader);
      final resp = await req.close();
      rpcLogger.fine(() =>
          'RPC Server responded with ${resp.statusCode} to request to stop');
    } catch (e) {
      rpcLogger.finer(() => 'Got an expected error '
          'after stopping the RPC Server: $e');
    }
  }
}

final _trackIdPattern = RegExp(r'^(-)?\d{1,9}\s');

class _RpcExecLogger extends JbOutputConsumer {
  final String prompt;
  final Map<int, _RpcRequestMetadata> metadataByTrackId = {};

  _RpcExecLogger(this.prompt, super.pid);

  LogColor? _colorFor(Level level) {
    return switch (level) {
      Level.SEVERE => LogColor.red,
      Level.WARNING => LogColor.yellow,
      _ => null,
    };
  }

  @override
  void consume(Level Function(String) getLevel, String line) {
    var prefix = '?';
    var message = line;
    final trackIdEndIndex = _trackIdPattern.firstMatch(line)?.end;
    if (trackIdEndIndex != null) {
      final trackId = int.tryParse(line.substring(0, trackIdEndIndex - 1));
      final metadata = trackId == null ? null : metadataByTrackId[trackId];
      if (metadata != null) {
        prefix = metadata.logPrefix;
        message = line.substring(trackIdEndIndex);
        final stdoutConsumer = metadata.stdoutConsumer;
        if (stdoutConsumer != null) {
          unawaited(stdoutConsumer.send(message));
          return; // the message is not logged as it's been consumed.
        }
      }
    }
    final level = getLevel(message);
    if (!logger.isLoggable(level)) return;
    final color = _colorFor(level);
    final text = '$prefix:$prompt [jvm $pid]: $message';
    logger.log(level,
        color != null ? ColoredLogMessage(text, color) : PlainMessage(text));
  }
}
