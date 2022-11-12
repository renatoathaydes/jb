import 'dart:io';

import 'package:dartle/dartle.dart';
import 'package:dartle/dartle_cache.dart';
import 'package:isolate_current_directory/isolate_current_directory.dart';
import 'package:yaml/yaml.dart';

import 'config.dart';
import 'create.dart';
import 'jbuild_dartle.dart';
import 'options.dart';
import 'utils.dart';

Future<void> runJBuild(
  JBuildCliOptions jbOptions,
  Options dartleOptions,
  Stopwatch stopwatch,
  File jbuildJar,
) async {
  final rootDir = jbOptions.rootDirectory;
  if (rootDir == null) {
    await _runJBuild(jbOptions, dartleOptions, stopwatch, jbuildJar);
  } else {
    final dir = Directory(rootDir);
    if (!(await dir.exists())) {
      if (jbOptions.createOptions == null) {
        throw DartleException(message: 'directory does not exist: $rootDir');
      } else {
        print('Creating directory: $rootDir');
        await dir.create(recursive: true);
      }
    }
    await withCurrentDirectory(
        rootDir,
        () async =>
            await _runJBuild(jbOptions, dartleOptions, stopwatch, jbuildJar));
  }
}

Future<void> _runJBuild(JBuildCliOptions options, Options dartleOptions,
    Stopwatch stopwatch, File jbuildJar) async {
  logger.log(profile,
      () => 'Initialized CLI and parsed options in ${elapsedTime(stopwatch)}');
  final createOptions = options.createOptions;
  if (createOptions != null) {
    return createNewProject(createOptions.arguments);
  }
  final cli = JBuildCli(jbuildJar);
  return cli.start(dartleOptions, stopwatch);
}

class JBuildCli {
  final JBuildFiles files;

  JBuildCli(File jbuildJar) : files = JBuildFiles(jbuildJar);

  Future<void> start(Options options, Stopwatch stopWatch) async {
    if (options.showHelp) {
      print(r'''
                 _ ___      _ _    _ 
              _ | | _ )_  _(_) |__| |
             | || | _ \ || | | / _` |
              \__/|___/\_,_|_|_\__,_|
                Java Build System

Usage:
    jb <task [args...]...> <options...>
    
To create a new project, run `jb create`.
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
