import 'dart:async';
import 'dart:io' hide pid;
import 'dart:isolate';

import 'package:actors/actors.dart';
import 'package:dartle/dartle.dart';
import 'package:logging/logging.dart';
import 'package:structured_async/structured_async.dart' show FutureCancelled;

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
  final Map<String, String> _javaEnv;
  final Map<String, Future<_JBuildRpc>> _rpcByClasspath = {};

  _JBuildActor(this._classpath, this._level, this._jvmArgs, this._javaEnv);

  @override
  void init() {
    activateLogging(_level);
  }

  Future<_JBuildRpc> _getRpc(String classpath, Stopwatch stopwatch) {
    return _rpcByClasspath.update(classpath, (v) => v,
        ifAbsent: () => _startRpc(classpath, stopwatch));
  }

  Future<_JBuildRpc> _startRpc(String classpath, Stopwatch stopwatch) async {
    final args = [
      ..._jvmArgs,
      if (_classpath.isNotEmpty) ...[
        '-cp',
        _classpath.joinClasspath(classpath)
      ],
      'jbuild.cli.RpcMain',
      if (logger.isLoggable(Level.FINE)) '-V',
    ];

    rpcLogger.fine(
        () => 'Starting JBuild RPC on Isolate ${Isolate.current.debugName} '
            'with args: $args');

    final proc = await Process.start('java', args,
        runInShell: true,
        workingDirectory: Directory.current.path,
        environment: _javaEnv);

    final pout = proc.stdout.lines().asBroadcastStream();
    final lines = await pout.take(2).toList();
    final port = lines.isEmpty ? '' : lines.first;
    final token = lines.length == 2 ? lines[1] : '';
    final portNumber = int.tryParse(port);
    if (portNumber == null) {
      // could be that the JVM process failed to start, so have a look
      final exitCode =
          await proc.exitCode.timeout(Duration.zero, onTimeout: () => 0);
      if (exitCode != 0) {
        throw DartleException(
            message: 'Failed to start JVM (exit code: $exitCode). Stderr:\n'
                '${await proc.stderr.lines().join('\n')}');
      }
      throw DartleException(
          message: 'Could not obtain port from RpcMain JBuild Process. '
              'Expected the port number to be printed, but got: "$port"');
    }
    if (token.isEmpty) {
      throw DartleException(
          message: 'Could not obtain token from RpcMain JBuild Process');
    }

    stopwatch.stop();
    logger.log(
        profile,
        () => 'Initialized JVM in ${elapsedTime(stopwatch)} '
            '(classpath=$classpath)');

    final perr = proc.stderr.lines();
    final stdoutLogger = _RpcExecLogger('stdout', proc.pid);
    final stderrLogger = _RpcExecLogger('stderr', proc.pid);
    pout.listen(stdoutLogger.call);
    perr.listen(stderrLogger.call);

    return _JBuildRpc(_Proc(proc, portNumber, token), stdoutLogger);
  }

  @override
  Future<Object?> handle(JavaCommand command) async {
    final stopwatch = Stopwatch()..start();
    final rpc = await _getRpc(command.classpath, stopwatch);
    stopwatch.reset();
    stopwatch.start();
    final Future<Object?> result = _run(command, rpc);

    return result.whenComplete(() {
      logger.log(
          profile,
          () =>
              'Java command completed in ${elapsedTime(stopwatch)}: $command');
    });
  }

  @override
  Future<void> close() async {
    for (final future in _rpcByClasspath.values
        .map((f) async => (await f).stop())
        .toList(growable: false)) {
      await ignoreExceptions(() => future);
    }
    _rpcByClasspath.clear();
  }

  Future<Object?> _run(JavaCommand command, _JBuildRpc rpc) {
    final taskName = command.taskName;
    return switch (command) {
      RunJBuild jb => rpc.runJBuild(taskName, jb.args, jb.stdoutConsumer),
      RunJava(
        classpath: var classpath,
        className: var className,
        methodName: var methodName,
        args: var args,
        constructorData: var constructorData,
      ) =>
        rpc.runJava(
            taskName, classpath, className, methodName, args, constructorData),
    };
  }
}

sealed class JavaCommand {
  final String taskName;
  final String classpath;

  JavaCommand(this.taskName, this.classpath);

  @override
  String toString() {
    return 'JavaCommand{task: $taskName}';
  }
}

final class RunJBuild extends JavaCommand {
  final List<String> args;
  final Sendable<String, void>? stdoutConsumer;

  RunJBuild(String taskName, this.args, [this.stdoutConsumer])
      : super(taskName, '');
}

final class RunJava extends JavaCommand {
  final String className;
  final String methodName;
  final List<Object?> args;
  final List<Object?> constructorData;

  RunJava(super.taskName, super.classpath, this.className, this.methodName,
      this.args, this.constructorData);
}

/// Create a Java [Actor] which can be used to run JBuild commands and
/// arbitrary Java methods (for jb extensions).
///
/// The Actor sender returns whatever the Java method returned.
Actor<JavaCommand, Object?> createJavaActor(String classpath, Level level,
    List<String> javaCompilerArgs, Map<String, String> javaEnv) {
  return Actor.create(
      () => _JBuildActor(classpath, level, javaCompilerArgs, javaEnv));
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
    final Object? result;
    try {
      result = await _runJava('runJBuild', [args],
          _RpcRequestMetadata(trackId, taskName, stdoutConsumer));
    } on FutureCancelled {
      rpcLogger.fine('Jobs cancelled, forcibly stopping the Java process');
      proc.destroy();
      rethrow;
    }
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
  Future<Object?> runJava(
      String taskName,
      String classpath,
      String className,
      String methodName,
      List<Object?> args,
      List<Object?> constructorData) async {
    // This class should run the JBuild RpcMain's run method:
    // Object run(String classpath, List<?> constructorData,
    //            String className, String methodName, String... args)
    try {
      return await _runJava(
          'run',
          [classpath, constructorData, className, methodName, args],
          _RpcRequestMetadata(_currentMessageIndex++, taskName));
    } on FutureCancelled {
      rpcLogger.fine('Jobs cancelled, forcibly stopping the Java process');
      proc.destroy();
      rethrow;
    }
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
    } on DartleException {
      rethrow;
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
      rpcLogger.finer(() =>
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
