import 'dart:io';

import 'package:dartle/dartle.dart';
import 'package:dartle/dartle_cache.dart';
import 'package:path/path.dart';

import 'config.dart';
import 'utils.dart';
import 'exec.dart';
import 'paths.dart';
import 'sub_project.dart';

const compileTaskName = 'compile';
const runTaskName = 'runJavaMainClass';
const installCompileDepsTaskName = 'installCompileDependencies';
const installRuntimeDepsTaskName = 'installRuntimeDependencies';
const writeDepsTaskName = 'writeDependencies';

Task createCompileTask(File jbuildJar, JBuildConfiguration config,
    DartleCache cache, List<SubProject> subProjects) {
  final outputs = config.output.when(dir: (d) => dir(d), jar: (j) => file(j));
  final compileRunCondition = RunOnChanges(
      inputs: dirs(config.sourceDirs, fileExtensions: const {'.java'}),
      outputs: outputs,
      cache: cache);
  return Task((_) => _compile(jbuildJar, config, subProjects),
      runCondition: compileRunCondition,
      name: compileTaskName,
      dependsOn: const {installCompileDepsTaskName},
      description: 'Compile Java source code.');
}

Future<void> _compile(File jbuildJar, JBuildConfiguration config,
    List<SubProject> subProjects) async {
  final exitCode = await execJBuild(
      jbuildJar, config.preArgs(), 'compile', config.compileArgs(subProjects));
  if (exitCode != 0) {
    throw DartleException(
        message: 'jbuild compile command failed', exitCode: exitCode);
  }
}

Task createWriteDependenciesTask(
    JBuildFiles files, JBuildConfiguration config, DartleCache cache) {
  final depsFile = dependenciesFile(files);

  final compileRunCondition = RunOnChanges(
      inputs: file(files.configFile.path),
      outputs: file(depsFile.path),
      cache: cache);

  return Task((_) => _writeDependencies(depsFile, config),
      runCondition: compileRunCondition,
      name: writeDepsTaskName,
      description: 'Write a temporary compile-time dependencies file.');
}

Future<void> _writeDependencies(
    File dependenciesFile, JBuildConfiguration config) async {
  await dependenciesFile.parent.create(recursive: true);
  await dependenciesFile.writeAsString(config.dependencies.entries
      .map((e) => e.value == DependencySpec.defaultSpec
          ? e.key
          : "${e.key}->${e.value}")
      .join('\n'));
}

Task createInstallCompileDepsTask(
    JBuildFiles files, JBuildConfiguration config, DartleCache cache) {
  return _createInstallDepsTask(
      'compile',
      installCompileDepsTaskName,
      () => _install(files.jbuildJar, config.preArgs(),
          config.installArgsForCompilation()),
      dependenciesFile(files),
      config.compileLibsDir,
      cache);
}

Task createInstallRuntimeDepsTask(
    JBuildFiles files, JBuildConfiguration config, DartleCache cache) {
  return _createInstallDepsTask(
      'runtime',
      installRuntimeDepsTaskName,
      () => _install(
          files.jbuildJar, config.preArgs(), config.installArgsForRuntime()),
      dependenciesFile(files),
      config.runtimeLibsDir,
      cache);
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

Task createRunTask(
    JBuildFiles files, JBuildConfiguration config, DartleCache cache) {
  return Task((_) => _run(files.jbuildJar, config),
      dependsOn: const {compileTaskName, installRuntimeDepsTaskName},
      name: runTaskName,
      description: 'Run Java Main class.');
}

Future<void> _run(File jbuildJar, JBuildConfiguration config) async {
  final mainClass = config.mainClass;
  if (mainClass.isEmpty) {
    throw DartleException(
        message: 'cannot run Java application as '
            'no main-class has been configured');
  }

  final separator = Platform.isWindows ? ';' : ':';
  final output = config.output.when(dir: (d) => join(d, '*'), jar: (j) => j);
  final classpath = '${join(config.runtimeLibsDir, '*')}$separator$output';

  final exitCode = await execJava(['-cp', classpath, mainClass]);

  if (exitCode != 0) {
    throw DartleException(message: 'java command failed', exitCode: exitCode);
  }
}

Future<List<SubProject>> createSubProjects(
    JBuildFiles files, JBuildConfiguration config) async {
  final pathDependencies = config.dependencies.entries
      .map((e) => e.value.toPathDependency())
      .whereNonNull()
      .toStream();

  final subProjectFactory = SubProjectFactory(files, config);

  return await subProjectFactory.createSubProjects(pathDependencies).toList();
}
