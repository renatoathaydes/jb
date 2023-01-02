import 'dart:io';

import 'package:dartle/dartle.dart';
import 'package:logging/logging.dart';

import 'config.dart' show logger;
import 'output_consumer.dart';
import 'tasks.dart';
import 'utils.dart';

/// Execute the jbuild tool.
Future<int> execJBuild(String taskName, File jbuildJar, List<String> preArgs,
    String command, List<String> commandArgs,
    {ProcessOutputConsumer? onStdout,
    ProcessOutputConsumer? onStderr,
    Map<String, String> env = const {}}) {
  return execJava(
      taskName,
      [
        ...commandArgs.javaRuntimeArgs(),
        '-jar',
        jbuildJar.path,
        '-q',
        ...preArgs,
        command,
        ...commandArgs.notJavaRuntimeArgs(),
      ],
      onStdout: onStdout,
      onStderr: onStderr,
      env: env);
}

/// Execute a java process.
Future<int> execJava(String taskName, List<String> args,
    {ProcessOutputConsumer? onStdout,
    ProcessOutputConsumer? onStderr,
    Map<String, String> env = const {}}) {
  final workingDir = Directory.current.path;
  logger.fine(() => '\n====> Task $taskName executing command at $workingDir\n'
      'java ${args.join(' ')}\n<=============================');

  // the test task must print to stdout/err directly
  if (taskName == testTaskName) {
    return exec(Process.start('java', args,
        environment: env, runInShell: true, workingDirectory: workingDir));
  }
  final stdoutFun = onStdout ?? _TaskExecLogger('-out>', taskName);
  final stderrFun = onStderr ?? _TaskExecLogger('-err>', taskName);
  return exec(
    Process.start('java', args,
            runInShell: true, environment: env, workingDirectory: workingDir)
        .then((proc) {
      stdoutFun.pid = proc.pid;
      stderrFun.pid = proc.pid;
      return proc;
    }),
    onStdoutLine: stdoutFun,
    onStderrLine: stderrFun,
  );
}

class _TaskExecLogger extends JbOutputConsumer {
  final String prompt;
  final String taskName;

  _TaskExecLogger(this.prompt, this.taskName);

  LogColor? _colorFor(Level level) {
    if (level == Level.SEVERE) return LogColor.red;
    if (level == Level.WARNING) return LogColor.yellow;
    return null;
  }

  @override
  Object createMessage(Level level, String line) {
    final color = _colorFor(level);
    final message = '$prompt $taskName [java $pid]: $line';
    if (color != null) {
      return ColoredLogMessage(message, color);
    }
    return PlainMessage(message);
  }
}
