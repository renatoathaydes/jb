import 'package:actors/actors.dart';
import 'package:dartle/dartle.dart';
import 'package:dartle/dartle_cache.dart';

import 'config.dart';
import 'dependencies/deps_cache.dart';
import 'jb_dartle.dart';
import 'jb_files.dart';
import 'jvm_executor.dart';

class JbRunner {
  final JbFiles files;
  final JbConfiguration config;
  final Sendable<JavaCommand, Object?> _jvmExecutor;
  final Sendable<DepsCacheMessage, ResolvedDependencies> _depsCache;

  JbRunner(this.files, this.config, this._jvmExecutor, this._depsCache);

  static Future<JbRunner> create(
    JbFiles files,
    JbConfiguration config,
    Sendable<JavaCommand, Object?> jvmExecutor,
    Sendable<DepsCacheMessage, ResolvedDependencies> depsCache,
  ) async {
    logger.fine(() => 'Parsed jb configuration: $config');
    config.validate();
    return JbRunner(files, config, jvmExecutor, depsCache);
  }

  Future<List<ParallelTasks>> run(
    Options options,
    Stopwatch stopWatch, {
    bool isRoot = true,
  }) async {
    final cache = DartleCache(JbFiles.jbCache);

    final jb = JbDartle.create(
      files,
      config,
      cache,
      options,
      _jvmExecutor,
      _depsCache,
      stopWatch,
      isRoot: isRoot,
    );

    await jb.init;

    return await runBasic(jb.tasks, jb.defaultTasks, options, cache);
  }
}
