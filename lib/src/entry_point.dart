import 'dart:io';

import 'package:dartle/dartle.dart';
import 'package:isolate_current_directory/isolate_current_directory.dart';
import 'package:path/path.dart' as p;

import 'config.dart';
import 'config_source.dart';
import 'create/create.dart';
import 'help.dart';
import 'jb_files.dart';
import 'jvm_executor.dart';
import 'options.dart';
import 'runner.dart';
import 'utils.dart';

/// Run jb.
///
/// Returns `true` if the build executed tasks, false if it only printed info.
///
/// The caller must handle errors.
Future<bool> runJb(
    JbCliOptions jbOptions, Options dartleOptions, Stopwatch stopwatch,
    [ConfigSource? configSource]) async {
  if (dartleOptions.showHelp) {
    printHelp();
    return false;
  }
  final jbuildJar = await createIfNeededAndGetJBuildJarFile();
  if (dartleOptions.showVersion) {
    await printVersion(jbuildJar);
    return false;
  }
  var rootDir = jbOptions.rootDirectory;
  if (rootDir == null) {
    await _runJb(jbOptions, dartleOptions, configSource, stopwatch, jbuildJar);
  } else {
    rootDir = p.canonicalize(rootDir);
    final dir = Directory(rootDir);
    if (!(await dir.exists())) {
      if (jbOptions.createOptions == null) {
        throw DartleException(message: 'directory does not exist: $rootDir');
      } else {
        logger.info(() => PlainMessage('Creating directory: $rootDir'));
        await dir.create(recursive: true);
      }
    }
    logger.fine(() => "Running jb on directory '$rootDir'");
    await withCurrentDirectory(
        rootDir,
        () async => await _runJb(
            jbOptions, dartleOptions, configSource, stopwatch, jbuildJar));
  }
  return true;
}

Future<void> _runJb(JbCliOptions options, Options dartleOptions,
    ConfigSource? configSource, Stopwatch stopwatch, File jbuildJar) async {
  logger.log(profile,
      () => 'Initialized CLI and parsed options in ${elapsedTime(stopwatch)}');
  final createOptions = options.createOptions;
  if (createOptions != null) {
    return createNewProject(createOptions.arguments);
  }
  final jvmExecutor = createJavaActor(dartleOptions.logLevel, jbuildJar.path);

  final runner = await JbRunner.create(
      JbFiles(
        jbuildJar,
        configSource: configSource ?? defaultJbConfigSource,
      ),
      await jvmExecutor.toSendable());

  try {
    await runner.run(dartleOptions, stopwatch);
  } finally {
    await jvmExecutor.close();
  }
}
