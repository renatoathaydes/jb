import 'dart:io';

import 'package:dartle/dartle.dart';
import 'package:dartle/dartle_cache.dart';

import 'config.dart';
import 'jbuild_dartle.dart';

class JbRunner {
  final JBuildFiles files;
  final JBuildConfiguration config;

  JbRunner(this.files, this.config);

  static Future<JbRunner> create(File jbuildJar) async {
    final files = JBuildFiles(jbuildJar);
    final config = await _createConfig(files.configFile);
    logger.fine(() => 'Parsed JBuild configuration: $config');
    return JbRunner(files, config);
  }

  Future<void> run(Options options, Stopwatch stopWatch) async {
    final cache = DartleCache(jbuildCache);

    final jbuildDartle =
        JBuildDartle.root(files, config, cache, options, stopWatch);

    final closable = await jbuildDartle.init;

    try {
      await runBasic(
          jbuildDartle.tasks, jbuildDartle.defaultTasks, options, cache);
    } finally {
      await closable();
    }
  }
}

Future<JBuildConfiguration> _createConfig(File configFile) async {
  if (await configFile.exists()) {
    return await loadConfig(configFile);
  }
  throw DartleException(
      message: '${configFile.path} configuration file not found.'
          '\nRun with the --help option to see usage.');
}
