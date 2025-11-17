import 'package:dartle/dartle.dart';
import 'package:dartle/dartle_cache.dart';

import 'config.dart';
import 'jb_actors.dart';
import 'jb_dartle.dart';
import 'jb_files.dart';

class JbRunner {
  final JbFiles files;
  final JbConfiguration config;
  final JbActors _actors;

  JbRunner(this.files, this.config, this._actors);

  static Future<JbRunner> create(
    JbFiles files,
    JbConfiguration config,
    JbActors actors,
  ) async {
    logger.fine(() => 'Parsed jb configuration: $config');
    config.validate();
    return JbRunner(files, config, actors);
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
      _actors,
      stopWatch,
      isRoot: isRoot,
    );

    await jb.init;

    return await runBasic(jb.tasks, jb.defaultTasks, options, cache);
  }
}
