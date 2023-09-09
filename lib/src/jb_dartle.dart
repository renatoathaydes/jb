import 'package:dartle/dartle.dart';
import 'package:dartle/dartle_cache.dart';

import 'config.dart';
import 'jb_files.dart';
import 'path_dependency.dart';
import 'resolved_dependency.dart';
import 'tasks.dart';
import 'utils.dart';

/// Grouped components needed by jb.
class _Components {
  final JbFiles files;
  final JbConfiguration config;
  final DartleCache cache;
  final Options options;
  final Stopwatch stopWatch;

  _Components(
      this.files, this.config, this.cache, this.options, this.stopWatch);
}

/// jb Dartle build definition.
///
/// Users of this class must await on the [init] Future for this class to
/// be fully initialized before using it.
class JbDartle {
  final _Components _components;

  /// Whether this project is the root project being executed.
  final bool isRoot;

  late final Task compile,
      writeDeps,
      installCompile,
      installRuntime,
      installProcessor,
      generateEclipse,
      requirements,
      clean,
      run,
      downloadTestRunner,
      test,
      deps;

  /// Get the tasks that are configured as part of a build.
  late final Set<Task> tasks;

  /// Wait for all sub-projects tasks to be initialized.
  ///
  /// Returns a [Closable] that must be called after this object is no longer
  /// required.
  late final Future<Closable> init;

  JbDartle._(this._components, this.isRoot) {
    final localDeps = Future.wait([
      _resolveLocalDependencies(_components.config.dependencies, name: 'main'),
      _resolveLocalDependencies(_components.config.processorDependencies,
          name: 'annotation processor')
    ]);
    init = localDeps.then((d) => _initialize(d[0], d[1]));
  }

  JbDartle.create(JbFiles files, JbConfiguration config, DartleCache cache,
      Options options, Stopwatch stopWatch,
      {required bool isRoot})
      : this._(_Components(files, config, cache, options, stopWatch), isRoot);

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

  Future<Closable> _initialize(ResolvedLocalDependencies localDependencies,
      ResolvedLocalDependencies localProcessorDependencies) async {
    final files = _components.files;
    final config = _components.config;
    final cache = _components.cache;
    final unresolvedLocalDeps = localDependencies.unresolved;

    final projectTasks = <Task>{};

    compile = createCompileTask(files, config, cache);
    writeDeps =
        createWriteDependenciesTask(files, config, cache, unresolvedLocalDeps);
    installCompile =
        createInstallCompileDepsTask(files, config, cache, localDependencies);
    installRuntime =
        createInstallRuntimeDepsTask(files, config, cache, localDependencies);
    installProcessor =
        createInstallProcessorDepsTask(files, config, cache, localDependencies);
    run = createRunTask(files, config, cache);
    downloadTestRunner =
        createDownloadTestRunnerTask(files.jbuildJar, config, cache);
    test = createTestTask(
        files.jbuildJar, config, cache, !_components.options.colorfulLog);
    deps = createDepsTask(files.jbuildJar, config, cache, unresolvedLocalDeps,
        !_components.options.colorfulLog);
    requirements = createRequirementsTask(files.jbuildJar, config, cache,
        unresolvedLocalDeps, !_components.options.colorfulLog);
    generateEclipse = createEclipseTask(config);

    // FIXME re-add support for extension projects
    // final extensionProject = await loadExtensionProject(_components);

    // final extensionTasks = extensionProject?.tasks;

    projectTasks.addAll({
      compile,
      writeDeps,
      installCompile,
      installRuntime,
      installProcessor,
      run,
      downloadTestRunner,
      test,
      deps,
      requirements,
      generateEclipse,
      // if (extensionTasks != null) ...extensionTasks,
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
            '${_components.stopWatch.elapsedMilliseconds} ms.');

    // return extensionProject?.close ?? () {};
    return () {};
  }

  Future<void> _initializeProjectDeps(
      List<ResolvedProjectDependency> projectDeps) async {
    for (var dep in projectDeps) {
      await initializeProjectDependency(
          dep, _components.options, _components.files);
    }
  }
}
