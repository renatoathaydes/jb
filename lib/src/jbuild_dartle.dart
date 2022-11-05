import 'package:dartle/dartle.dart';
import 'package:dartle/dartle_cache.dart';
import 'package:path/path.dart' as p;
import 'config.dart';
import 'sub_project.dart';
import 'tasks.dart';
import 'utils.dart';

class JBuildComponents {
  final JBuildFiles files;
  final JBuildConfiguration config;
  final DartleCache cache;
  final Options options;
  final String projectName;
  final List<String> projectPath;
  final Stopwatch stopWatch;

  JBuildComponents(this.files, this.config, this.cache, this.options,
      this.projectName, this.projectPath, this.stopWatch);

  JBuildComponents child(String projectName, JBuildConfiguration config) {
    final childPath = [...projectPath, projectName];
    return JBuildComponents(
        files, config, cache, options, projectName, childPath, stopWatch);
  }
}

class JBuildDartle {
  JBuildComponents _components;

  late final Task compile,
      writeDeps,
      installCompile,
      installRuntime,
      clean,
      run,
      downloadTestRunner,
      test;

  /// Get the tasks that are configured as part of a build.
  late final Set<Task> tasks;

  /// Wait for all sub-projects tasks to be initialized.
  late final Future<void> init;

  /// Project configuration.
  JBuildConfiguration get config => _components.config;

  /// Project path. The empty string for the root project.
  final String projectPath;

  /// Simple name of the project (last part of the projectPath).
  final String projectName;

  JBuildDartle(this._components)
      : projectPath = p.joinAll(_components.projectPath),
        projectName = _components.projectName {
    init = _resolveSubProjects().then(_initialize);
  }

  JBuildDartle.root(JBuildFiles files, JBuildConfiguration config,
      DartleCache cache, Options options, Stopwatch stopWatch)
      : this(JBuildComponents(
            files, config, cache, options, '', const [], stopWatch));

  Set<Task> get defaultTasks {
    return {compile};
  }

  Future<List<SubProject>> _resolveSubProjects() async {
    final pathDependencies = _components.config.dependencies.entries
        .map((e) => e.value.toPathDependency())
        .whereNonNull()
        .toStream();

    final subProjectFactory = SubProjectFactory(_components);

    final projectDeps = <ProjectDependency>[];
    final jars = <JarDependency>[];

    await for (final pathDep in pathDependencies) {
      pathDep.map(jar: jars.add, jbuildProject: projectDeps.add);
    }

    final subProjects =
        await subProjectFactory.createSubProjects(projectDeps).toList();

    logger.fine(() => 'Resolved ${subProjects.length} sub-projects, '
        '${jars.length} local jar dependencies.');

    return subProjects;
  }

  Future<void> _initialize(List<SubProject> subProjects) async {
    final files = _components.files;
    final config = _components.config;
    final cache = _components.cache;

    // must initialize the cache explicitly as this method may be running on
    // sub-projects where the cache was not created by the cache constructor.
    cache.init();

    final projectTasks = <Task>{};
    final compileDeps =
        subProjects.where((p) => p.spec.scope.includedInCompilation());
    final runtimeDeps =
        subProjects.where((p) => p.spec.scope.includedAtRuntime());

    compile = createCompileTask(files.jbuildJar, config, cache);
    writeDeps = createWriteDependenciesTask(files, config, cache, subProjects);
    installCompile =
        createInstallCompileDepsTask(files, config, cache, compileDeps);
    installRuntime =
        createInstallRuntimeDepsTask(files, config, cache, runtimeDeps);
    run = createRunTask(files, config, cache);
    downloadTestRunner =
        createDownloadTestRunnerTask(files.jbuildJar, config, cache);
    test = createTestTask(files.jbuildJar, config, cache);

    projectTasks.addAll({
      compile,
      writeDeps,
      installCompile,
      installRuntime,
      run,
      downloadTestRunner,
      test
    });

    clean = createCleanTask(
        tasks: projectTasks,
        name: cleanTaskName,
        description: 'deletes the outputs of all other tasks.');
    projectTasks.add(clean);

    projectTasks.addSubProjectTasks(subProjects);
    _addSubProjectTaskDependencies(subProjects);

    tasks = Set.unmodifiable(projectTasks);

    logger.log(
        profile,
        () =>
            "${projectPath.isEmpty ? 'Root project' : "Project '$projectPath'"}"
            ' initialization completed in '
            '${_components.stopWatch.elapsedMilliseconds} ms.');
  }

  void _addSubProjectTaskDependencies(List<SubProject> subProjects) {
    for (var subProject in subProjects) {
      final subCompileTask = subProject.getTaskOrError(compileTaskName);
      final subInstallRuntimeTask =
          subProject.getTaskOrError(installRuntimeDepsTaskName);
      final subCleanTask = subProject.getTaskOrError(cleanTaskName);
      installCompile.dependsOn({subCompileTask.name});
      installRuntime
          .dependsOn({subCompileTask.name, subInstallRuntimeTask.name});
      clean.dependsOn({subCleanTask.name});
    }
  }
}

extension _TasksExtension on Set<Task> {
  void addSubProjectTasks(Iterable<SubProject> subProjects) {
    for (var subProject in subProjects) {
      addAll(subProject.tasks.values);
    }
  }
}

extension _SubProjectTasksExtension on SubProject {
  Task getTaskOrError(String name) {
    return tasks[name]
        .orThrow("SubProject '${this.name}' is missing task '$name'");
  }
}
