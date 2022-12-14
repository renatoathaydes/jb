import 'dart:convert';

import 'package:archive/archive_io.dart';
import 'package:dartle/dartle.dart';
import 'package:dartle/dartle_cache.dart';
import 'package:path/path.dart' as p;

import 'config.dart';
import 'path_dependency.dart';
import 'sub_project.dart';
import 'tasks.dart';
import 'utils.dart';

/// Grouped components of a build.
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
      clean,
      run,
      downloadTestRunner,
      test,
      deps;

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

  final SubProjectFactory _subProjectFactory;

  JBuildDartle(this._components)
      : projectPath = p.joinAll(_components.projectPath),
        projectName = _components.projectName,
        _subProjectFactory = SubProjectFactory(_components) {
    init = _resolveLocalDependencies().then(_initialize);
  }

  JBuildDartle.root(JBuildFiles files, JBuildConfiguration config,
      DartleCache cache, Options options, Stopwatch stopWatch)
      : this(JBuildComponents(
            files, config, cache, options, '', const [], stopWatch));

  /// Get the default tasks (`{ compile }`).
  Set<Task> get defaultTasks {
    return {compile};
  }

  Future<LocalDependencies> _resolveLocalDependencies() async {
    final pathDependencies = _components.config.dependencies.entries
        .map((e) => e.value.toPathDependency())
        .whereNonNull()
        .toStream();

    final projectDeps = <ProjectDependency>[];
    final jars = <JarDependency>[];

    await for (final pathDep in pathDependencies) {
      pathDep.when(jar: jars.add, jbuildProject: projectDeps.add);
    }

    final subProjects =
        await _subProjectFactory.createSubProjects(projectDeps).toList();

    logger.fine(() => 'Resolved ${subProjects.length} sub-projects, '
        '${jars.length} local jar dependencies.');

    return LocalDependencies(jars, subProjects);
  }

  Future<void> _initialize(LocalDependencies localDependencies) async {
    final files = _components.files;
    final config = _components.config;
    final cache = _components.cache;
    final subProjects = localDependencies.subProjects;

    // must initialize the cache explicitly as this method may be running on
    // sub-projects where the cache was not created by the cache constructor.
    cache.init();

    final projectTasks = <Task>{};

    compile = createCompileTask(files, config, cache);
    writeDeps =
        createWriteDependenciesTask(files, config, cache, localDependencies);
    installCompile =
        createInstallCompileDepsTask(files, config, cache, localDependencies);
    installRuntime =
        createInstallRuntimeDepsTask(files, config, cache, localDependencies);
    installProcessor = createInstallProcessorDepsTask(files, config, cache);
    run = createRunTask(files, config, cache);
    downloadTestRunner =
        createDownloadTestRunnerTask(files.jbuildJar, config, cache);
    test = createTestTask(
        files.jbuildJar, config, cache, !_components.options.colorfulLog);
    deps = createDepsTask(files.jbuildJar, config, cache, localDependencies,
        !_components.options.colorfulLog);

    final customTasks = await _loadExtensionProject(files, cache).toList();

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
      ...customTasks,
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

  Stream<Task> _loadExtensionProject(
      JBuildFiles files, DartleCache cache) async* {
    if (await files.jbExtensionProjectDir.exists()) {
      logger.fine('Loading jb extension project');
      final path = files.jbExtensionProjectDir.path;
      final jbExtensionProject =
          await _subProjectFactory.createJBuildSubProject(ProjectDependency(
              DependencySpec(
                  transitive: false, scope: DependencyScope.all, path: path),
              path));

      logger.fine('Running jb extension project build');

      await runBasic(jbExtensionProject.tasks.values.toSet(), const {},
          Options(tasksInvocation: ['$path:$compileTaskName']), cache);

      final jar = jbExtensionProject.output.when(
          dir: (d) => throw DartleException(
              message: 'jb extension project must configure an '
                  "'output-jar', not 'output-dir'."),
          jar: (j) => j);

      yield* _loadExtensionTasks(p.join(files.jbExtensionProjectDir.path, jar));
    }
  }

  Stream<Task> _loadExtensionTasks(String jar) async* {
    const extService = 'META-INF/jb/jb-extension.yaml';
    logger.fine('Reading jb extension project manifest file');
    final archive = ZipDecoder().decodeBuffer(InputFileStream(jar));
    final extFile = archive.findFile(extService);
    if (extFile == null) {
      throw DartleException(
          message:
              'jb extension project jar is missing manifest file: $extService');
    }
    final model = loadJbExtensionModel(
        utf8.decode(extFile.content), Uri.parse('jar:file:$jar!$extService'));

    // TODO create tasks from the model
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
