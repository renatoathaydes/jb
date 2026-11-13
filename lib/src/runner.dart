import 'package:dartle/dartle.dart' show runBasic, Options, ParallelTasks;
import 'package:dartle/dartle_cache.dart' show DartleCache;

import 'config.dart';
import 'config_import.dart';
import 'extension/extension_pipeline.dart';
import 'jb_actors.dart';
import 'jb_dartle.dart';
import 'jb_files.dart';

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

    // extensions must be loaded before the build because they may define tasks
    final extensionProjects = await loadExtensionProjects(
      files,
      _actors,
      options,
      cwi,
    );

    final jb = JbDartle.create(
      files,
      cwi,
      cache,
      options,
      _actors,
      isRoot: isRoot,
      extensionProjects: extensionProjects,
    );

    await jb.init;

    return await runBasic(jb.tasks, jb.defaultTasks, options, cache);
  }
}
