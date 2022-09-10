import 'dart:io';

import 'package:dartle/dartle.dart';
import 'package:dartle/dartle_cache.dart';
import 'package:yaml/yaml.dart';

import 'config.dart';
import 'jbuild_dartle.dart';
import 'utils.dart';

class JBuildCli {
  final JBuildFiles files;

  JBuildCli(File jbuildJar, File configFile)
      : files = JBuildFiles(jbuildJar, configFile);

  Future<void> start(List<String> args, Stopwatch stopWatch) async {
    final options = parseOptions(args);
    activateLogging(options.logLevel,
        colorfulLog: options.colorfulLog,
        logName: Platform.environment[jbuildLogNameEnvVar]);

    if (options.showHelp) {
      print('JBuild CLI\n');
      return print(optionsDescription);
    }

    final cache = DartleCache('.jbuild-cache');

    final config =
        (await createConfig()).orThrow('${files.configFile.path} not found.'
            '\nRun with the --help option to see usage.');

    logger.fine(() => 'Parsed JBuild configuration: $config');

    final jbuildDartle =
        JBuildDartle.root(files, config, cache, options, stopWatch);

    await jbuildDartle.init;

    await runBasic(
        jbuildDartle.tasks, jbuildDartle.defaultTasks, options, cache);
  }

  Future<JBuildConfiguration?> createConfig() async {
    if (await files.configFile.exists()) {
      return configFromJson(loadYaml(await files.configFile.readAsString(),
          sourceUrl: Uri.parse(files.configFile.path)));
    }
    return null;
  }
}
