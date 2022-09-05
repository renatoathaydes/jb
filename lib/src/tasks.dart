import 'dart:io';

import 'package:dartle/dartle.dart';
import 'package:dartle/dartle_cache.dart';
import 'package:path/path.dart';

import 'config.dart';
import 'exec.dart';
import 'paths.dart';
import 'sub_project.dart';
import 'utils.dart';

const compileTaskName = 'compile';
const runTaskName = 'runJavaMainClass';
const installCompileDepsTaskName = 'installCompileDependencies';
const installRuntimeDepsTaskName = 'installRuntimeDependencies';
const writeDepsTaskName = 'writeDependencies';

Task createCompileTask(
    File jbuildJar, JBuildConfiguration config, DartleCache cache) {
  final outputs = config.output.when(dir: (d) => dir(d), jar: (j) => file(j));
  final compileRunCondition = RunOnChanges(
      inputs: dirs(config.sourceDirs, fileExtensions: const {'.java'}),
      outputs: outputs,
      cache: cache);
  return Task((_) => _compile(jbuildJar, config),
      runCondition: compileRunCondition,
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
    await File(path).copy(join(destinationDir, basename(path)));
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
    join(config.runtimeLibsDir, '*'),
    ...subProjects.map((p) => p.output.when(dir: (d) => d, jar: (j) => j))
  ].join(Platform.isWindows ? ';' : ':');

  final exitCode = await execJava(['-cp', classpath, mainClass]);

  if (exitCode != 0) {
    throw DartleException(message: 'java command failed', exitCode: exitCode);
  }
}

Future<ResolvedProjectDependencies> resolveLocalDependencies(
    JBuildFiles files, JBuildConfiguration config) async {
  final pathDependencies = config.dependencies.entries
      .map((e) => e.value.toPathDependency())
      .whereNonNull()
      .toStream();

  final subProjectFactory = SubProjectFactory(files, config);

  final projectDeps = <ProjectDependency>[];
  final jars = <JarDependency>[];

  await for (final pathDep in pathDependencies) {
    pathDep.map(jar: jars.add, jbuildProject: projectDeps.add);
  }

  final subProjects =
      await subProjectFactory.createSubProjects(projectDeps).toList();

  logger.fine(() => 'Resolved ${subProjects.length} sub-projects, '
      '${jars.length} local jar dependencies.');

  for (final subProject in subProjects) {
    subProject.output.when(
        // ignore: void_checks
        dir: (_) {
          throw UnsupportedError('Cannot depend on project ${subProject.name} '
              'because its output is not a jar!');
        },
        jar: (j) => jars.add(JarDependency(subProject.spec, j)));
  }

  return ResolvedProjectDependencies(subProjects, jars);
}
