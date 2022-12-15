import 'dart:io';

import 'package:dartle/dartle.dart';
import 'package:dartle/dartle_cache.dart';
import 'package:isolate_current_directory/isolate_current_directory.dart';

import 'config.dart';
import 'create/create.dart';
import 'jbuild_dartle.dart';
import 'options.dart';
import 'utils.dart';
import 'help.dart';

/// Run jb.
///
/// Returns `true` if the build executed tasks, false if it only printed info.
///
/// The caller must handle errors.
Future<bool> runJBuild(
  JBuildCliOptions jbOptions,
  Options dartleOptions,
  Stopwatch stopwatch,
  File jbuildJar,
) async {
  if (dartleOptions.showHelp) {
    printHelp();
    return false;
  }
  if (dartleOptions.showVersion) {
    await printVersion(jbuildJar);
    return false;
  }
  final rootDir = jbOptions.rootDirectory;
  if (rootDir == null) {
    await _runJBuild(jbOptions, dartleOptions, stopwatch, jbuildJar);
  } else {
    final dir = Directory(rootDir);
    if (!(await dir.exists())) {
      if (jbOptions.createOptions == null) {
        throw DartleException(message: 'directory does not exist: $rootDir');
      } else {
        logger.info(() => PlainMessage('Creating directory: $rootDir'));
        await dir.create(recursive: true);
      }
    }
    await withCurrentDirectory(
        rootDir,
        () async =>
            await _runJBuild(jbOptions, dartleOptions, stopwatch, jbuildJar));
  }
  return true;
}

Future<void> _runJBuild(JBuildCliOptions options, Options dartleOptions,
    Stopwatch stopwatch, File jbuildJar) async {
  logger.log(profile,
      () => 'Initialized CLI and parsed options in ${elapsedTime(stopwatch)}');
  final createOptions = options.createOptions;
  if (createOptions != null) {
    return createNewProject(createOptions.arguments);
  }
  final cli = _JBuildCli(jbuildJar);
  return cli.start(dartleOptions, stopwatch);
}

class _JBuildCli {
  final JBuildFiles files;

  _JBuildCli(File jbuildJar) : files = JBuildFiles(jbuildJar);

  Future<void> start(Options options, Stopwatch stopWatch) async {
    final cache = DartleCache(jbuildCache);

    final config =
        (await createConfig()).orThrow('${files.configFile.path} not found.'
            '\nRun with the --help option to see usage.');

    logger.fine(() => 'Parsed JBuild configuration: $config');

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

  Future<JBuildConfiguration?> createConfig() async {
    if (await files.configFile.exists()) {
      return await loadConfig(files.configFile);
    }
    return null;
  }
}
