import 'dart:io';

import 'package:collection/collection.dart';
import 'package:conveniently/conveniently.dart' show ConvenientlyPredicate;
import 'package:dartle/dartle.dart'
    show deleteAll, file, tempDir, failBuild, profile, elapsedTime;
import 'package:path/path.dart' as p;

import '../crypto.dart' show computeSha1;
import '../config.dart' show logger;
import '../jb_files.dart';
import '../jvm_executor.dart';
import '../tasks.dart' show downloadDependenciesChecksumsTaskName;
import '../utils.dart';
import 'deps_cache.dart';

/// Downloads the checksums of the dependencies
Future<void> downloadDependenciesChecksums(
  JbFiles jbFiles,
  List<String> preArgs,
  JBuildSender jBuildSender,
  DepsCache depsCache,
) async {
  final deps = await depsCache.send(GetDeps(jbFiles.dependenciesFile.path));
  final procDeps = await depsCache.send(
    GetDeps(jbFiles.processorDependenciesFile.path),
  );
  final nonLocalDeps = deps.dependencies
      .followedBy(procDeps.dependencies)
      .where((dep) => dep.spec.path == null)
      .map((dep) => dep.artifact);

  final checksums = await computeDependenciesChecksums(
    jBuildSender,
    preArgs,
    nonLocalDeps,
    await readChecksums(jbFiles.dependenciesChecksumFile),
  );

  await writeChecksums(jbFiles.dependenciesChecksumFile, checksums);
}

/// Returns the checksum of each of the [nonLocalDeps] artifacts (`g:a:v`).
///
/// Checksums already in [currentChecksums] are re-used, the others are fetched
/// from the repositories with JBuild.
Future<Map<String, String>> computeDependenciesChecksums(
  JBuildSender jBuildSender,
  List<String> preArgs,
  Iterable<String> nonLocalDeps,
  Map<String, String> currentChecksums,
) async {
  final tempDirectory = tempDir(suffix: '-jb-checksums');
  final knownChecksums = currentChecksums.keys.toSet();
  final unknownDeps = nonLocalDeps.where(knownChecksums.contains.not$);

  // start with all dependencies whose checksum are already known
  final result = {
    for (final e in currentChecksums.entries)
      if (nonLocalDeps.contains(e.key)) e.key: e.value,
  };

  if (result.isNotEmpty) {
    logger.fine(
      () => 'Known checksums will not be re-computed: ${result.keys}',
    );
  }

  if (unknownDeps.isNotEmpty) {
    logger.fine(() => 'Will request checksum for dependencies: $unknownDeps');
    final stopWatch = Stopwatch()..start();
    await jBuildSender.send(
      RunJBuild(downloadDependenciesChecksumsTaskName, preArgs, 'fetch', [
        '-d',
        tempDirectory.path,
        ...unknownDeps.map((dep) => '$dep:jar.sha1'),
      ]),
    );
    for (final dep in unknownDeps) {
      // org:artifact:version:extension:classifier
      final depParts = dep.split(':');
      if (depParts.length < 3) {
        throw failBuild(reason: 'Invalid dependency syntax: $dep');
      }
      final artifact = depParts[1];
      final version = depParts[2];
      result[dep] = await File(
        p.join(tempDirectory.path, '$artifact-$version.jar.sha1'),
      ).readAsString();
    }
    logger.log(
      profile,
      () => 'Loaded dependencies checksums in ${elapsedTime(stopWatch)}',
    );
  }

  return result;
}

/// Reads a checksums file (`<dependency> <checksum>` per line).
///
/// Returns an empty map if the file does not exist.
Future<Map<String, String>> readChecksums(File dependenciesChecksumFile) async {
  if (!await dependenciesChecksumFile.exists()) {
    return const {};
  }
  final lines = await dependenciesChecksumFile.readAsLines();
  return Map.fromEntries(
    lines.mapIndexed((index, line) {
      if (line.isEmpty || line.startsWith('#')) return null;
      final checksumIndex = line.lastIndexOf(' ');
      if (checksumIndex < 0 || checksumIndex == line.length - 1) {
        failBuild(
          reason:
              'Invalid line [${index + 1}] in ${dependenciesChecksumFile.path},'
              ' should be of form "<dependency> <checksum>": $line',
        );
      }
      return MapEntry(
        line.substring(0, checksumIndex),
        line.substring(checksumIndex + 1),
      );
    }).nonNulls,
  );
}

/// Writes the checksums to the file, sorted by dependency.
///
/// The file is deleted if there are no checksums.
Future<void> writeChecksums(
  File dependenciesChecksumFile,
  Map<String, String> checksums,
) async {
  if (checksums.isEmpty) {
    await deleteAll(file(dependenciesChecksumFile.path));
    return;
  }
  await dependenciesChecksumFile.withSink((sink) async {
    for (final entry in checksums.entries.sorted(
      (a, b) => compareAsciiLowerCase(a.key, b.key),
    )) {
      sink.writeln('${entry.key} ${entry.value}');
    }
  });
}

/// Fails if any downloaded jar does not have the expected checksum.
Future<void> verifyChecksums(
  String dir,
  Map<String, String> checksums,
  String checksumsFile,
) async {
  final errors = <String>[];
  for (final entry in checksums.entries) {
    final parts = entry.key.split(':');
    if (parts.length < 3) continue;
    final jar = File(p.join(dir, '${parts[1]}-${parts[2]}.jar'));
    if (!await jar.exists()) continue;
    final expected = entry.value.trim();
    final actual = await computeSha1(jar.path);
    if (actual != expected) {
      errors.add(
        'Checksum mismatch for ${entry.key}: expected $expected, '
        'but the downloaded jar has $actual.\n'
        '**Delete the jar ${jar.path} as it may be corrupted.**\n'
        'If you trust the source of the jar, remove its entry from '
        '$checksumsFile and retry to record the checksum.',
      );
    }
  }
  if (errors.isNotEmpty) {
    failBuild(reason: errors.join('\n\n'));
  }
}
