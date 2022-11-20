import 'dart:io';

import 'package:dartle/dartle.dart';
import 'package:dartle/dartle_cache.dart';
import 'package:jb/jb.dart';

/// jb is meant to be used directly as a CLI tool to build Java projects.
/// However, it is possible to use it also as a Dart library.
///
/// This example shows how a [JBuildDartle] object can be created, which can
/// then be used to integrate it with a standard Dartle project.
///
/// As a configuration object is created from a const Map, this program can be
/// executed in any directory without the `jbuild.yaml` file, unlike the
/// "official" CLI utility. It looks for Java source code to compile in the
/// `src` directory. As the config object does not specify anything else,
/// the default options are used, which means a jar file is created with the
/// name of the working directory.
Future<void> main(List<String> args) async {
  final stopwatch = Stopwatch()..start();
  final jbuildJar = await createIfNeededAndGetJBuildJarFile();

  final config = await loadConfigString('''
    source-dirs: [ src ]
  ''');
  final options = parseOptions(args);

  activateLogging(options.logLevel,
      colorfulLog: options.colorfulLog, logName: 'jbuild');

  final jb = JBuildDartle.root(JBuildFiles(jbuildJar), config,
      DartleCache('.jbuild-cache'), options, stopwatch);

  // Must always wait for jb to initialize as it will load sub-projects async.
  await jb.init;

  // Run the Dartle build
  try {
    await run(args,
        tasks: jb.tasks, defaultTasks: jb.defaultTasks, doNotExit: true);
    logger.info(ColoredLogMessage(
        'jb completed successfully in ${stopwatch.elapsed})!', LogColor.green));
  } catch (e) {
    logger.severe('ERROR: $e');
    exit(1);
  }
}
