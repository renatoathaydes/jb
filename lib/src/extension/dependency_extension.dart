import 'dart:io';

import 'package:actors/actors.dart' show Sendable;
import 'package:dartle/dartle.dart';
import 'package:dartle/dartle_cache.dart';
import 'package:jb/jb.dart';
import 'package:jb/src/jvm_executor.dart';
import 'package:path/path.dart' as p;

import '../jb_actors.dart';
import '../utils.dart' show classpathSeparator;

Future<ExtensionProject> loadExtensionFromDep(
  String coordinates,
  JbFiles files,
  JbActors actors,
  Options options,
  JbConfigWithImports cwi,
  DartleCache cache,
) async {
  final name = coordinates.replaceAll(':', '#');
  final depDir = Directory(
    p.join(cache.rootDir, 'extension-dependencies', name),
  );
  if (!await depDir.exists()) {
    await depDir.create(recursive: true);
    await _fetchDependencies(coordinates, actors.jvmExecutor, out: depDir);
  }
  final classpath = await depDir
      .list()
      .where((f) => f is File && f.path.endsWith('.jar'))
      .map((f) => f.path)
      .toList();
  final jar = _findJar(coordinates, classpath);

  final extensionModel = await createJbExtensionModel(
    CompileOutput.jar(jar.path),
    cwi.config,
    name,
    depDir.path,
    classpath.join(classpathSeparator),
    cache,
    actors.jvmExecutor.takingJavaCommands(),
    // FIXME how do we know if the extension tasks are up-to-date?
    extensionUpToDate: false,
  );

  return ExtensionProject(
    name,
    depDir.path,
    classpath.join(classpathSeparator),
    extensionModel,
  );
}

File _findJar(String coordinates, List<String> classpath) {
  final [_, module, ...] = coordinates.split(':');
  for (final jar in classpath) {
    if (jar.contains(module)) {
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
  Sendable<JvmExecutorMessage, Object?> jvmExecutor, {
  required Directory out,
}) async {
  await jvmExecutor.send(
    RunJBuild('install-extension-$coordinates', const [], 'install', [
      coordinates,
      '-d',
      out.path,
    ]),
  );
}
