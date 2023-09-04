import 'package:dartle/dartle.dart';
import 'package:dartle/dartle_cache.dart';
import 'package:jb/src/project_dependency.dart';

import 'config.dart';
import 'path_dependency.dart';
import 'tasks.dart';
import 'utils.dart';

/// Grouped components of a build.
class JBuildComponents {
  final JBuildFiles files;
  final JBuildConfiguration config;
  final DartleCache cache;
  final Options options;
  final Stopwatch stopWatch;

  JBuildComponents(
      this.files, this.config, this.cache, this.options, this.stopWatch);
}

/// jb Dartle tasks, including sub-projects.
///
/// Users of this class must await on the [init] Future for this class to
/// be fully initialized before using it.
class JBuildDartle {
  JBuildComponents _components;

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

  JBuildDartle(this._components) {
    final localDeps = Future.wait([
      _resolveLocalDependencies(_components.config.dependencies, name: 'main'),
      _resolveLocalDependencies(_components.config.processorDependencies,
          name: 'annotation processor')
    ]);
    init = localDeps.then((d) => _initialize(d[0], d[1]));
  }

  JBuildDartle.root(JBuildFiles files, JBuildConfiguration config,
      DartleCache cache, Options options, Stopwatch stopWatch)
      : this(JBuildComponents(files, config, cache, options, stopWatch));

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
        '${subProjects.length} project dependencies, '
        '${jars.length} local jar dependencies.');

    return ResolvedLocalDependencies(jars, subProjects);
  }

  Future<Closable> _initialize(ResolvedLocalDependencies localDependencies,
      ResolvedLocalDependencies localProcessorDependencies) async {
    final files = _components.files;
    final config = _components.config;
    final cache = _components.cache;
    final unresolvedLocalDeps = localDependencies.unresolved;

    // must initialize the cache explicitly as this method may be running on
    // sub-projects where the cache was not created by the cache constructor.
    cache.init();

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

    _addProjectDependenciesTasks(
        projectTasks, localDependencies.projectDependencies);

    tasks = Set.unmodifiable(projectTasks);

    logger.log(
        profile,
        () => 'Project initialization completed in '
            '${_components.stopWatch.elapsedMilliseconds} ms.');

    // return extensionProject?.close ?? () {};
    return () {};
  }

  void _addProjectDependenciesTasks(
      Set<Task> tasks, List<ResolvedProjectDependency> projectDeps) {
    for (var dep in projectDeps) {
      tasks.add(_createAndSetupDepTask(dep, compile));
      tasks.add(_createAndSetupDepTask(dep, test));
    }
  }

  Task _createAndSetupDepTask(ResolvedProjectDependency dep, Task mainTask) {
    final depTask = createProjectDependencyTask(dep, _components.options,
        mainTaskName: mainTask.name);
    mainTask.dependsOn({depTask.name});
    return depTask;
  }
}
