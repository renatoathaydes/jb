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

  JBuildDartle(this.files, this.config, this.cache) {
    compile = createCompileTask(files.jbuildJar, config, cache);
    writeDeps = createWriteDependenciesTask(files, config, cache);
    installCompile = createInstallCompileDepsTask(files, config, cache);
    installRuntime = createInstallRuntimeDepsTask(files, config, cache);
    run = createRunTask(files, config, cache);
    final allTasks = {compile, writeDeps, installCompile, installRuntime, run};
    clean = createCleanTask(
        tasks: allTasks,
        name: 'clean',
        description: 'deletes the outputs of all other tasks.');
    allTasks.add(clean);
    tasks = Set.unmodifiable(allTasks);
  }

  Set<Task> get defaultTasks {
    return {compile};
  }
}
