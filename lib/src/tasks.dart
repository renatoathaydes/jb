import 'dart:io';

import 'package:dartle/dartle.dart';
import 'package:dartle/dartle_cache.dart';
import 'package:path/path.dart' as p;

import 'config.dart';
import 'exec.dart';
import 'paths.dart';

const cleanTaskName = 'clean';
const compileTaskName = 'compile';
const runTaskName = 'runJavaMainClass';
const installCompileDepsTaskName = 'installCompileDependencies';
const installRuntimeDepsTaskName = 'installRuntimeDependencies';
const writeDepsTaskName = 'writeDependencies';
const testTaskName = 'test';

const allTaskNames = {
  cleanTaskName,
  compileTaskName,
  runTaskName,
  installCompileDepsTaskName,
  installRuntimeDepsTaskName,
  writeDepsTaskName,
  testTaskName,
};

RunOnChanges createCompileRunCondition(
    JBuildConfiguration config, DartleCache cache,
    {String? rootPath}) {
  final relativize =
      rootPath == null ? (String s) => s : (String s) => p.join(rootPath, s);
  final outputs = config.output
      .when(dir: (d) => dir(relativize(d)), jar: (j) => file(relativize(j)));
  return RunOnChanges(
      inputs: dirs(config.sourceDirs.map(relativize),
          fileExtensions: const {'.java'}),
      outputs: outputs,
      cache: cache);
}

Task createCompileTask(
    File jbuildJar, JBuildConfiguration config, DartleCache cache) {
  return Task((_) => _compile(jbuildJar, config),
      runCondition: createCompileRunCondition(config, cache),
      name: compileTaskName,
      dependsOn: const {installCompileDepsTaskName},
      description: 'Compile Java source code.');
}

Future<void> _compile(File jbuildJar, JBuildConfiguration config) async {
  final exitCode = await execJBuild(
      jbuildJar, config.preArgs(), 'compile', config.compileArgs());
  if (exitCode != 0) {
    throw DartleException(
        message: 'jbuild compile command failed', exitCode: exitCode);
  }
}

Task createWriteDependenciesTask(JBuildFiles files, JBuildConfiguration config,
    DartleCache cache, List<JarDependency> jars) {
  final depsFile = dependenciesFile(files);

  final compileRunCondition = RunOnChanges(
      inputs: file(files.configFile.path),
      outputs: file(depsFile.path),
      cache: cache);

  return Task((_) => _writeDependencies(depsFile, config, jars),
      runCondition: compileRunCondition,
      name: writeDepsTaskName,
      description: 'Write a temporary compile-time dependencies file.');
}

Future<void> _writeDependencies(File dependenciesFile,
    JBuildConfiguration config, List<JarDependency> jars) async {
  await dependenciesFile.parent.create(recursive: true);
  await dependenciesFile.writeAsString(config.dependencies.entries
      .map((e) => e.value == DependencySpec.defaultSpec
          ? e.key
          : "${e.key}->${e.value}")
      .followedBy(jars.map((e) => '${e.path}->${e.spec}'))
      .join('\n'));
}

Task createInstallCompileDepsTask(JBuildFiles files, JBuildConfiguration config,
    DartleCache cache, Iterable<String> jars) {
  Future<void> action() async {
    await _install(
        files.jbuildJar, config.preArgs(), config.installArgsForCompilation());
    await _copy(jars, config.compileLibsDir);
  }

  return _createInstallDepsTask('compile', installCompileDepsTaskName, action,
      dependenciesFile(files), config.compileLibsDir, cache);
}

Task createInstallRuntimeDepsTask(JBuildFiles files, JBuildConfiguration config,
    DartleCache cache, Iterable<String> jars) {
  Future<void> action() async {
    await _install(
        files.jbuildJar, config.preArgs(), config.installArgsForRuntime());
    await _copy(jars, config.runtimeLibsDir);
  }

  return _createInstallDepsTask('runtime', installRuntimeDepsTaskName, action,
      dependenciesFile(files), config.runtimeLibsDir, cache);
}

Task _createInstallDepsTask(
    String scopeName,
    String taskName,
    Future<void> Function() action,
    File dependenciesFile,
    String libsDir,
    DartleCache cache) {
  final runCondition = RunOnChanges(
      inputs: file(dependenciesFile.path),
      outputs: dir(libsDir),
      verifyOutputsExist: false,
      cache: cache);

  return Task((_) => action(),
      runCondition: runCondition,
      dependsOn: const {writeDepsTaskName},
      name: taskName,
      description: 'Install $scopeName dependencies.');
}

Future<void> _install(
    File jbuildJar, List<String> preArgs, List<String> args) async {
  final exitCode = await execJBuild(jbuildJar, preArgs, 'install', args);
  if (exitCode != 0) {
    throw DartleException(
        message: 'jbuild install command failed', exitCode: exitCode);
  }
}

Future<void> _copy(Iterable<String> paths, String destinationDir) async {
  if (paths.isEmpty) return;
  logger.fine(() => 'Copying $paths to $destinationDir');
  await Directory(destinationDir).create(recursive: true);
  for (final path in paths) {
    await File(path).copy(p.join(destinationDir, p.basename(path)));
  }
}

Task createRunTask(JBuildFiles files, JBuildConfiguration config,
    DartleCache cache, List<SubProject> subProjects) {
  return Task((_) => _run(files.jbuildJar, config, subProjects),
      dependsOn: const {compileTaskName, installRuntimeDepsTaskName},
      name: runTaskName,
      description: 'Run Java Main class.');
}

Future<void> _run(File jbuildJar, JBuildConfiguration config,
    List<SubProject> subProjects) async {
  final mainClass = config.mainClass;
  if (mainClass.isEmpty) {
    throw DartleException(
        message: 'cannot run Java application as '
            'no main-class has been configured');
  }

  final classpath = [
    config.output.when(dir: (d) => d, jar: (j) => j),
    p.join(config.runtimeLibsDir, '*'),
    ...subProjects.map((p) => p.output.when(dir: (d) => d, jar: (j) => j))
  ].join(Platform.isWindows ? ';' : ':');

  final exitCode = await execJava(['-cp', classpath, mainClass]);

  if (exitCode != 0) {
    throw DartleException(message: 'java command failed', exitCode: exitCode);
  }
}
