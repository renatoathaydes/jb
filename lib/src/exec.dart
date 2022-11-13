import 'dart:io';

import 'package:dartle/dartle.dart';

import 'config.dart' show logger;

Future<int> execJBuild(String taskName, File jbuildJar, List<String> preArgs,
    String command, List<String> commandArgs) {
  return execJava(taskName, [
    '-jar',
    jbuildJar.path,
    '-q',
    ...preArgs,
    command,
    ...commandArgs,
  ]);
}

Future<int> execJava(String taskName, List<String> args) {
  final workingDir = Directory.current.path;
  logger.fine(() => '\n====> Task $taskName executing command at $workingDir\n'
      'java ${args.join(' ')}\n<=============================');
  final onStdout = _TaskExecLogger('--1>', taskName);
  final onStderr = _TaskExecLogger('--2>', taskName);
  return exec(
    Process.start('java', args, runInShell: true, workingDirectory: workingDir)
        .then((proc) {
      onStdout.pid = proc.pid;
      onStderr.pid = proc.pid;
      return proc;
    }),
    onStdoutLine: onStdout,
    onStderrLine: onStderr,
  );
}

class _TaskExecLogger {
  final String prompt;
  final String taskName;
  int pid = 0;

  _TaskExecLogger(this.prompt, this.taskName);

  void call(String line) {
    logger.info(ColoredLogMessage(
        '$prompt $taskName [java $pid]: $line', LogColor.gray));
  }
}
