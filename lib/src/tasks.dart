import 'dart:io';

import 'package:dartle/dartle.dart';
import 'package:dartle/dartle_cache.dart';
import 'package:path/path.dart' as p;

import 'config.dart';
import 'dependencies.dart';
import 'eclipse.dart';
import 'exec.dart';
import 'file_tree.dart';
import 'java_tests.dart';
import 'path_dependency.dart';
import 'requirements.dart';
import 'sub_project.dart';
import 'utils.dart';

const cleanTaskName = 'clean';
const compileTaskName = 'compile';
const testTaskName = 'test';
const downloadTestRunnerTaskName = 'downloadTestRunner';
const runTaskName = 'runJavaMainClass';
const installCompileDepsTaskName = 'installCompileDependencies';
const installRuntimeDepsTaskName = 'installRuntimeDependencies';
const installProcessorDepsTaskName = 'installProcessorDependencies';
const writeDepsTaskName = 'writeDependencies';
const depsTaskName = 'dependencies';
const requirementsTaskName = 'requirements';
const createEclipseTaskName = 'createEclipseFiles';

/// Create run condition for the `compile` task.
RunOnChanges createCompileRunCondition(
    JBuildConfiguration config, DartleCache cache) {
  final outputs = config.output.when(dir: (d) => dir(d), jar: (j) => file(j));
  return RunOnChanges(
      inputs: dirs(config.sourceDirs.followedBy(config.resourceDirs)),
      outputs: outputs,
      cache: cache);
}

/// Create the `compile` task.
Task createCompileTask(
    JBuildFiles jbFiles, JBuildConfiguration config, DartleCache cache) {
  return Task(
      (List<String> args, [ChangeSet? changes]) =>
          _compile(jbFiles, config, changes, args, cache),
      runCondition: createCompileRunCondition(config, cache),
      name: compileTaskName,
      argsValidator: const AcceptAnyArgs(),
      dependsOn: const {
        installCompileDepsTaskName,
        installProcessorDepsTaskName
      },
      description: 'Compile Java source code.');
}

Future<void> _compile(JBuildFiles jbFiles, JBuildConfiguration config,
    ChangeSet? changeSet, List<String> args, DartleCache cache) async {
  final stopwatch = Stopwatch()..start();
  final changes =
      await computeAllChanges(changeSet, jbFiles.javaSrcFileTreeFile);
  if (changes != null) {
    logger.log(profile,
        () => 'Computed transitive changes in ${elapsedTime(stopwatch)}');
  }
  stopwatch.reset();
  final exitCode = await execJBuild(
      compileTaskName,
      jbFiles.jbuildJar,
      config.preArgs(),
      'compile',
      [...await config.compileArgs(jbFiles.processorLibsDir, changes), ...args],
      env: config.javacEnv);
  logger.log(
      profile, () => 'Java compilation completed in ${elapsedTime(stopwatch)}');
  if (exitCode != 0) {
    throw DartleException(
        message: 'jbuild compile command failed', exitCode: exitCode);
  }
  stopwatch.reset();
  logger.fine('Computing Java source tree for incremental builds');
  final output = config.output.when(dir: (d) => d, jar: (j) => j);
  await storeNewFileTree(compileTaskName, jbFiles.jbuildJar, config, output,
      jbFiles.javaSrcFileTreeFile);
  logger.log(
      profile, () => 'Computed Java source tree in ${elapsedTime(stopwatch)}');
}

/// Create the `writeDependencies` task.
Task createWriteDependenciesTask(
    JBuildFiles jbFiles,
    JBuildConfiguration config,
    DartleCache cache,
    LocalDependencies localDependencies) {
  final depsFile = jbFiles.dependenciesFile;
  final procDepsFile = jbFiles.processorDependenciesFile;

  final runCondition = RunOnChanges(
      inputs: file(jbFiles.configFile.path),
      outputs: files([depsFile.path, procDepsFile.path]),
      cache: cache);

  return Task(
      (_) async => await writeDependencies(
            depsFile: jbFiles.dependenciesFile,
            localDeps: localDependencies,
            deps: config.dependencies,
            exclusions: config.exclusions,
            processorDepsFile: jbFiles.processorDependenciesFile,
            processorDeps: config.processorDependencies,
            processorsExclusions: config.processorDependenciesExclusions,
          ),
      runCondition: runCondition,
      name: writeDepsTaskName,
      description: 'Write files with dependencies information.');
}

/// Create the `installCompileDependencies` task.
Task createInstallCompileDepsTask(JBuildFiles files, JBuildConfiguration config,
    DartleCache cache, LocalDependencies localDependencies) {
  final projectDeps = localDependencies.subProjects
      .where((s) => s.spec.scope.includedInCompilation())
      .toList(growable: false);
  final jarDeps = localDependencies.jars
      .where((j) => j.spec.scope.includedInCompilation())
      .toList(growable: false);

  Future<void> action(_) async {
    await _install(installCompileDepsTaskName, files.jbuildJar,
        config.preArgs(), config.installArgsForCompilation());
    await _copy(projectDeps, config.compileLibsDir, runtime: false);
    await _copyFiles(jarDeps, config.compileLibsDir);
  }

  return _createInstallDepsTask(
      installCompileDepsTaskName,
      'compile',
      action,
      files.dependenciesFile,
      projectDeps,
      jarDeps,
      config.compileLibsDir,
      cache);
}

/// Create the `installRuntimeDependencies` task.
Task createInstallRuntimeDepsTask(JBuildFiles files, JBuildConfiguration config,
    DartleCache cache, LocalDependencies localDependencies) {
  final projectDeps = localDependencies.subProjects
      .where((s) => s.spec.scope.includedAtRuntime())
      .toList(growable: false);
  final jarDeps = localDependencies.jars
      .where((j) => j.spec.scope.includedAtRuntime())
      .toList(growable: false);
  Future<void> action(_) async {
    await _install(installRuntimeDepsTaskName, files.jbuildJar,
        config.preArgs(), config.installArgsForRuntime());
    await _copy(projectDeps, config.runtimeLibsDir, runtime: true);
    await _copyFiles(jarDeps, config.runtimeLibsDir);
  }

  return _createInstallDepsTask(
      installRuntimeDepsTaskName,
      'runtime',
      action,
      files.dependenciesFile,
      projectDeps,
      jarDeps,
      config.runtimeLibsDir,
      cache);
}

/// Create the `installProcessorDependencies` task.
Task createInstallProcessorDepsTask(
    JBuildFiles files,
    JBuildConfiguration config,
    DartleCache cache,
    LocalDependencies localDependencies) {
  final projectDeps = localDependencies.subProjects
      .where((s) => s.spec.scope.includedAtRuntime())
      .toList(growable: false);
  final jarDeps = localDependencies.jars
      .where((j) => j.spec.scope.includedAtRuntime())
      .toList(growable: false);
  Future<void> action(_) async {
    await _install(
        installProcessorDepsTaskName,
        files.jbuildJar,
        config.preArgs(),
        config.installArgsForProcessor(files.processorLibsDir));
    await _copy(projectDeps, files.processorLibsDir, runtime: true);
    await _copyFiles(jarDeps, files.processorLibsDir);
  }

  return _createInstallDepsTask(
      installProcessorDepsTaskName,
      'annotation processor',
      action,
      files.processorDependenciesFile,
      projectDeps,
      jarDeps,
      files.processorLibsDir,
      cache);
}

Task _createInstallDepsTask(
    String taskName,
    String scopeName,
    Future<void> Function(List<String>) action,
    File inputFile,
    List<SubProject> subProjects,
    List<JarDependency> jarDeps,
    String libsDir,
    DartleCache cache) {
  final inputFiles = [inputFile.path];
  final inputDirs = <DirectoryEntry>[];
  for (final subProject in subProjects) {
    subProject.config.output.when(
        dir: (d) =>
            inputDirs.add(DirectoryEntry(path: p.join(subProject.path, d))),
        jar: (j) => inputFiles.add(p.join(subProject.path, j)));
  }
  for (final jar in jarDeps) {
    inputFiles.add(jar.path);
  }
  final runCondition = RunOnChanges(
      inputs: entities(inputFiles, inputDirs),
      outputs: dir(libsDir),
      verifyOutputsExist: false, // maybe nothing to install
      cache: cache);

  return Task(action,
      runCondition: runCondition,
      dependsOn: const {writeDepsTaskName},
      name: taskName,
      description: 'Install $scopeName dependencies.');
}

Future<void> _install(String taskName, File jbuildJar, List<String> preArgs,
    List<String> args) async {
  if (args.isEmpty) {
    return logger.fine("No dependencies to install for '$taskName'.");
  }
  final exitCode =
      await execJBuild(taskName, jbuildJar, preArgs, 'install', args);
  if (exitCode != 0) {
    throw DartleException(
        message: 'jbuild install command failed', exitCode: exitCode);
  }
}

Future<void> _copy(Iterable<SubProject> subProjects, String destinationDir,
    {required bool runtime}) async {
  if (subProjects.isEmpty) return;
  await Directory(destinationDir).create(recursive: true);
  for (final sub in subProjects) {
    await _copyOutput(sub.config.output, sub.path, destinationDir);
    await _copyOutput(
        CompileOutput.dir(
            runtime ? sub.config.runtimeLibsDir : sub.config.compileLibsDir),
        sub.path,
        destinationDir);
  }
}

Future<void> _copyFiles(
    Iterable<JarDependency> jars, String destinationDir) async {
  if (jars.isEmpty) return;
  await Directory(destinationDir).create(recursive: true);
  for (final jar in jars) {
    logger.fine(() => 'Copying ${jar.path} to $destinationDir');
    await File(jar.path).copy(p.join(destinationDir, p.basename(jar.path)));
  }
}

Future<void> _copyOutput(
    CompileOutput out, String subProjectDir, String destinationDir) {
  logger.fine(() => 'Copying $subProjectDir:$out to $destinationDir');
  return out.when(
      dir: (d) =>
          Directory(p.join(subProjectDir, d)).copyContentsInto(destinationDir),
      jar: (j) => File(p.join(subProjectDir, j))
          .copy(p.join(destinationDir, p.basename(j))));
}

Task createEclipseTask(JBuildConfiguration config) {
  return Task(
      (_) async => await generateEclipseFiles(config.sourceDirs,
          config.resourceDirs, config.module, config.compileLibsDir),
      name: createEclipseTaskName,
      description: 'Generate Eclipse IDE files for the project.',
      dependsOn: const {installCompileDepsTaskName});
}

/// Create the `run` task.
Task createRunTask(
    JBuildFiles files, JBuildConfiguration config, DartleCache cache) {
  return Task((List<String> args) => _run(files.jbuildJar, config, args),
      dependsOn: const {compileTaskName, installRuntimeDepsTaskName},
      argsValidator: const AcceptAnyArgs(),
      name: runTaskName,
      description: 'Run Java Main class.');
}

Future<void> _run(
    File jbuildJar, JBuildConfiguration config, List<String> args) async {
  var mainClass = config.mainClass ?? '';
  if (mainClass.isEmpty) {
    const mainClassArg = '--main-class=';
    final mainClassArgIndex =
        args.indexWhere((arg) => arg.startsWith(mainClassArg));
    if (mainClassArgIndex >= 0) {
      mainClass =
          args.removeAt(mainClassArgIndex).substring(mainClassArg.length);
    }
  }
  if (mainClass.isEmpty) {
    throw DartleException(
        message: 'cannot run Java application as '
            'no main-class has been configured or provided.\n'
            'To configure one, add "main-class: your.Main" to your jbuild.yaml file.');
  }

  final classpath = {
    config.output.when(dir: (d) => d, jar: (j) => j),
    config.runtimeLibsDir,
    p.join(config.runtimeLibsDir, '*'),
  }.join(classpathSeparator);

  final exitCode = await execJava(runTaskName,
      [...config.runJavaArgs, '-cp', classpath, mainClass, ...args],
      env: config.runJavaEnv);

  if (exitCode != 0) {
    throw DartleException(message: 'java command failed', exitCode: exitCode);
  }
}

/// Create the `downloadTestRunner` task.
Task createDownloadTestRunnerTask(
    File jbuildJar, JBuildConfiguration config, DartleCache cache) {
  return Task((_) => _downloadTestRunner(jbuildJar, config, cache),
      runCondition: RunOnChanges(
          inputs: file('jbuild.yaml'),
          outputs: dir(p.join(cache.rootDir, junitRunnerLibsDir)),
          cache: cache),
      name: downloadTestRunnerTaskName,
      description:
          'Download a test runner. JBuild automatically detects JUnit5.');
}

/// Create the `test` task.
Task createTestTask(File jbuildJar, JBuildConfiguration config,
    DartleCache cache, bool noColor) {
  return Task(
      (List<String> args) => _test(jbuildJar, config, cache, noColor, args),
      name: testTaskName,
      argsValidator: const AcceptAnyArgs(),
      dependsOn: const {
        compileTaskName,
        downloadTestRunnerTaskName,
        installRuntimeDepsTaskName,
      },
      description: 'Run tests. JBuild automatically detects JUnit5.');
}

Future<void> _downloadTestRunner(
    File jbuildJar, JBuildConfiguration config, DartleCache cache) async {
  final junit = findJUnitSpec(config.dependencies);
  if (junit == null) {
    throw DartleException(
        message: 'cannot run tests as no test libraries have been detected.\n'
            'To use JUnit, for example, add the JUnit API as a dependency:\n'
            '    - "org.junit.jupiter:junit-jupiter-api"');
  }
  final outDir = Directory(p.join(cache.rootDir, junitRunnerLibsDir));
  await outDir.create();
  if (junit.runtimeIncludesJUnitConsole) {
    await File(p.join(outDir.path, '.no-dependencies')).create();
  } else {
    await _install(downloadTestRunnerTaskName, jbuildJar, config.preArgs(),
        ['-d', outDir.path, '-m', junitConsoleLib(junit.consoleVersion)]);
  }
}

Future<void> _test(File jbuildJar, JBuildConfiguration config,
    DartleCache cache, bool noColor, List<String> args) async {
  final libs = Directory(config.runtimeLibsDir).list();
  final classpath = {
    config.output.when(dir: (d) => d, jar: (j) => j),
    config.runtimeLibsDir,
    await for (final lib in libs)
      if (p.extension(lib.path) == '.jar') lib.path,
  }.join(classpathSeparator);

  const mainClass = 'org.junit.platform.console.ConsoleLauncher';
  if (mainClass.isEmpty) {
    throw DartleException(
        message: 'cannot run tests as no test libraries have been detected'
            'no main-class has been configured');
  }

  final hasCustomSelect = args.any((arg) =>
      arg.startsWith('--select') || arg.startsWith('--scan-classpath'));

  final exitCode = await execJava(
      testTaskName,
      [
        ...config.testJavaArgs,
        '-ea',
        '-cp',
        '${cache.rootDir}/$junitRunnerLibsDir/*',
        mainClass,
        '--classpath=$classpath',
        if (!hasCustomSelect)
          '--scan-classpath=${config.output.when(dir: (d) => d, jar: (j) => j)}',
        '--reports-dir=${config.testReportsDir}',
        '--fail-if-no-tests',
        if (noColor) '--disable-ansi-colors',
        ...args,
      ],
      env: config.testJavaEnv);

  if (exitCode != 0) {
    throw DartleException(message: 'test command failed', exitCode: exitCode);
  }
}

/// Create the `dependencies` task.
Task createDepsTask(File jbuildJar, JBuildConfiguration config,
    DartleCache cache, LocalDependencies localDependencies, bool noColor) {
  return Task(
      (List<String> args) =>
          _deps(jbuildJar, config, cache, localDependencies, noColor, args),
      name: depsTaskName,
      argsValidator: const AcceptAnyArgs(),
      phase: TaskPhase.setup,
      description: 'Shows information about project dependencies.');
}

Future<void> _deps(
    File jbuildJar,
    JBuildConfiguration config,
    DartleCache cache,
    LocalDependencies localDependencies,
    bool noColor,
    List<String> args) async {
  final exitCode = await printDependencies(
      jbuildJar, config, cache, localDependencies, noColor, args);
  if (exitCode != 0) {
    throw DartleException(
        message: 'jbuild dependencies command failed', exitCode: exitCode);
  }
}

/// Create the `requirements` task.
Task createRequirementsTask(File jbuildJar, JBuildConfiguration config,
    DartleCache cache, LocalDependencies localDependencies, bool noColor) {
  return Task(
      (List<String> args) => _requirements(
          jbuildJar, config, cache, localDependencies, noColor, args),
      name: requirementsTaskName,
      argsValidator: const AcceptAnyArgs(),
      dependsOn: const {compileTaskName},
      description: 'Shows information about project requirements.');
}

Future<void> _requirements(
    File jbuildJar,
    JBuildConfiguration config,
    DartleCache cache,
    LocalDependencies localDependencies,
    bool noColor,
    List<String> args) async {
  final out = config.output.when(dir: (dir) => dir, jar: (jar) => jar);
  final exitCode = await logRequirements(jbuildJar, config, [out, ...args]);
  if (exitCode != 0) {
    throw DartleException(
        message: 'jbuild requirements command failed', exitCode: exitCode);
  }
}
