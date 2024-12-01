import 'package:actors/actors.dart';
import 'package:dartle/dartle.dart';
import 'package:dartle/dartle_cache.dart';

import 'config.dart';
import 'config_source.dart';
import 'jb_dartle.dart';
import 'jb_files.dart';
import 'jvm_executor.dart';

class JbRunner {
  final JbFiles files;
  final JbConfiguration config;
  final Sendable<JavaCommand, Object?> _jvmExecutor;

  JbRunner(this.files, this.config, this._jvmExecutor);

  static Future<JbRunner> create(
      JbFiles files, Sendable<JavaCommand, Object?> jvmExecutor) async {
    final config = await _createConfig(files.configSource);
    logger.fine(() => 'Parsed jb configuration: $config');
    config.validate();
    return JbRunner(files, config, jvmExecutor);
  }

  Future<List<ParallelTasks>> run(Options options, Stopwatch stopWatch,
      {bool isRoot = true}) async {
    final cache = DartleCache(files.jbCache);

    final jb = JbDartle.create(
        files, config, cache, options, _jvmExecutor, stopWatch,
        isRoot: isRoot);

    await jb.init;

    return await runBasic(jb.tasks, jb.defaultTasks, options, cache);
  }
}

Future<JbConfiguration> _createConfig(ConfigSource configSource) async {
  try {
    return await configSource.load();
  } on DartleException {
    rethrow;
  } catch (e) {
    throw DartleException(
        message: 'Unable to load jb config due to: $e.'
            '\nRun with the --help option to see usage.');
  }
}
