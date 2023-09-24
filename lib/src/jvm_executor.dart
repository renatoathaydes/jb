import 'dart:async';
import 'dart:io' hide pid;
import 'dart:isolate';

import 'package:actors/actors.dart';
import 'package:conveniently/conveniently.dart';
import 'package:dartle/dartle.dart';
import 'package:logging/logging.dart';

import 'output_consumer.dart';
import 'utils.dart';
import 'xml_rpc.dart';

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

  // initialized on demand
  Future<_JBuildRpc>? _rpc;

  _JBuildActor(this._classpath, this._level);

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
        'java', ['-cp', _classpath, 'jbuild.cli.RpcMain'],
        runInShell: true, workingDirectory: Directory.current.path);

    final pout = proc.stdout.lines().asBroadcastStream();
    final [port, token] = await pout.take(2).toList();
    final portNumber = int.tryParse(port);
    if (portNumber == null) {
      throw DartleException(
          message: 'Could not obtain port from RpcMain JBuild Process. '
              'Expected the port number to be printed, but got: "$port"');
    }

    final perr = proc.stderr.lines();
    pout.listen(_RpcExecLogger('out>', 'remoteRunner', proc.pid));
    perr.listen(_RpcExecLogger('err>', 'remoteRunner', proc.pid));

    return _JBuildRpc(_Proc(proc, portNumber, token));
  }

  @override
  Future<Object?> handle(JavaCommand command) async {
    final rpc = await _getRpc();
    return switch (command) {
      RunJBuild jb => rpc.runJBuild(jb.args),
      RunJava(
        classpath: var classpath,
        className: var className,
        methodName: var methodName,
        args: var args,
      ) =>
        rpc.runJava(classpath, className, methodName, args),
    };
  }

  @override
  Future<void> close() async {
    await _rpc?.vmap((f) => f.then((rpc) => rpc.stop()));
  }
}

sealed class JavaCommand {
  const JavaCommand();
}

final class RunJBuild extends JavaCommand {
  final List<String> args;

  const RunJBuild(this.args);
}

final class RunJava extends JavaCommand {
  final String classpath;
  final String className;
  final String methodName;
  final List<String> args;

  const RunJava(this.classpath, this.className, this.methodName, this.args);
}

/// Create a Java [Actor] which can be used to run JBuild commands and
/// arbitrary Java methods (for jb extensions).
///
/// The Actor sender returns whatever the Java method returned.
Actor<JavaCommand, Object?> createJavaActor(String classpath, Level level) {
  return Actor.create(() => _JBuildActor(classpath, level));
}

/// Class executed by the _JBuildActor in its own Isolate.
class _JBuildRpc {
  final _Proc proc;
  final client = HttpClient();

  _JBuildRpc(this.proc);

  /// Run a JBuild command.
  Future<void> runJBuild(List<String> args) async {
    final result = await _runJava('runJBuild', [args]);
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
  Future<Object?> runJava(String classpath, String className, String methodName,
      List<String> args) async {
    // This class should run the JBuild RpcMain's run method:
    //Object run(String classpath, String className, String methodName, String... args)
    return _runJava('run', [classpath, className, methodName, args]);
  }

  Future<Object?> _runJava(String methodName, List<Object> args) async {
    final req = await client.post('localhost', proc.port, '/jbuild');
    req.headers.add('Content-Type', 'text/xml; charset=utf-8');
    req.headers.add('Authorization', proc.authorizationHeader);
    req.add(createRpcMessage(methodName, args));
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
      rpcLogger
          .fine(() => 'A problem occurred trying to stop the RPC Server: $e');
    }
  }
}

class _RpcExecLogger extends JbOutputConsumer {
  final String prompt;
  final String taskName;

  _RpcExecLogger(this.prompt, this.taskName, super.pid);

  LogColor? _colorFor(Level level) {
    if (level == Level.SEVERE) return LogColor.red;
    if (level == Level.WARNING) return LogColor.yellow;
    return null;
  }

  @override
  Object createMessage(Level level, String line) {
    final message = '$prompt $taskName [jvm-rpc $pid]: $line';
    final color = _colorFor(level);
    if (color != null) {
      return ColoredLogMessage(message, color);
    }
    return PlainMessage(message);
  }
}
