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
        colorfulLog: options.colorfulLog, logName: 'jbuild');

    if (options.showHelp) {
      print(r'''
                 _ ___      _ _    _ 
              _ | | _ )_  _(_) |__| |
             | || | _ \ || | | / _` |
              \__/|___/\_,_|_|_\__,_|
                Java Build System

Usage:
    jb <task [args...]...> <options...>
    
To see available tasks, run 'jb -s' (list of tasks) or 'jb -g' (task graph).

Options:''');
      print(optionsDescription);
      return print('\nFor Documentation, visit '
          'https://github.com/renatoathaydes/jbuild-cli');
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
