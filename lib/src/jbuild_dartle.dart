import 'package:dartle/dartle.dart';
import 'package:dartle/dartle_cache.dart';

import 'config.dart';
import 'tasks.dart';

class JBuildDartle {
  final JBuildFiles files;
  final CompileConfiguration config;
  final DartleCache cache;

  late final Task compile, writeDeps, install;

  JBuildDartle(this.files, this.config, this.cache) {
    compile = compileTask(files.jbuildJar, config, cache);
    writeDeps = writeDependenciesTask(files, config, cache);
    install = installTask(files, config, cache);
  }

  /// Get the tasks that are configured as part of a build.
  Set<Task> get tasks {
    return {compile, writeDeps, install};
  }

  Set<Task> get defaultTasks {
    return {compile};
  }
}
