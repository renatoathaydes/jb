import 'dart:io';

import 'package:dartle/dartle.dart';
import 'package:dartle/dartle_cache.dart';
import 'package:dartle/dartle_dart.dart';
import 'package:jbuild_cli/src/config.dart';

Future<Task> compileTask(
    File jbuildJar, CompileConfiguration config, DartleCache cache) async {
  final outputs = config.output.when(dir: (d) => dir(d), jar: (j) => file(j));
  final compileRunCondition = RunOnChanges(
      inputs: dirs(config.sourceDirs, fileExtensions: const {'.java'}),
      outputs: outputs,
      cache: cache);
  return Task((_) => _compile(jbuildJar, config),
      runCondition: compileRunCondition,
      name: 'compile',
      description: 'Compile Java source code.');
}

Future<Never> _compile(File jbuildJar, CompileConfiguration config) async {
  return exit(await exec(Process.start(
      'java', ['-jar', jbuildJar.path, 'compile', ...config.asArgs()],
      runInShell: true)));
}
