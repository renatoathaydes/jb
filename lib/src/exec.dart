import 'dart:io';

import 'package:dartle/dartle.dart';

import 'config.dart' show logger;
import 'tasks.dart';
import 'utils.dart';

/// Consumer of another process' output.
mixin ProcessOutputConsumer {
  /// The PID of the process.
  ///
  /// This is called immediately as the process starts.
  set pid(int pid);

  /// Receive a line of the process output.
  void call(String line);
}

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

class _TaskExecLogger implements ProcessOutputConsumer {
  final String prompt;
  final String taskName;
  int pid = 0;

  _TaskExecLogger(this.prompt, this.taskName);

  @override
  void call(String line) {
    logger.info(ColoredLogMessage(
        '$prompt $taskName [java $pid]: $line', LogColor.gray));
  }
}
