import 'dart:io';

import 'package:dartle/dartle.dart';
import 'package:dartle/dartle_cache.dart';
import 'package:path/path.dart';

import 'config.dart';

Task compileTask(
    File jbuildJar, CompileConfiguration config, DartleCache cache) {
  final outputs = config.output.when(dir: (d) => dir(d), jar: (j) => file(j));
  final compileRunCondition = RunOnChanges(
      inputs: dirs(config.sourceDirs, fileExtensions: const {'.java'}),
      outputs: outputs,
      cache: cache);
  return Task((_) => _compile(jbuildJar, config),
      runCondition: compileRunCondition,
      name: 'compile',
      dependsOn: {'install'},
      description: 'Compile Java source code.');
}

Future<void> _compile(File jbuildJar, CompileConfiguration config) async {
  final exitCode = await exec(Process.start(
      'java',
      [
        '-jar',
        jbuildJar.path,
        '-q',
        ...config.preArgs(),
        'compile',
        ...config.compileArgs()
      ],
      runInShell: true));

  if (exitCode != 0) {
    throw DartleException(
        message: 'jbuild compile command failed', exitCode: exitCode);
  }
}

File _dependenciesFile(JBuildFiles files) {
  return File(join(files.tempDir.path, 'dependencies'));
}

Task writeDependenciesTask(
    JBuildFiles files, CompileConfiguration config, DartleCache cache) {
  final dependenciesFile = _dependenciesFile(files);

  final compileRunCondition = RunOnChanges(
      inputs: file(files.configFile.path),
      outputs: file(dependenciesFile.path),
      cache: cache);

  return Task((_) => _writeDependencies(dependenciesFile, config),
      runCondition: compileRunCondition,
      name: 'writeDependencies',
      description: 'Write a temporary dependencies file.');
}

Future<void> _writeDependencies(
    File dependenciesFile, CompileConfiguration config) async {
  await dependenciesFile.parent.create();
  await dependenciesFile.writeAsString(config.dependencies.keys.join(','));
}

Task installTask(
    JBuildFiles files, CompileConfiguration config, DartleCache cache) {
  final outputs = config.output.when(dir: (d) => dir(d), jar: (j) => file(j));
  final compileRunCondition = RunOnChanges(
      inputs: file(_dependenciesFile(files).path),
      outputs: outputs,
      cache: cache);

  return Task((_) => _install(files.jbuildJar, config),
      runCondition: compileRunCondition,
      dependsOn: {'writeDependencies'},
      name: 'install',
      description: 'Install dependencies.');
}

Future<void> _install(File jbuildJar, CompileConfiguration config) async {
  final exitCode = await exec(Process.start(
      'java',
      [
        '-jar',
        jbuildJar.path,
        '-q',
        ...config.preArgs(),
        'install',
        ...config.installForCompilationArgs(),
      ],
      runInShell: true));

  if (exitCode != 0) {
    throw DartleException(
        message: 'jbuild install command failed', exitCode: exitCode);
  }
}
