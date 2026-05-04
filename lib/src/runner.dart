import 'package:dartle/dartle.dart';
import 'package:dartle/dartle_cache.dart';
import 'package:jb/jb.dart';

import 'jb_actors.dart';

class JbRunner {
  final JbFiles files;
  final JbConfigWithImports cwi;
  final JbActors _actors;

  JbRunner(this.files, this.cwi, this._actors);

  static Future<JbRunner> create(
    JbFiles files,
    JbConfigWithImports cwi,
    JbActors actors,
  ) async {
    logger.fine(() => 'Parsed jb configuration: ${cwi.config}');
    cwi.config.validate();
    return JbRunner(files, cwi, actors);
  }

  Future<List<ParallelTasks>> run(Options options, {bool isRoot = true}) async {
    final cache = DartleCache(JbFiles.jbCache);

    final jb = JbDartle.create(
      files,
      cwi,
      cache,
      options,
      _actors,
      isRoot: isRoot,
    );

    await jb.init;

    return await runBasic(jb.tasks, jb.defaultTasks, options, cache);
  }
}
