import 'package:dartle/dartle.dart';
import 'package:dartle/dartle_cache.dart';
import 'package:jb/src/jb_extension.dart';

import 'config.dart';
import 'config_source.dart';
import 'jb_files.dart';
import 'jvm_executor.dart' show createJavaActor;
import 'path_dependency.dart';
import 'pom.dart';
import 'resolved_dependency.dart';
import 'tasks.dart';
import 'utils.dart';

/// jb Dartle build definition.
///
/// Users of this class must await on the [init] Future for this class to
/// be fully initialized before using it.
class JbDartle {
  final JbFiles _files;
  final JbConfiguration _config;
  final DartleCache _cache;
  final Options _options;

  /// Whether this project is the root project being executed.
  final bool isRoot;

  late final Task compile,
      publicationCompile,
      writeDeps,
      installCompile,
      installRuntime,
      installProcessor,
      generateEclipse,
      generatePom,
      requirements,
      clean,
      run,
      downloadTestRunner,
      test,
      showConfig,
      deps,
      publish,
      updateJBuild;

  /// Get the tasks that are configured as part of a build.
  late final Set<Task> tasks;

  /// Wait for all sub-projects tasks to be initialized.
  ///
  /// Returns a [Closable] that must be called after this object is no longer
  /// required.
  late final Future<Closable> init;

  JbDartle._(this._files, this._config, this._cache, this._options, this.isRoot,
      Stopwatch stopwatch) {
    final localDeps = Future.wait([
      _resolveLocalDependencies(_config.dependencies, name: 'main'),
      _resolveLocalDependencies(_config.processorDependencies,
          name: 'annotation processor')
    ]);
    init = localDeps.then((d) => _initialize(d[0], d[1], stopwatch));
  }

  JbDartle.create(JbFiles files, JbConfiguration config, DartleCache cache,
      Options options, Stopwatch stopWatch,
      {required bool isRoot})
      : this._(files, config, cache, options, isRoot, stopWatch);

  /// Get the default tasks (`{ compile }`).
  Set<Task> get defaultTasks {
    return {compile};
  }

  Future<ResolvedLocalDependencies> _resolveLocalDependencies(
      Map<String, DependencySpec> dependencies,
      {required String name}) async {
    final pathDependencies = dependencies.entries
        .map((e) => e.value.toPathDependency())
        .whereNonNull()
        .toStream();

    final projectDeps = <ProjectDependency>[];
    final jars = <JarDependency>[];

    await for (final pathDep in pathDependencies) {
      pathDep.when(jar: jars.add, jbuildProject: projectDeps.add);
    }

    final subProjects =
        await projectDeps.toStream().asyncMap((e) => e.resolve()).toList();

    logger.fine(() => 'Resolved $name configuration: '
        '${subProjects.length} project dependenc${subProjects.length == 1 ? 'y' : 'ies'}, '
        '${jars.length} local jar dependenc${jars.length == 1 ? 'y' : 'ies'}.');

    return ResolvedLocalDependencies(jars, subProjects);
  }

  Future<Closable> _initialize(
      ResolvedLocalDependencies localDependencies,
      ResolvedLocalDependencies localProcessorDependencies,
      Stopwatch stopwatch) async {
    final unresolvedLocalDeps = localDependencies.unresolved;
    final unresolvedLocalProcessorDeps = localProcessorDependencies.unresolved;

    final jvmExecutor = createJavaActor(
        _files.jbuildJar.path,
        _options.logLevel,
        (await _config.compileArgs(_files.processorLibsDir))
            .javaRuntimeArgs()
            .toList(),
        _config.javacEnv);
    final javaSender = await jvmExecutor.toSendable();

    final FileCollection jbFileInputs;
    final configSource = _files.configSource;
    if (configSource is FileConfigSource) {
      jbFileInputs = file((await configSource.selectFile()).path);
    } else {
      jbFileInputs = FileCollection.empty;
    }
    final artifact = createArtifact(_config);

    final projectTasks = <Task>{};

    compile = createCompileTask(_files, _config, _cache, javaSender);
    publicationCompile =
        createPublicationCompileTask(_files, _config, _cache, javaSender);
    writeDeps = createWriteDependenciesTask(_files, _config, _cache,
        jbFileInputs, unresolvedLocalDeps, unresolvedLocalProcessorDeps);
    installCompile = createInstallCompileDepsTask(
        _files, _config, javaSender, _cache, localDependencies);
    installRuntime = createInstallRuntimeDepsTask(
        _files, _config, javaSender, _cache, localDependencies);
    installProcessor = createInstallProcessorDepsTask(
        _files, _config, javaSender, _cache, localProcessorDependencies);
    run = createRunTask(_files, _config, _cache);
    downloadTestRunner =
        createDownloadTestRunnerTask(_config, javaSender, _cache, jbFileInputs);
    test = createTestTask(
        _files.jbuildJar, _config, _cache, !_options.colorfulLog);
    deps = createDepsTask(_files.jbuildJar, _config, _cache,
        unresolvedLocalDeps, unresolvedLocalProcessorDeps);
    showConfig = createShowConfigTask(_config, !_options.colorfulLog);
    requirements = createRequirementsTask(_files.jbuildJar, _config);
    generateEclipse = createEclipseTask(_config);
    generatePom = createGeneratePomTask(
        artifact, _config.dependencies, localDependencies);
    publish = createPublishTask(
        artifact,
        _config.dependencies,
        _config.output.when(dir: (_) => null, jar: (j) => j),
        localDependencies);
    updateJBuild = createUpdateJBuildTask(javaSender);

    final extensionProject = await loadExtensionProject(javaSender, _files,
        _options, _config.extensionProject, _config.nonConsumedConfig);

    final extensionTasks = extensionProject?.tasks;

    projectTasks.addAll({
      compile,
      publicationCompile,
      writeDeps,
      installCompile,
      installRuntime,
      installProcessor,
      run,
      downloadTestRunner,
      test,
      deps,
      showConfig,
      requirements,
      generateEclipse,
      generatePom,
      publish,
      updateJBuild,
      if (extensionTasks != null) ...extensionTasks,
    });

    clean = createCleanTask(
        tasks: projectTasks,
        name: cleanTaskName,
        description: 'deletes the outputs of all other tasks.');
    projectTasks.add(clean);

    if (localDependencies.projectDependencies.isNotEmpty) {
      await _initializeProjectDeps(localDependencies.projectDependencies);
      if (isRoot) {
        logger.info('All project dependencies have been initialized');
      }
    }

    tasks = Set.unmodifiable(projectTasks);

    logger.log(
        profile,
        () => 'Project initialization completed in '
            '${stopwatch.elapsedMilliseconds} ms.');

    return jvmExecutor.close;
  }

  Future<void> _initializeProjectDeps(
      List<ResolvedProjectDependency> projectDeps) async {
    for (var dep in projectDeps) {
      await dep.initialize(_options, _files);
    }
  }
}
