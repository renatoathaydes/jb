import 'dart:io';

import 'package:dartle/dartle.dart';
import 'package:dartle/dartle_cache.dart';
import 'jbuild_dartle.dart';
import 'package:yaml/yaml.dart';

import 'config.dart';
import 'utils.dart';

class JBuildCli {
  final JBuildFiles files;

  JBuildCli(File jbuildJar, File configFile)
      : files = JBuildFiles(jbuildJar, configFile);

  Future<void> start(List<String> args) async {
    final options = parseOptions(args);
    activateLogging(options.logLevel, colorfulLog: options.colorfulLog);

    if (options.showHelp) {
      print('JBuild CLI\n');
      return print(optionsDescription);
    }

    final cache = DartleCache('.jbuild-cache');

    final config =
        (await createConfig()).orThrow('${files.configFile.path} not found.'
            '\nRun with the --help option to see usage.');

    logger.fine(() => 'Parsed JBuild configuration: $config');

    final jbuildDartle = JBuildDartle(files, config, cache);

    await runBasic(
        jbuildDartle.tasks, jbuildDartle.defaultTasks, options, cache);
  }

  Future<CompileConfiguration?> createConfig() async {
    if (await files.configFile.exists()) {
      return _config(loadYaml(await files.configFile.readAsString(),
          sourceUrl: Uri.parse(files.configFile.path)));
    }
    return null;
  }
}

CompileConfiguration _config(dynamic json) {
  if (json is Map) {
    final map = asJsonMap(json);
    return CompileConfiguration.fromMap(map);
  } else {
    throw DartleException(
        message: 'Expecting jbuild configuration to be a Map, '
            'but it is ${json?.runtimeType}');
  }
}
