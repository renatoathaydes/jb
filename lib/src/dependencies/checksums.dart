import 'dart:io';

import 'package:collection/collection.dart';
import 'package:conveniently/conveniently.dart' show ConvenientlyPredicate;
import 'package:dartle/dartle.dart'
    show deleteAll, file, tempDir, failBuild, profile, elapsedTime;
import 'package:path/path.dart' as p;

import '../config.dart' show logger;
import '../jb_files.dart';
import '../jvm_executor.dart';
import '../tasks.dart' show downloadDependenciesChecksumsTaskName;
import '../utils.dart';
import 'deps_cache.dart';

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

  final checksums = await _computeDependenciesChecksums(
    jBuildSender,
    preArgs,
    nonLocalDeps,
    await _parseChecksums(jbFiles.dependenciesChecksumFile),
  );

  await _writeChecksums(jbFiles.dependenciesChecksumFile, checksums);
}

Future<Map<String, String>> _computeDependenciesChecksums(
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
      RunJBuild(downloadDependenciesChecksumsTaskName, [
        ...preArgs,
        'fetch',
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

Future<Map<String, String>> _parseChecksums(
  File dependenciesChecksumFile,
) async {
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

Future<void> _writeChecksums(
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
