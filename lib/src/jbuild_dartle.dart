import 'package:dartle/dartle.dart';
import 'package:dartle/dartle_cache.dart';

import 'config.dart';
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

  JBuildDartle(this.files, this.config, this.cache) {
    final subProjects = <SubProject>[];
    compile = createCompileTask(files.jbuildJar, config, cache, subProjects);
    writeDeps = createWriteDependenciesTask(files, config, cache);
    installCompile = createInstallCompileDepsTask(files, config, cache);
    installRuntime = createInstallRuntimeDepsTask(files, config, cache);
    run = createRunTask(files, config, cache);
    final projectTasks = {
      compile,
      writeDeps,
      installCompile,
      installRuntime,
      run
    };
    clean = createCleanTask(
        tasks: projectTasks,
        name: 'clean',
        description: 'deletes the outputs of all other tasks.');
    projectTasks.add(clean);

    init = createSubProjects(files, config).then((projects) async {
      subProjects.addAll(projects);
      for (var project in projects) {
        _setupSubProject(project, projectTasks);
      }
    });

    tasks = Set.unmodifiable(projectTasks);
  }

  Set<Task> get defaultTasks {
    return {compile};
  }

  void _setupSubProject(SubProject project, Set<Task> projectTasks) {
    project.when(
        project: (subCompile, subTest, out) {
          projectTasks.add(subCompile);
          projectTasks.add(subTest);
          compile.dependsOn({subCompile.name});
        },
        jar: (_) {});
  }
}
