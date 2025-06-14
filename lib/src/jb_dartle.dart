import 'package:actors/actors.dart';
import 'package:collection/collection.dart';
import 'package:conveniently/conveniently.dart';
import 'package:dartle/dartle.dart';
import 'package:dartle/dartle_cache.dart';

import 'config.dart';
import 'config_source.dart';
import 'extension/jb_extension.dart';
import 'jb_files.dart';
import 'jvm_executor.dart' show JavaCommand;
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
  final Sendable<JavaCommand, Object?> _jvmExecutor;

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
  late final Future<void> init;

  JbDartle._(
    this._files,
    this._config,
    this._cache,
    this._options,
    this._jvmExecutor,
    this.isRoot,
    Stopwatch stopwatch,
  ) {
    final localDeps = Future.wait([
      _resolveLocalDependencies(_config.allDependencies, name: 'main'),
      _resolveLocalDependencies(
        _config.allProcessorDependencies,
        name: 'annotation processor',
      ),
    ]);
    init = localDeps.then((d) => _initialize(d[0], d[1], stopwatch));
  }

  JbDartle.create(
    JbFiles files,
    JbConfiguration config,
    DartleCache cache,
    Options options,
    Sendable<JavaCommand, Object?> jvmExecutor,
    Stopwatch stopWatch, {
    required bool isRoot,
  }) : this._(files, config, cache, options, jvmExecutor, isRoot, stopWatch);

  /// Get the default tasks (`{ compile }`).
  Set<Task> get defaultTasks {
    return {compile};
  }

  Future<ResolvedLocalDependencies> _resolveLocalDependencies(
    Iterable<MapEntry<String, DependencySpec>> dependencies, {
    required String name,
  }) async {
    final pathDependencies = dependencies
        .map((e) => e.value.toPathDependency())
        .whereNonNull()
        .toStream();

    final projectDeps = <ProjectDependency>[];
    final jars = <JarDependency>[];

    await for (final pathDep in pathDependencies) {
      pathDep.when(jar: jars.add, jbuildProject: projectDeps.add);
    }

    final subProjects = await projectDeps
        .toStream()
        .asyncMap((e) => e.resolve())
        .toList();

    logger.fine(
      () =>
          'Resolved $name configuration: '
          '${subProjects.length} project dependenc${subProjects.length == 1 ? 'y' : 'ies'}, '
          '${jars.length} local jar dependenc${jars.length == 1 ? 'y' : 'ies'}.',
    );

    return ResolvedLocalDependencies(jars, subProjects);
  }

  Future<void> _initialize(
    ResolvedLocalDependencies localDependencies,
    ResolvedLocalDependencies localProcessorDependencies,
    Stopwatch stopwatch,
  ) async {
    final configContainer = JbConfigContainer(_config);
    final unresolvedLocalDeps = localDependencies.unresolved;
    final unresolvedLocalProcessorDeps = localProcessorDependencies.unresolved;

    final FileCollection jbFileInputs;
    final configSource = _files.configSource;
    if (configSource is FileConfigSource) {
      jbFileInputs = file((await configSource.selectFile()).path);
    } else {
      jbFileInputs = FileCollection.empty;
    }
    final artifact = createArtifact(_config);

    final projectTasks = <Task>{};

    compile = createCompileTask(_files, configContainer, _cache, _jvmExecutor);
    publicationCompile = createPublicationCompileTask(
      _files,
      configContainer,
      _cache,
      _jvmExecutor,
    );
    writeDeps = createWriteDependenciesTask(
      _files,
      _config,
      _cache,
      jbFileInputs,
      _jvmExecutor,
      unresolvedLocalDeps,
      unresolvedLocalProcessorDeps,
    );
    installCompile = createInstallCompileDepsTask(
      _files,
      _config,
      _jvmExecutor,
      _cache,
      localDependencies,
    );
    installRuntime = createInstallRuntimeDepsTask(
      _files,
      _config,
      _jvmExecutor,
      _cache,
      localDependencies,
    );
    installProcessor = createInstallProcessorDepsTask(
      _files,
      _config,
      _jvmExecutor,
      _cache,
      localProcessorDependencies,
    );
    run = createRunTask(_files, configContainer, _cache);
    downloadTestRunner = createDownloadTestRunnerTask(
      _files,
      configContainer,
      _jvmExecutor,
      _cache,
      jbFileInputs,
    );
    test = createTestTask(
      _files.jbuildJar,
      configContainer,
      _cache,
      !_options.colorfulLog,
    );
    deps = createDepsTask(
      _files,
      _config,
      _cache,
      unresolvedLocalDeps,
      unresolvedLocalProcessorDeps,
    );
    showConfig = createShowConfigTask(_config, !_options.colorfulLog);
    requirements = createRequirementsTask(_files.jbuildJar, configContainer);
    generateEclipse = createEclipseTask(_config);
    generatePom = createGeneratePomTask(
      artifact,
      _config.allDependencies,
      localDependencies,
    );
    publish = createPublishTask(
      artifact,
      _config.allDependencies,
      configContainer.output.when(dir: (_) => null, jar: (j) => j),
      localDependencies,
    );
    updateJBuild = createUpdateJBuildTask(_jvmExecutor);

    final extensionProject = await loadExtensionProject(
      _jvmExecutor,
      _files,
      _options,
      _config,
      _cache,
    );

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
      description: 'deletes the outputs of all other tasks.',
    );
    projectTasks.add(clean);

    extensionProject?.vmap((p) => _wireupTasks(p, projectTasks));

    if (localDependencies.projectDependencies.isNotEmpty) {
      await _initializeProjectDeps(localDependencies.projectDependencies);
      if (isRoot) {
        logger.info('All project dependencies have been initialized');
      }
    }

    tasks = Set.unmodifiable(projectTasks);

    logger.log(
      profile,
      () =>
          'Project initialization completed in '
          '${stopwatch.elapsedMilliseconds} ms.',
    );
  }

  Future<void> _initializeProjectDeps(
    List<ResolvedProjectDependency> projectDeps,
  ) async {
    for (var dep in projectDeps) {
      await dep.initialize(_options, _files, _jvmExecutor);
    }
  }
}

void _wireupTasks(ExtensionProject extensionProject, Set<Task> allTasks) {
  final taskMap = allTasks.groupFoldBy((t) => t.name, (a, b) => b);
  for (final exTask in extensionProject.model.extensionTasks) {
    for (final dep in exTask.dependents) {
      final dependent = taskMap[dep].orThrow(
        () => DartleException(
          message:
              "Task '${exTask.name}' of extension project"
              " '${extensionProject.name}' has non-existent task "
              "dependent '$dep'",
        ),
      );
      dependent.dependsOn({exTask.name});
    }
    for (final dep in exTask.dependsOn) {
      // no need to add dependencies as they're added when the task is created
      taskMap[dep].orThrow(
        () => DartleException(
          message:
              "Task '${exTask.name}' of extension project"
              " '${extensionProject.name}' has non-existent task "
              "dependency '$dep'",
        ),
      );
    }
  }
}
