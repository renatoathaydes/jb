import 'dart:io';

import 'package:dartle/dartle.dart';
import 'config.dart' show logger;

Future<int> execJBuild(File jbuildJar, List<String> preArgs, String command,
    List<String> commandArgs) {
  return execJava([
    '-jar',
    jbuildJar.path,
    '-q',
    ...preArgs,
    command,
    ...commandArgs,
  ]);
}

Future<int> execJava(List<String> args) {
  logger.fine(() => 'Executing java $args');
  return exec(Process.start('java', args, runInShell: true));
}
