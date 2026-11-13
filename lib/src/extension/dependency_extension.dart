import 'dart:io';

import 'package:dartle/dartle.dart';
import 'package:path/path.dart' as p;

import '../compute_compilation_path.dart' show computeLibsCompilationPath;
import '../config.dart' show logger, CompileOutput, defaultSpec;
import '../crypto.dart' show computeSha1;
import '../dependencies/checksums.dart';
import '../dependencies/deps_cache.dart';
import '../dependencies/install.dart';
import '../dependencies/writer.dart' show resolveDependencies;
import '../jb_files.dart';
import '../tasks.dart' show checkDepsJavaVersion;
import '../utils.dart' show classpathSeparator;
import 'extension_pipeline.dart';
import 'jb_extension.dart';

/// Directory, inside `.jb-cache`, where dependency extensions are stored.
const _dependencyExtensionsDir = 'extension-dependencies';

/// Creates the tasks which load a dependency extension, given its coordinates.
///
/// The extension's dependency tree is resolved and stored as JSON, then its
/// artifacts are downloaded into a directory named after the coordinates, with
/// `:` replaced by `#` (so it's a valid directory name on Windows).
///
/// The directory is only created when it does not exist, and its artifacts
/// are only checked against their checksums when downloaded.
ExtensionTasks createDependencyExtensionTasks(
  String coordinates,
  ExtensionPipelineContext context,
) {
  final name = coordinates.replaceAll(':', '#');
  // tasks of dependency extensions are named after the artifact
  final [_, artifact, ...] = coordinates.split(':');
  final storeDir = p.join(JbFiles.jbCache, _dependencyExtensionsDir);
  final resolvedFile = p.absolute(p.join(storeDir, '$name.json'));
  final classpathDir = p.absolute(p.join(storeDir, name));
  final downloadingDir = p.absolute(p.join(storeDir, '$name.downloading'));
  final compPathFile = p.absolute(
    p.join(storeDir, '$name-compilation-path.json'),
  );

  final resolveTaskName = 'resolveExtension#$name';
  final downloadTaskName = 'downloadExtension#$name';
  final compPathTaskName = 'computeExtensionCompilationPath#$name';
  final javaCheckTaskName = 'checkExtensionJavaVersion#$name';
  final loadTaskName = 'loadExtension#$name';

  final resolve = Task(
    (_) => _resolveExtension(context, coordinates, resolvedFile),
    name: resolveTaskName,
    runCondition: MissingPathCondition(resolvedFile),
    description: 'Resolves the dependencies of extension $coordinates.',
  );
  final download = Task(
    (_) => _downloadExtension(
      context,
      coordinates,
      resolvedFile,
      classpathDir,
      downloadingDir,
      compPathFile,
    ),
    name: downloadTaskName,
    runCondition: MissingPathCondition(classpathDir),
    dependsOn: {resolveTaskName},
    description: 'Downloads the dependencies of extension $coordinates.',
  );
  final computePath = Task(
    (_) => computeLibsCompilationPath(
      compPathTaskName,
      artifact,
      context.jBuildPreArgs,
      context.jBuildSender,
      classpathDir,
      context.actors.compPath,
      compPathFile,
    ),
    name: compPathTaskName,
    runCondition: MissingPathCondition(compPathFile),
    dependsOn: {downloadTaskName},
    description: 'Computes the compilation path of extension $coordinates.',
  );
  final javaCheck = Task(
    (_) => checkDepsJavaVersion(
      context.actors.jvmExecutor,
      context.actors.compPath,
      artifact,
      classpathDir,
      compPathFile,
    ),
    name: javaCheckTaskName,
    runCondition: const AlwaysRun(),
    dependsOn: {compPathTaskName},
    description: 'Checks the Java version required by extension $coordinates.',
  );
  final load = Task(
    (_) => _loadDependencyExtension(
      context,
      coordinates,
      artifact,
      classpathDir,
      loadTaskName,
    ),
    name: loadTaskName,
    runCondition: const AlwaysRun(),
    dependsOn: {javaCheckTaskName},
    description: 'Loads the jb tasks of extension $coordinates.',
  );

  return ExtensionTasks(
    tasks: {resolve, download, computePath, javaCheck, load},
    loadTaskName: loadTaskName,
    downloadTaskName: downloadTaskName,
    resolvedDependenciesFile: resolvedFile,
  );
}

Future<void> _resolveExtension(
  ExtensionPipelineContext context,
  String coordinates,
  String resolvedFile,
) async {
  await File(resolvedFile).parent.create(recursive: true);
  await resolveDependencies(
    'Extension $coordinates',
    context.jBuildSender,
    context.jBuildPreArgs,
    context.actors.depsCache,
    {coordinates: defaultSpec},
    const {},
    const [],
    File(resolvedFile),
  );
}

Future<void> _downloadExtension(
  ExtensionPipelineContext context,
  String coordinates,
  String resolvedFile,
  String classpathDir,
  String downloadingDir,
  String compPathFile,
) async {
  final stopWatch = Stopwatch()..start();
  final resolved = await context.actors.depsCache.send(GetDeps(resolvedFile));
  final artifacts = resolved.dependencies
      .where((dep) => dep.spec.path == null)
      .map((dep) => dep.artifact)
      .toList(growable: false);

  final checksums = await computeDependenciesChecksums(
    context.jBuildSender,
    context.jBuildPreArgs,
    artifacts,
    await readChecksums(context.files.extensionDependenciesChecksumFile),
  );

  // download to a separate directory, so an interrupted download is not
  // mistaken for a complete one the next time
  final downloading = Directory(downloadingDir);
  if (await downloading.exists()) {
    await downloading.delete(recursive: true);
  }
  await downloading.create(recursive: true);
  try {
    await installArtifacts(
      'installExtension#$coordinates',
      context.jBuildSender,
      context.jBuildPreArgs,
      artifacts,
      downloadingDir,
      installToMavenLocal: false,
    );
    await _verifyChecksums(
      downloadingDir,
      checksums,
      context.files.extensionDependenciesChecksumFile.path,
    );
  } catch (_) {
    await ignoreExceptions(() => downloading.delete(recursive: true));
    rethrow;
  }

  // the compilation path must be computed again for the new artifacts
  await ignoreExceptions(File(compPathFile).delete);
  await downloading.rename(classpathDir);
  await updateExtensionChecksums(context.files, add: checksums);

  logger.log(
    profile,
    () =>
        "Downloaded extension dependency '$coordinates' in ${elapsedTime(stopWatch)}",
  );
}

/// Fails if any downloaded jar does not have the expected checksum.
Future<void> _verifyChecksums(
  String dir,
  Map<String, String> checksums,
  String checksumsFile,
) async {
  for (final entry in checksums.entries) {
    final parts = entry.key.split(':');
    if (parts.length < 3) continue;
    final jar = File(p.join(dir, '${parts[1]}-${parts[2]}.jar'));
    if (!await jar.exists()) continue;
    final expected = entry.value.trim();
    final actual = await computeSha1(jar.path);
    if (actual != expected) {
      failBuild(
        reason:
            'Checksum mismatch for ${entry.key}: expected $expected, '
            'but the downloaded jar has $actual. '
            'Remove its entry from $checksumsFile to record the checksum again.',
      );
    }
  }
}

Future<void> _loadDependencyExtension(
  ExtensionPipelineContext context,
  String coordinates,
  String artifact,
  String classpathDir,
  String loadTaskName,
) async {
  final jars = await _jarsIn(classpathDir);
  final jar = _findJar(coordinates, jars);
  final project = await loadExtensionProject(
    context,
    name: artifact,
    rootDir: classpathDir,
    classpath: jars.join(classpathSeparator),
    // the jar is stored in classpathDir, so it must be relative to it (like local extensions)
    output: CompileOutput.jar(p.basename(jar.path)),
    // this is only used for local extensions which may need to be re-built
    extensionUpToDate: true,
    // downloaded artifacts are never modified, so the jar is not checked
    outputMayChange: false,
  );
  context.loaded[loadTaskName] = project;
}

Future<List<String>> _jarsIn(String dir) async {
  final jars = await Directory(dir)
      .list()
      .where((f) => f is File && f.path.endsWith('.jar'))
      .map((f) => f.path)
      .toList();
  return jars..sort();
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
