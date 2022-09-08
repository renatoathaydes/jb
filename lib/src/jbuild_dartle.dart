import 'package:dartle/dartle.dart';
import 'package:dartle/dartle_cache.dart';

import 'config.dart';
import 'dependencies.dart';
import 'tasks.dart';

class JBuildDartle {
  final JBuildFiles files;
  final JBuildConfiguration config;
  final DartleCache cache;

  late final Task compile,
      writeDeps,
      installCompile,
      installRuntime,
      clean,
      run;

  /// Get the tasks that are configured as part of a build.
  late final Set<Task> tasks;

  /// Wait for all sub-projects tasks to be initialized.
  late final Future<void> init;

  JBuildDartle(this.files, this.config, this.cache, Options options,
      Stopwatch stopWatch) {
    init = resolveSubProjects(files, config, cache, options)
        .then((r) => _initialize(r, stopWatch));
  }

  Set<Task> get defaultTasks {
    return {compile};
  }

  Future<void> _initialize(
      List<SubProject> subProjects, Stopwatch stopWatch) async {
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
    run = createRunTask(files, config, cache, subProjects);

    projectTasks
        .addAll({compile, writeDeps, installCompile, installRuntime, run});

    projectTasks.addSubProjectTasks(subProjects);

    clean = createCleanTask(
        tasks: projectTasks,
        name: cleanTaskName,
        description: 'deletes the outputs of all other tasks.');
    projectTasks.add(clean);

    _addSubProjectTaskDependencies(subProjects);

    tasks = Set.unmodifiable(projectTasks);

    logger.log(
        profile,
        () => 'Build initialization completed in '
            '${stopWatch.elapsedMilliseconds}ms.');
  }

  void _addSubProjectTaskDependencies(List<SubProject> subProjects) {
    for (var subProject in subProjects) {
      compile.dependsOn({subProject.compileTask.name});
      installRuntime.dependsOn({subProject.installRuntimeTask.name});
      clean.dependsOn({subProject.cleanTask.name});
    }
  }
}

extension _TasksExtension on Set<Task> {
  void addSubProjectTasks(List<SubProject> subProjects) {
    for (var subProject in subProjects) {
      add(subProject.compileTask);
      add(subProject.testTask);
      add(subProject.cleanTask);
      add(subProject.installRuntimeTask);
    }
  }
}
