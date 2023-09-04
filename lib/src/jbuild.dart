import 'dart:io';

import 'package:dartle/dartle.dart';
import 'package:isolate_current_directory/isolate_current_directory.dart';

import 'config.dart';
import 'create/create.dart';
import 'help.dart';
import 'options.dart';
import 'runner.dart';

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
    await _runJb(jbOptions, dartleOptions, stopwatch, jbuildJar);
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
            await _runJb(jbOptions, dartleOptions, stopwatch, jbuildJar));
  }
  return true;
}

Future<void> _runJb(JBuildCliOptions options, Options dartleOptions,
    Stopwatch stopwatch, File jbuildJar) async {
  logger.log(profile,
      () => 'Initialized CLI and parsed options in ${elapsedTime(stopwatch)}');
  final createOptions = options.createOptions;
  if (createOptions != null) {
    return createNewProject(createOptions.arguments);
  }
  final runner = await JbRunner.create(jbuildJar);
  return runner.run(dartleOptions, stopwatch);
}
