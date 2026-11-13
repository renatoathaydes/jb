import 'dart:io';

import 'package:actors/actors.dart' show Sendable;
import 'package:dartle/dartle.dart';
import 'package:dartle/dartle_cache.dart';
import 'package:path/path.dart' as p;

import '../config.dart' show logger, CompileOutput, JbConfigExtension;
import '../config_import.dart';
import '../extension/jb_extension.dart';
import '../jb_actors.dart';
import '../jb_config.g.dart' show JbConfiguration;
import '../jb_files.dart';
import '../jvm_executor.dart';
import '../utils.dart' show classpathSeparator;

/// Load an [ExtensionProject] from a dependency's coordinates.
///
/// The dependency is fetched with its own dependencies into the [DartleCache]
/// and then re-used without checks if it already exists. Each dependency is
/// stored in a directory under `extension-dependencies/<dep-name>` where
/// `<dep-name>` is the coordinate, but with `:` replaced with `#`
/// (so it's a valid directory name in Windows).
Future<ExtensionProject> loadExtensionFromDep(
  String coordinates,
  JbFiles files,
  JbActors actors,
  Options options,
  JbConfigWithImports cwi,
  DartleCache cache,
) async {
  final name = coordinates.replaceAll(':', '#');
  // tasks of dependency extensions are named after the artifact
  final [_, artifact, ...] = coordinates.split(':');
  final depDir = Directory(
    p.join(cache.rootDir, 'extension-dependencies', name),
  );
  if (await depDir.exists()) {
    logger.fine(() => 'Using cached extension dependency at ${depDir.path}');
  } else {
    logger.fine(
      () => "Fetching extension dependency '$coordinates' to ${depDir.path}",
    );
    await depDir.create(recursive: true);
    await _fetchDependencies(
      coordinates,
      cwi.config,
      actors.jvmExecutor,
      out: depDir,
    );
  }
  final classpath = await depDir
      .list()
      .where((f) => f is File && f.path.endsWith('.jar'))
      .map((f) => f.path)
      .toList();
  final jar = _findJar(coordinates, classpath);

  final extensionModel = await createJbExtensionModel(
    // the jar is stored in depDir, so it must be relative to it (like local extensions)
    CompileOutput.jar(p.basename(jar.path)),
    cwi.config,
    artifact,
    depDir.path,
    classpath.join(classpathSeparator),
    cache,
    actors.jvmExecutor.takingJavaCommands(),
    // this is only used for local extensions we may need to re-build
    extensionUpToDate: true,
  );

  return ExtensionProject(
    artifact,
    depDir.path,
    classpath.join(classpathSeparator),
    extensionModel,
  );
}

File _findJar(String coordinates, List<String> classpath) {
  final [_, module, ...] = coordinates.split(':');
  for (final jar in classpath) {
    if (jar.contains(module)) {
      logger.finer(() => "Found jar for '$coordinates': $jar");
      return File(jar);
    }
  }
  failBuild(
    reason:
        'Unable to find jar for extension project "$coordinates". '
        'Looked for it in jars: $classpath. '
        'This may be a bug in jb!',
  );
}

Future<void> _fetchDependencies(
  String coordinates,
  JbConfiguration config,
  Sendable<JvmExecutorMessage, Object?> jvmExecutor, {
  required Directory out,
}) async {
  final stopWatch = Stopwatch()..start();
  await jvmExecutor.send(
    RunJBuild(
      'install-extension-$coordinates',
      config.preArgs(Directory.current.path),
      'install',
      [coordinates, '-d', out.path],
    ),
  );
  logger.log(
    profile,
    () =>
        "Fetched extension dependency '$coordinates' in ${elapsedTime(stopWatch)}",
  );
}
