import 'dart:io';

import 'package:dartle/dartle.dart';
import 'package:path/path.dart' as p;

import 'compute_compilation_path.dart';
import 'config.dart';
import 'config_source.dart';
import 'create/create.dart';
import 'dependencies/deps_cache.dart';
import 'help.dart';
import 'jb_actors.dart';
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
  JbCliOptions jbOptions,
  Options dartleOptions, [
  ConfigSource? configSource,
]) async {
  if (dartleOptions.showHelp) {
    printHelp();
    return false;
  }
  final stopwatch = Stopwatch()..start();
  final jbuildJar = await createIfNeededAndGetJBuildJarFile();
  logger.log(profile, () => 'Checked JBuild jar in ${elapsedTime(stopwatch)}');
  if (dartleOptions.showVersion) {
    await printVersion(jbuildJar);
    return false;
  }
  var rootDir = jbOptions.rootDirectory;
  if (rootDir != null) {
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
    Directory.current = Directory(rootDir);
    logger.fine(() => "Running jb on directory '$rootDir'");
  }

  await _runJb(jbOptions, dartleOptions, configSource, jbuildJar);

  return true;
}

Future<void> _runJb(
  JbCliOptions options,
  Options dartleOptions,
  ConfigSource? configSource,
  File jbuildJar,
) async {
  final createOptions = options.createOptions;
  if (createOptions != null) {
    return createNewProject(
      createOptions.arguments,
      colors: dartleOptions.colorfulLog,
    );
  }

  final config = await _createConfig(configSource ?? defaultJbConfigSource);
  final jbFiles = JbFiles(
    jbuildJar,
    configSource: configSource ?? defaultJbConfigSource,
  );

  final jvmExecutor = createJavaActor(
    dartleOptions.logLevel,
    jbuildJar.path,
    jbFiles.jvmCdsFile.absolute.path,
    config.javacArgs.javaRuntimeArgs().toList(growable: false),
  );

  final depsCache = createDepsActor(dartleOptions.logLevel);

  final compilationPathActor = createCompilationPathActor(
    dartleOptions.logLevel,
  );

  final runner = await JbRunner.create(
    jbFiles,
    config,
    JbActors(
      await jvmExecutor.toSendable(),
      await depsCache.toSendable(),
      await compilationPathActor.toSendable(),
    ),
  );

  try {
    await runner.run(dartleOptions);
  } finally {
    await jvmExecutor.close();
    await depsCache.close();
    await compilationPathActor.close();
  }
}

Future<JbConfiguration> _createConfig(ConfigSource configSource) async {
  try {
    return await configSource.load();
  } on DartleException {
    rethrow;
  } catch (e) {
    throw DartleException(
      message:
          'Unable to load jb config due to: $e.'
          '\nRun with the --help option to see usage.',
    );
  }
}
