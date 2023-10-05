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
import 'jb_files.dart';
import 'jvm_executor.dart';
import 'pom.dart';
import 'requirements.dart';
import 'resolved_dependency.dart';
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
const showJbConfigTaskName = 'showJbConfiguration';
const requirementsTaskName = 'requirements';
const createEclipseTaskName = 'createEclipseFiles';
const createPomTaskName = 'generatePom';

/// Create run condition for the `compile` task.
RunOnChanges createCompileRunCondition(
    JbConfiguration config, DartleCache cache) {
  final outputs = config.output.when(dir: (d) => dir(d), jar: (j) => file(j));
  return RunOnChanges(
      inputs: dirs(config.sourceDirs.followedBy(config.resourceDirs)),
      outputs: outputs,
      cache: cache);
}

/// Create the `compile` task.
Task createCompileTask(JbFiles jbFiles, JbConfiguration config,
    DartleCache cache, JBuildSender jBuildSender) {
  return Task(
      (List<String> args, [ChangeSet? changes]) =>
          _compile(jbFiles, config, changes, args, cache, jBuildSender),
      runCondition: createCompileRunCondition(config, cache),
      name: compileTaskName,
      argsValidator: const AcceptAnyArgs(),
      dependsOn: const {
        installCompileDepsTaskName,
        installProcessorDepsTaskName
      },
      description: 'Compile Java source code.');
}

Future<void> _compile(
    JbFiles jbFiles,
    JbConfiguration config,
    ChangeSet? changeSet,
    List<String> args,
    DartleCache cache,
    JBuildSender jBuildSender) async {
  final stopwatch = Stopwatch()..start();
  final changes =
      await computeAllChanges(changeSet, jbFiles.javaSrcFileTreeFile);
  if (changes != null) {
    logger.log(profile,
        () => 'Computed transitive changes in ${elapsedTime(stopwatch)}');
  }
  stopwatch.reset();
  final commandArgs = [
    ...await config.compileArgs(jbFiles.processorLibsDir, changes),
    ...args,
  ];
  await jBuildSender.send(RunJBuild('compile', [
    ...config.preArgs(),
    'compile',
    // the Java compiler runtime args are sent when starting the JVM
    ...commandArgs.notJavaRuntimeArgs(),
    // TODO how to honour javacEnv?
    // env: config.javacEnv
  ]));

  logger.log(
      profile, () => 'Java compilation completed in ${elapsedTime(stopwatch)}');

  stopwatch.reset();
  logger.fine('Computing Java source tree for incremental builds');
  final output = config.output.when(dir: (d) => d, jar: (j) => j);
  await storeNewFileTree(compileTaskName, config, jBuildSender, output,
      jbFiles.javaSrcFileTreeFile);
  logger.log(
      profile, () => 'Computed Java source tree in ${elapsedTime(stopwatch)}');
}

/// Create the `writeDependencies` task.
Task createWriteDependenciesTask(
    JbFiles jbFiles,
    JbConfiguration config,
    DartleCache cache,
    FileCollection jbFileInputs,
    LocalDependencies localDependencies,
    LocalDependencies localProcessorDeps) {
  final depsFile = jbFiles.dependenciesFile;
  final procDepsFile = jbFiles.processorDependenciesFile;

  final runCondition = RunOnChanges(
      inputs: jbFileInputs,
      outputs: files([depsFile.path, procDepsFile.path]),
      cache: cache);

  // don't send the full config to the Task!
  final deps = config.dependencies;
  final exclusions = config.dependencyExclusionPatterns;
  final procDeps = config.processorDependencies;
  final procExc = config.processorDependencyExclusionPatterns;

  return Task(
      (_) async => await writeDependencies(
            depsFile: depsFile,
            localDeps: localDependencies,
            deps: deps,
            localProcessorDeps: localProcessorDeps,
            exclusions: exclusions,
            processorDepsFile: procDepsFile,
            processorDeps: procDeps,
            processorsExclusions: procExc,
          ),
      runCondition: runCondition,
      name: writeDepsTaskName,
      description: 'Write files with dependencies information.');
}

/// Create the `installCompileDependencies` task.
Task createInstallCompileDepsTask(
    JbFiles files,
    JbConfiguration config,
    JBuildSender jBuildSender,
    DartleCache cache,
    ResolvedLocalDependencies localDependencies) {
  final projectDeps = localDependencies.projectDependencies
      .where((s) => s.spec.scope.includedInCompilation())
      .toList(growable: false);
  final jarDeps = localDependencies.jars
      .where((j) => j.spec.scope.includedInCompilation())
      .map((j) => j.path)
      .toList(growable: false);
  final preArgs = config.preArgs();
  final args = config.installArgsForCompilation();
  final libsDir = config.compileLibsDir;
  // can only use Sendable objects inside action
  Future<void> action(_) async {
    await _install(installCompileDepsTaskName, jBuildSender, preArgs, args);
    await _copy(projectDeps, libsDir, runtime: false);
    await _copyFiles(jarDeps, libsDir);
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
Task createInstallRuntimeDepsTask(
    JbFiles files,
    JbConfiguration config,
    JBuildSender jBuildSender,
    DartleCache cache,
    ResolvedLocalDependencies localDependencies) {
  final projectDeps = localDependencies.projectDependencies
      .where((s) => s.spec.scope.includedAtRuntime())
      .toList(growable: false);
  final jarDeps = localDependencies.jars
      .where((j) => j.spec.scope.includedAtRuntime())
      .map((j) => j.path)
      .toList(growable: false);
  Future<void> action(_) async {
    await _install(installRuntimeDepsTaskName, jBuildSender, config.preArgs(),
        config.installArgsForRuntime());
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
    JbFiles files,
    JbConfiguration config,
    JBuildSender jBuildSender,
    DartleCache cache,
    ResolvedLocalDependencies localDependencies) {
  final projectDeps = localDependencies.projectDependencies
      .where((s) => s.spec.scope.includedAtRuntime())
      .toList(growable: false);
  final jarDeps = localDependencies.jars
      .where((j) => j.spec.scope.includedAtRuntime())
      .map((j) => j.path)
      .toList(growable: false);
  Future<void> action(_) async {
    await _install(installProcessorDepsTaskName, jBuildSender, config.preArgs(),
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
    List<ResolvedProjectDependency> projectDeps,
    List<String> jarDeps,
    String libsDir,
    DartleCache cache) {
  final inputFiles = [inputFile.path];
  final inputDirs = <DirectoryEntry>[];
  for (final dep in projectDeps) {
    dep.output.when(
        dir: (d) => inputDirs
            .add(DirectoryEntry(path: p.canonicalize(p.join(dep.path, d)))),
        jar: (j) => inputFiles.add(p.canonicalize(p.join(dep.path, j))));
  }
  inputFiles.addAll(jarDeps);
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

Future<void> _install(String taskName, JBuildSender jBuildSender,
    List<String> preArgs, List<String> args) async {
  if (args.isEmpty) {
    return logger.fine("No dependencies to install for '$taskName'.");
  }
  await jBuildSender
      .send(RunJBuild('install', [...preArgs, 'install', ...args]));
}

Future<void> _copy(
    Iterable<ResolvedProjectDependency> resolvedDeps, String destinationDir,
    {required bool runtime}) async {
  if (resolvedDeps.isEmpty) return;
  await Directory(destinationDir).create(recursive: true);
  for (final dep in resolvedDeps) {
    await _copyOutput(dep.output, destinationDir);
    await _copyOutput(
        CompileOutput.dir(runtime ? dep.runtimeLibsDir : dep.compileLibsDir),
        destinationDir);
  }
}

Future<void> _copyFiles(Iterable<String> jars, String destinationDir) async {
  if (jars.isEmpty) return;
  await Directory(destinationDir).create(recursive: true);
  for (final jar in jars) {
    logger.fine(() => 'Copying $jar to $destinationDir');
    await File(jar).copy(p.join(destinationDir, p.basename(jar)));
  }
}

Future<void> _copyOutput(CompileOutput out, String destinationDir) {
  logger.fine(() => 'Copying $out to $destinationDir');
  return out.when(
      dir: (d) => Directory(d).copyContentsInto(destinationDir),
      jar: (j) => File(j).copy(p.join(destinationDir, p.basename(j))));
}

Task createEclipseTask(JbConfiguration config) {
  return Task(
      (_) async => await generateEclipseFiles(config.sourceDirs,
          config.resourceDirs, config.module, config.compileLibsDir),
      name: createEclipseTaskName,
      description: 'Generate Eclipse IDE files for the project.',
      dependsOn: const {installCompileDepsTaskName});
}

Task createGeneratePomTask(
    JbConfiguration config, ResolvedLocalDependencies localDependencies) {
  return Task(
      (List<String> args) => _pom(args, createPom(config, localDependencies)),
      name: createPomTaskName,
      phase: TaskPhase.setup,
      argsValidator: ArgsCount.range(min: 0, max: 1),
      description: 'Generate Maven POM for publishing the project. '
          'An optional argument can be used to specify the POM destination.');
}

Future<void> _pom(List<String> args, Object pom) async {
  final destination = File(args.isEmpty ? 'pom.xml' : args[0]);
  await destination.parent.create(recursive: true);
  logger.fine(() => "Writing POM to $destination");
  await destination.writeAsString(pom.toString(), flush: true);
}

/// Create the `run` task.
Task createRunTask(JbFiles files, JbConfiguration config, DartleCache cache) {
  return Task((List<String> args) => _run(files.jbuildJar, config, args),
      dependsOn: const {compileTaskName, installRuntimeDepsTaskName},
      argsValidator: const AcceptAnyArgs(),
      name: runTaskName,
      description: 'Run Java Main class.');
}

Future<void> _run(
    File jbuildJar, JbConfiguration config, List<String> args) async {
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
            'To configure one, add "main-class: your.Main" to your jb config file.');
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
Task createDownloadTestRunnerTask(JbConfiguration config,
    JBuildSender jBuildSender, DartleCache cache, FileCollection jbFileInputs) {
  return Task((_) => _downloadTestRunner(jBuildSender, config, cache),
      runCondition: RunOnChanges(
          inputs: jbFileInputs,
          outputs: dir(p.join(cache.rootDir, junitRunnerLibsDir)),
          cache: cache),
      name: downloadTestRunnerTaskName,
      description:
          'Download a test runner. JBuild automatically detects JUnit5.');
}

/// Create the `test` task.
Task createTestTask(
    File jbuildJar, JbConfiguration config, DartleCache cache, bool noColor) {
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

Future<void> _downloadTestRunner(JBuildSender jBuildSender,
    JbConfiguration config, DartleCache cache) async {
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
    await _install(downloadTestRunnerTaskName, jBuildSender, config.preArgs(),
        ['-d', outDir.path, '-m', junitConsoleLib(junit.consoleVersion)]);
  }
}

Future<void> _test(File jbuildJar, JbConfiguration config, DartleCache cache,
    bool noColor, List<String> args) async {
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
Task createDepsTask(File jbuildJar, JbConfiguration config, DartleCache cache,
    LocalDependencies localDependencies, LocalDependencies localProcessorDeps) {
  return Task(
      (List<String> args) => _deps(jbuildJar, config, cache, localDependencies,
          localProcessorDeps, args),
      name: depsTaskName,
      argsValidator: const AcceptAnyArgs(),
      phase: TaskPhase.setup,
      description: 'Shows information about project dependencies.');
}

Future<void> _deps(
    File jbuildJar,
    JbConfiguration config,
    DartleCache cache,
    LocalDependencies localDependencies,
    LocalDependencies localProcessorDependencies,
    List<String> args) async {
  final exitCode = await printDependencies(jbuildJar, config, cache,
      localDependencies, localProcessorDependencies, args);
  if (exitCode != 0) {
    throw DartleException(
        message: 'jbuild dependencies command failed', exitCode: exitCode);
  }
}

Task createShowConfigTask(JbConfiguration config, bool noColor) {
  return Task((_) => print(config.toYaml(noColor)),
      name: showJbConfigTaskName,
      phase: TaskPhase.setup,
      description: 'Shows the fully resolved jb configuration.');
}

/// Create the `requirements` task.
Task createRequirementsTask(File jbuildJar, JbConfiguration config) {
  return Task((List<String> args) => _requirements(jbuildJar, config, args),
      name: requirementsTaskName,
      argsValidator: const AcceptAnyArgs(),
      dependsOn: const {compileTaskName},
      description: 'Shows information about project requirements.');
}

Future<void> _requirements(
    File jbuildJar, JbConfiguration config, List<String> args) async {
  final out = config.output.when(dir: (dir) => dir, jar: (jar) => jar);
  final exitCode = await logRequirements(jbuildJar, config, [out, ...args]);
  if (exitCode != 0) {
    throw DartleException(
        message: 'jbuild requirements command failed', exitCode: exitCode);
  }
}
