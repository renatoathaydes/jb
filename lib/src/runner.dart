import 'package:dartle/dartle.dart';
import 'package:dartle/dartle_cache.dart';

import 'config.dart';
import 'config_source.dart';
import 'jb_dartle.dart';
import 'jb_files.dart';

class JbRunner {
  final JbFiles files;
  final JBuildConfiguration config;

  JbRunner(this.files, this.config);

  static Future<JbRunner> create(JbFiles files) async {
    final config = await _createConfig(files.configSource);
    logger.info(() => 'Parsed JBuild configuration: $config');
    return JbRunner(files, config);
  }

  Future<void> run(Options options, Stopwatch stopWatch) async {
    final cache = DartleCache(files.jbCache);

    final jb = JbDartle.create(files, config, cache, options, stopWatch);

    final closable = await jb.init;

    try {
      await runBasic(jb.tasks, jb.defaultTasks, options, cache);
    } finally {
      await closable();
    }
  }
}

Future<JBuildConfiguration> _createConfig(ConfigSource configSource) async {
  try {
    return await configSource.load();
  } catch (e) {
    throw DartleException(
        message: 'Unable to load jb config due to: $e.'
            '\nRun with the --help option to see usage.');
  }
}
