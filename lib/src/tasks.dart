import 'dart:io';

import 'package:conveniently/conveniently.dart';
import 'package:dartle/dartle.dart';
import 'package:dartle/dartle_cache.dart' show DartleCache;
import 'package:path/path.dart' as p;

import 'compile/compile.dart';
import 'compute_compilation_path.dart' as cp;
import 'config.dart';
import 'dependencies/deps_cache.dart';
import 'dependencies/printer.dart';
import 'dependencies/writer.dart';
import 'deps.dart';
import 'eclipse.dart';
import 'exec.dart';
import 'file_tree.dart';
import 'java_tests.dart';
import 'jb_files.dart';
import 'jbuild_update.dart';
import 'jshell.dart';
import 'jvm_executor.dart';
import 'optional_arg_validator.dart';
import 'pom.dart';
import 'publish.dart';
import 'requirements.dart';
import 'resolved_dependency.dart';
import 'run_conditions.dart';
import 'utils.dart';

const cleanTaskName = 'clean';
const compileTaskName = 'compile';
const publicationCompileTaskName = 'publicationCompile';
const testTaskName = 'test';
const downloadTestRunnerTaskName = 'downloadTestRunner';
const runTaskName = 'runJavaMainClass';
const jshellTaskName = 'jshell';
const installCompileDepsTaskName = 'installCompileDependencies';
const installRuntimeDepsTaskName = 'installRuntimeDependencies';
const installProcessorDepsTaskName = 'installProcessorDependencies';
const createJavaCompilationPathTaskName = 'createJavaCompilationPath';
const writeDepsTaskName = 'writeDependencies';
const verifyDepsTaskName = 'verifyDependencies';
const depsTaskName = 'dependencies';
const showJbConfigTaskName = 'showJbConfiguration';
const requirementsTaskName = 'requirements';
const createEclipseTaskName = 'createEclipseFiles';
const createPomTaskName = 'generatePom';
const publishTaskName = 'publish';
const updateJBuildTaskName = 'updateJBuild';

final depsPhase = TaskPhase.custom(TaskPhase.setup.index + 1, 'deps');
final evaluatePhase = TaskPhase.custom(TaskPhase.build.index + 10, 'evaluate');

const _reasonPublicationCompileCannotRun =
    'Cannot publish project because "output-jar" is not configured. '
    'Replace "output-dir" with "output-jar" to publish.';

final publishPhase = TaskPhase.custom(evaluatePhase.index + 10, 'publish');

/// Create run condition for the `compile` task.
RunOnChanges _createCompileRunCondition(
  JbConfigContainer configContainer,
  DartleCache cache,
) {
  final config = configContainer.config;
  final outputs = configContainer.output.when(
    dir: (d) => dir(d),
    jar: (j) => file(j),
  );
  return RunOnChanges(
    inputs: dirs(config.sourceDirs.followedBy(config.resourceDirs)),
    outputs: outputs,
    cache: cache,
  );
}

RunCondition _createPublicationCompileRunCondition(
  JbConfigContainer configContainer,
  DartleCache cache,
) {
  final config = configContainer.config;
  return configContainer.output.when(
    dir: (d) => const CannotRun(_reasonPublicationCompileCannotRun),
    jar: (jar) => RunOnChanges(
      inputs: dirs(config.sourceDirs.followedBy(config.resourceDirs)),
      outputs: files([
        jar,
        jar.replaceExtension('-sources.jar'),
        jar.replaceExtension('-javadoc.jar'),
      ]),
      cache: cache,
    ),
  );
}

/// Create the `compile` task.
Task createCompileTask(
  JbFiles jbFiles,
  JbConfigContainer config,
  DartleCache cache,
  JBuildSender jBuildSender,
) {
  final workingDir = Directory.current.path;
  return Task(
    (List<String> args, [ChangeSet? changes]) => _compile(
      jbFiles,
      config,
      workingDir,
      changes,
      args,
      cache,
      jBuildSender,
    ),
    runCondition: _createCompileRunCondition(config, cache),
    name: compileTaskName,
    argsValidator: const AcceptAnyArgs(),
    dependsOn: const {
      createJavaCompilationPathTaskName,
      installProcessorDepsTaskName,
    },
    description: 'Compile Java source code.',
  );
}

/// Create the publicationCompile task.
Task createPublicationCompileTask(
  JbFiles jbFiles,
  JbConfigContainer config,
  DartleCache cache,
  JBuildSender jBuildSender,
) {
  final workingDir = Directory.current.path;
  return Task(
    (List<String> args) =>
        _publishCompile(jbFiles, config, workingDir, args, cache, jBuildSender),
    runCondition: _createPublicationCompileRunCondition(config, cache),
    name: publicationCompileTaskName,
    argsValidator: const AcceptAnyArgs(),
    dependsOn: const {installCompileDepsTaskName, installProcessorDepsTaskName},
    description: 'Compile Java source code, javadocs and sources jar.',
  );
}

Future<void> _publishCompile(
  JbFiles jbFiles,
  JbConfigContainer config,
  String workingDir,
  List<String> args,
  DartleCache cache,
  JBuildSender jBuildSender,
) async {
  config.output.when(
    dir: (_) => failBuild(reason: _reasonPublicationCompileCannotRun),
    jar: (_) => null,
  );
  await _compile(
    jbFiles,
    config,
    workingDir,
    null,
    args,
    cache,
    jBuildSender,
    publication: true,
  );
}

Future<void> _compile(
  JbFiles jbFiles,
  JbConfigContainer configContainer,
  String workingDir,
  ChangeSet? changeSet,
  List<String> args,
  DartleCache cache,
  JBuildSender jBuildSender, {
  bool publication = false,
}) async {
  final config = configContainer.config;
  final stopwatch = Stopwatch()..start();
  final changes = await computeAllChanges(
    changeSet,
    jbFiles.javaSrcFileTreeFile,
  );
  if (changes != null) {
    logger.log(
      profile,
      () =>
          'Computed transitive changes in '
          '${elapsedTime(stopwatch)}: $changes',
    );
  }
  stopwatch.reset();
  final isGroovyEnabled =
      configContainer.knownDeps.groovy ||
      configContainer.testConfig.spockVersion != null;
  await jBuildSender.send(
    await compileCommand(
      jbFiles,
      config,
      isGroovyEnabled,
      workingDir,
      publication,
      changes,
      args,
    ),
  );

  logger.log(
    profile,
    () => 'Java compilation completed in ${elapsedTime(stopwatch)}',
  );

  stopwatch.reset();
  logger.fine('Computing Java source tree for incremental builds');
  final output = configContainer.output.when(dir: (d) => d, jar: (j) => j);
  await storeNewFileTree(
    compileTaskName,
    config,
    workingDir,
    jBuildSender,
    output,
    jbFiles.javaSrcFileTreeFile,
  );
  logger.log(
    profile,
    () => 'Computed Java source tree in ${elapsedTime(stopwatch)}',
  );
}

/// Create the `writeDependencies` task.
Task createWriteDependenciesTask(
  JbFiles jbFiles,
  JbConfiguration config,
  ResolvedLocalDependencies localDependencies,
  ResolvedLocalDependencies localProcessorDependencies,
  DepsCache depsCache,
  DartleCache cache,
  FileCollection jbFileInputs,
  JBuildSender jbuildSender,
) {
  final nonLocalDeps = Map.fromEntries(
    config.allDependencies.where((d) => d.value.path == null),
  );
  final nonLocalProcDeps = Map.fromEntries(
    config.allProcessorDependencies.where((d) => d.value.path == null),
  );
  final preArgs = config.preArgs(Directory.current.path);
  final exclusions = config.dependencyExclusionPatterns.toSet();
  final procExclusions = config.processorDependencyExclusionPatterns.toSet();
  final runCondition = RunOnChanges(
    inputs: jbFileInputs,
    outputs: files([
      jbFiles.dependenciesFile.path,
      jbFiles.processorDependenciesFile.path,
      jbFiles.testRunnerDependenciesFile.path,
    ]),
    cache: cache,
  );
  return Task(
    (args) async => await writeDependencies(
      jbuildSender,
      preArgs,
      jbFiles,
      depsCache,
      cache,
      exclusions,
      procExclusions,
      args,
      nonLocalDeps: nonLocalDeps,
      nonLocalProcDeps: nonLocalProcDeps,
      localDeps: localDependencies,
      localProcDeps: localProcessorDependencies,
    ),
    runCondition: runCondition,
    name: writeDepsTaskName,
    phase: depsPhase,
    description: 'Write resolved dependencies files.',
  );
}

Task createVerifyDependenciesTask(
  JbFiles jbFiles,
  DepsCache depsCache,
  DartleCache cache,
) {
  const link =
      'https://renatoathaydes.github.io/jb/pages/dependency-management.html';
  return Task(
    (List<String> _) async {
      final deps = await depsCache.send(GetDeps(jbFiles.dependenciesFile.path));
      final procDeps = await depsCache.send(
        GetDeps(jbFiles.processorDependenciesFile.path),
      );

      if (procDeps.warnings.isNotEmpty) {
        logger.warning(
          'Annotation Processor dependencies contains version conflicts',
        );
      }
      for (final (deps, forProcessor) in [(deps, false), (procDeps, true)]) {
        if (deps.warnings.isNotEmpty) {
          if (deps.warnings.isNotEmpty) {
            final prefix = forProcessor ? 'Annotation Processor' : 'Project';
            logger.warning('$prefix dependencies are problematic.');
          }
          printDepWarnings(deps);
          failBuild(
            reason:
                'Dependency graph contains version conflicts (see above)!\n'
                'You need to fix the conflicts as explained at $link',
          );
        }
      }
    },
    name: verifyDepsTaskName,
    runCondition: RunOnChanges(
      inputs: files([
        jbFiles.dependenciesFile.path,
        jbFiles.processorDependenciesFile.path,
      ]),
      cache: cache,
    ),
    dependsOn: {writeDepsTaskName},
    description:
        'Fails the build if dependency version conflicts are detected.',
  );
}

/// Create the `installCompileDependencies` task.
Task createInstallCompileDepsTask(
  JbFiles files,
  JbConfiguration config,
  JBuildSender jBuildSender,
  DepsCache depsCache,
  DartleCache cache,
  ResolvedLocalDependencies localDependencies,
) {
  final projectDeps = localDependencies.projectDependencies
      .where((s) => s.spec.scope.includedInCompilation())
      .toList(growable: false);
  final jarDeps = localDependencies.jars
      .where((j) => j.spec.scope.includedInCompilation())
      .map((j) => j.path)
      .toList(growable: false);
  final depsFile = files.dependenciesFile.path;
  final preArgs = config.preArgs(Directory.current.path);
  final libsDir = config.compileLibsDir;

  // can only use Sendable objects inside action
  Future<void> action(_) async {
    final deps = FileDependencies(
      File(depsFile),
      depsCache,
      (scope) => scope.includedInCompilation(),
    );
    await _install(
      installCompileDepsTaskName,
      jBuildSender,
      preArgs,
      deps,
      libsDir,
    );
    await _copy(projectDeps, libsDir, runtime: false);
    await _copyFiles(jarDeps, libsDir);
  }

  return _createInstallDepsTask(
    installCompileDepsTaskName,
    'compile',
    action,
    depsFile,
    projectDeps,
    jarDeps,
    config.compileLibsDir,
    cache,
  );
}

/// Create the `installRuntimeDependencies` task.
Task createInstallRuntimeDepsTask(
  JbFiles files,
  JbConfiguration config,
  JBuildSender jBuildSender,
  DepsCache depsCache,
  DartleCache cache,
  ResolvedLocalDependencies localDependencies,
) {
  final projectDeps = localDependencies.projectDependencies
      .where((s) => s.spec.scope.includedAtRuntime())
      .toList(growable: false);
  final jarDeps = localDependencies.jars
      .where((j) => j.spec.scope.includedAtRuntime())
      .map((j) => j.path)
      .toList(growable: false);
  final depsFile = files.dependenciesFile.path;
  final preArgs = config.preArgs(Directory.current.path);
  final runtimeLibsDir = config.runtimeLibsDir;
  Future<void> action(_) async {
    final deps = FileDependencies(
      File(depsFile),
      depsCache,
      (scope) => scope.includedAtRuntime(),
    );
    await _install(
      installRuntimeDepsTaskName,
      jBuildSender,
      preArgs,
      deps,
      runtimeLibsDir,
    );
    await _copy(projectDeps, runtimeLibsDir, runtime: true);
    await _copyFiles(jarDeps, runtimeLibsDir);
  }

  return _createInstallDepsTask(
    installRuntimeDepsTaskName,
    'runtime',
    action,
    depsFile,
    projectDeps,
    jarDeps,
    config.runtimeLibsDir,
    cache,
  );
}

/// Create the `installProcessorDependencies` task.
Task createInstallProcessorDepsTask(
  JbFiles files,
  JbConfiguration config,
  JBuildSender jBuildSender,
  DepsCache depsCache,
  DartleCache cache,
  ResolvedLocalDependencies localDependencies,
) {
  final projectDeps = localDependencies.projectDependencies
      .where((s) => s.spec.scope.includedAtRuntime())
      .toList(growable: false);
  final jarDeps = localDependencies.jars
      .where((j) => j.spec.scope.includedAtRuntime())
      .map((j) => j.path)
      .toList(growable: false);
  final preArgs = config.preArgs(Directory.current.path);
  final libsDir = files.processorLibsDir;
  final depsFile = files.processorDependenciesFile.path;

  Future<void> action(_) async {
    final deps = FileDependencies(
      File(depsFile),
      depsCache,
      (scope) => scope.includedAtRuntime(),
    );
    await _install(
      installProcessorDepsTaskName,
      jBuildSender,
      preArgs,
      deps,
      libsDir,
    );
    await _copy(projectDeps, libsDir, runtime: true);
    await _copyFiles(jarDeps, libsDir);
  }

  return _createInstallDepsTask(
    installProcessorDepsTaskName,
    'annotation processor',
    action,
    depsFile,
    projectDeps,
    jarDeps,
    libsDir,
    cache,
  );
}

Task _createInstallDepsTask(
  String taskName,
  String scopeName,
  Future<void> Function(List<String>) action,
  String inputFile,
  List<ResolvedProjectDependency> projectDeps,
  List<String> jarDeps,
  String libsDir,
  DartleCache cache,
) {
  final inputFiles = [inputFile];
  final inputDirs = <DirectoryEntry>[];
  for (final dep in projectDeps) {
    dep.output.when(
      dir: (d) => inputDirs.add(
        DirectoryEntry(path: p.canonicalize(p.join(dep.path, d))),
      ),
      jar: (j) => inputFiles.add(p.canonicalize(p.join(dep.path, j))),
    );
  }
  inputFiles.addAll(jarDeps);
  final runCondition = RunOnChanges(
    inputs: entities(inputFiles, inputDirs),
    outputs: dir(libsDir),
    verifyOutputsExist: false, // maybe nothing to install
    cache: cache,
  );

  return Task(
    action,
    runCondition: runCondition,
    dependsOn: const {verifyDepsTaskName},
    name: taskName,
    description: 'Install $scopeName dependencies.',
  );
}

Future<void> _install(
  String taskName,
  JBuildSender jBuildSender,
  List<String> preArgs,
  Dependencies dependencies,
  String outputDir,
) async {
  final deps = await dependencies.resolveArtifacts(includeLocal: false);
  if (deps.isEmpty) {
    return logger.fine("No dependencies to install for '$taskName'.");
  }
  await jBuildSender.send(
    RunJBuild(taskName, [
      ...preArgs,
      'install',
      '--non-transitive',
      '-d',
      outputDir,
      ...deps,
    ]),
  );
}

Future<void> _copy(
  Iterable<ResolvedProjectDependency> resolvedDeps,
  String destinationDir, {
  required bool runtime,
}) async {
  if (resolvedDeps.isEmpty) return;
  await Directory(destinationDir).create(recursive: true);
  for (final dep in resolvedDeps) {
    await _copyOutput(dep.output, destinationDir);
    await _copyOutput(
      CompileOutput.dir(runtime ? dep.runtimeLibsDir : dep.compileLibsDir),
      destinationDir,
    );
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
    jar: (j) => File(j).copy(p.join(destinationDir, p.basename(j))),
  );
}

/// Create the createJavaCompilationPath task.
Task createJavaCompilationPathTask(
  JbFiles files,
  JbConfiguration config,
  JBuildSender jBuildSender,
  DartleCache cache,
) {
  final compilationFiles = cp.CompilationPathFiles(cache);
  final workingDir = Directory.current.path;
  return Task(
    (_) async {
      await cp.computeCompilationPath(
        createJavaCompilationPathTaskName,
        config,
        workingDir,
        jBuildSender,
        config.compileLibsDir,
        config.runtimeLibsDir,
        compilationFiles,
      );
    },
    name: createJavaCompilationPathTaskName,
    dependsOn: {installCompileDepsTaskName, installRuntimeDepsTaskName},
    runCondition: RunOnChanges(outputs: compilationFiles.asFileCollection()),
  );
}

/// Create the eclipse task.
Task createEclipseTask(JbConfiguration config) {
  return Task(
    (_) async => await generateEclipseFiles(
      config.sourceDirs,
      config.resourceDirs,
      config.module,
      config.compileLibsDir,
    ),
    name: createEclipseTaskName,
    description: 'Generate Eclipse IDE files for the project.',
    dependsOn: const {installCompileDepsTaskName},
  );
}

/// Create the generatePom task.
Task createGeneratePomTask(
  Result<Artifact> artifact,
  ResolvedLocalDependencies localDependencies,
  File dependenciesFile,
  DepsCache depsCache,
) {
  return Task(
    (List<String> args) => _generatePom(
      args,
      artifact,
      localDependencies,
      dependenciesFile,
      depsCache,
    ),
    name: createPomTaskName,
    phase: publishPhase,
    dependsOn: {writeDepsTaskName},
    runCondition: artifact.runCondition(),
    argsValidator: const OptionalArgValidator(
      'One argument may be provided: the POM destination',
    ),
    description: 'Generate Maven POM for publishing the project',
  );
}

Future<void> _generatePom(
  List<String> args,
  Result<Artifact> artifact,
  ResolvedLocalDependencies localDependencies,
  File dependenciesFile,
  DepsCache depsCache,
) async {
  final stopWatch = Stopwatch()..start();
  final deps = await depsCache.send(GetDeps(dependenciesFile.path));
  logger.log(
    profile,
    'Parsed dependencies file in ${stopWatch.elapsedMilliseconds} ms',
  );
  stopWatch.reset();

  final pom = createPom(
    switch (artifact) {
      Ok(value: var theArtifact) => theArtifact,
      Fail(exception: var e) => throw e,
    },
    deps.dependencies,
    localDependencies,
  );

  logger.log(profile, 'Created POM in ${stopWatch.elapsedMilliseconds} ms');

  final destination = File(args.isEmpty ? 'pom.xml' : args[0]);
  await destination.parent.create(recursive: true);

  logger.fine(() => "Writing POM to $destination");
  await destination.writeAsString(pom, flush: true);
}

/// Create the publish task.
Task createPublishTask(
  Result<Artifact> artifact,
  File depsFile,
  DepsCache depsCache,
  String? outputJar,
  ResolvedLocalDependencies localDependencies,
) {
  return Task(
    Publisher(artifact, depsFile, depsCache, localDependencies, outputJar).call,
    name: publishTaskName,
    dependsOn: const {publicationCompileTaskName},
    runCondition: artifact.runCondition(),
    phase: publishPhase,
    argsValidator: Publisher.argsValidator,
    description:
        'Publish project to a Maven repository (Maven local by '
        'default).',
  );
}

/// Create the `run` task.
Task createRunTask(JbFiles files, JbConfigContainer config, DartleCache cache) {
  return Task(
    (List<String> args) => _run(files.jbuildJar, config, args),
    dependsOn: const {compileTaskName, installRuntimeDepsTaskName},
    argsValidator: const AcceptAnyArgs(),
    name: runTaskName,
    description: 'Run Java Main class.',
    phase: evaluatePhase,
  );
}

Future<void> _run(
  File jbuildJar,
  JbConfigContainer configContainer,
  List<String> args,
) async {
  final config = configContainer.config;
  var mainClass = config.mainClass ?? '';
  if (mainClass.isEmpty) {
    const mainClassArg = '--main-class=';
    final mainClassArgIndex = args.indexWhere(
      (arg) => arg.startsWith(mainClassArg),
    );
    if (mainClassArgIndex >= 0) {
      mainClass = args
          .removeAt(mainClassArgIndex)
          .substring(mainClassArg.length);
    }
  }
  if (mainClass.isEmpty) {
    throw DartleException(
      message:
          'cannot run Java application as '
          'no main-class has been configured or provided.\n'
          'To configure one, add "main-class: your.Main" to your jb config file.',
    );
  }

  final classpath = {
    configContainer.output.when(dir: (d) => d.asDirPath(), jar: (j) => j),
    config.runtimeLibsDir,
    p.join(config.runtimeLibsDir, '*'),
  }.join(classpathSeparator);

  final exitCode = await execJava(runTaskName, [
    ...config.runJavaArgs,
    '-cp',
    classpath,
    mainClass,
    ...args,
  ], env: config.runJavaEnv);

  if (exitCode != 0) {
    throw DartleException(message: 'java command failed', exitCode: exitCode);
  }
}

/// Create the `jshell` task.
Task createJshellTask(
  JbFiles files,
  JbConfigContainer config,
  DartleCache cache,
) {
  return Task(
    (List<String> args) => jshell(files.jbuildJar, config, args),
    dependsOn: const {compileTaskName, installRuntimeDepsTaskName},
    argsValidator: const JshellArgs(),
    name: jshellTaskName,
    description: jshellHelp,
    phase: evaluatePhase,
  );
}

/// Create the `downloadTestRunner` task.
Task createDownloadTestRunnerTask(
  JbFiles files,
  JbConfigContainer configContainer,
  JBuildSender jBuildSender,
  DepsCache depsCache,
  DartleCache cache,
  FileCollection jbFileInputs,
) {
  final workingDir = Directory.current.path;
  final depsFile = files.testRunnerDependenciesFile.path;
  return Task(
    (_) => _downloadTestRunner(
      jBuildSender,
      configContainer,
      workingDir,
      depsCache,
      depsFile,
      cache,
    ),
    dependsOn: {writeDepsTaskName},
    runCondition: RunOnChanges(
      inputs: jbFileInputs,
      outputs: dir(p.join(cache.rootDir, junitRunnerLibsDir)),
      cache: cache,
    ),
    name: downloadTestRunnerTaskName,
    description: 'Download a test runner. JBuild automatically detects JUnit5.',
  );
}

/// Create the `test` task.
Task createTestTask(
  File jbuildJar,
  JbConfigContainer config,
  DartleCache cache,
  bool noColor,
) {
  return Task(
    (List<String> args) => _test(jbuildJar, config, cache, noColor, args),
    name: testTaskName,
    argsValidator: const AcceptAnyArgs(),
    dependsOn: const {
      compileTaskName,
      downloadTestRunnerTaskName,
      installRuntimeDepsTaskName,
    },
    description: 'Run tests. JBuild automatically detects JUnit5 and Spock.',
    phase: evaluatePhase,
  );
}

Future<void> _downloadTestRunner(
  JBuildSender jBuildSender,
  JbConfigContainer configContainer,
  String workingDir,
  DepsCache depsCache,
  String depsFile,
  DartleCache cache,
) async {
  final config = configContainer.config;
  validateTestConfig(configContainer.testConfig);
  final outDir = Directory(p.join(cache.rootDir, junitRunnerLibsDir));
  logger.fine('Installing Test Runner');
  return _install(
    downloadTestRunnerTaskName,
    jBuildSender,
    config.preArgs(workingDir),
    FileDependencies(
      File(depsFile),
      depsCache,
      (scope) => scope.includedAtRuntime(),
    ),
    outDir.path,
  );
}

Future<void> _test(
  File jbuildJar,
  JbConfigContainer configContainer,
  DartleCache cache,
  bool noColor,
  List<String> args,
) async {
  final config = configContainer.config;
  final libs = Directory(config.runtimeLibsDir).list();
  final classpath = {
    configContainer.output.when(dir: (d) => d.asDirPath(), jar: (j) => j),
    config.runtimeLibsDir,
    await for (final lib in libs)
      if (p.extension(lib.path) == '.jar') lib.path,
  }.join(classpathSeparator);

  const mainClass = 'org.junit.platform.console.ConsoleLauncher';

  final hasCustomSelect = args.any(
    (arg) => arg.startsWith('--select') || arg.startsWith('--scan-classpath'),
  );

  final isSpockConfigured = configContainer.testConfig.spockVersion != null;
  final hasCustomName = args.any(
    (arg) => arg == '-n' || arg.startsWith('--include-classname'),
  );
  final customTestNames = (hasCustomName || !isSpockConfigured)
      ? null
      : '.*Spec|.*Specification|.*Specifications|.*Test|.*Tests|.*TestSuite|.*TestCase';

  final exitCode = await execJava(testTaskName, [
    ...config.testJavaArgs,
    '-ea',
    '-cp',
    p.join(cache.rootDir, junitRunnerLibsDir, '*'),
    mainClass,
    '--classpath=$classpath',
    if (!hasCustomSelect)
      '--scan-classpath=${configContainer.output.when(dir: (d) => d.asDirPath(), jar: (j) => j)}',
    if (customTestNames != null) ...['-n', customTestNames],
    '--reports-dir=${config.testReportsDir}',
    '--fail-if-no-tests',
    if (noColor) '--disable-ansi-colors',
    ...args,
  ], env: config.testJavaEnv);

  if (exitCode != 0) {
    throw DartleException(message: 'test command failed', exitCode: exitCode);
  }
}

/// Create the `dependencies` task.
Task createDepsTask(
  JbFiles jbFiles,
  JbConfiguration config,
  DepsCache depsCache,
  DartleCache cache,
  ResolvedLocalDependencies localDeps,
  ResolvedLocalDependencies localProcDeps,
) {
  final workingDir = Directory.current.path;
  return Task(
    (List<String> args) => printDependencies(
      jbFiles,
      config,
      workingDir,
      depsCache,
      localDeps,
      localProcDeps,
      args,
    ),
    name: depsTaskName,
    dependsOn: {writeDepsTaskName},
    argsValidator: const DepsArgValidator(),
    description: 'Shows information about project dependencies.',
  );
}

Task createShowConfigTask(JbConfiguration config, bool noColor) {
  return Task(
    (_) => print(config.toYaml(noColor)),
    name: showJbConfigTaskName,
    phase: TaskPhase.setup,
    description: 'Shows the fully resolved jb configuration.',
  );
}

/// Create the `requirements` task.
Task createRequirementsTask(File jbuildJar, JbConfigContainer config) {
  final workingDir = Directory.current.path;
  return Task(
    (List<String> args) => _requirements(jbuildJar, config, workingDir, args),
    name: requirementsTaskName,
    argsValidator: const AcceptAnyArgs(),
    dependsOn: const {compileTaskName},
    description: 'Shows information about project requirements.',
  );
}

Future<void> _requirements(
  File jbuildJar,
  JbConfigContainer configContainer,
  String workingDir,
  List<String> args,
) async {
  final out = configContainer.output.when(dir: (dir) => dir, jar: (jar) => jar);
  final exitCode = await logRequirements(
    jbuildJar,
    configContainer.config,
    workingDir,
    [out, ...args],
  );
  if (exitCode != 0) {
    throw DartleException(
      message: 'jbuild requirements command failed',
      exitCode: exitCode,
    );
  }
}

Task createUpdateJBuildTask(JBuildSender jBuildSender) {
  final workingDir = Directory.current.path;
  return Task(
    (_) => jbuildUpdate(jBuildSender, workingDir),
    phase: TaskPhase.setup,
    name: updateJBuildTaskName,
    description: 'Updates the JBuild jar used by jb.',
  );
}

extension on Result<Artifact> {
  RunCondition runCondition() {
    return switch (this) {
      Ok() => const AlwaysRun(),
      Fail(exception: final err) => CannotRun(
        err is DartleException ? err.message : err.toString(),
      ),
    };
  }
}
