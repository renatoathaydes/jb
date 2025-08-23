import 'dart:collection' show SplayTreeMap;

import 'package:collection/collection.dart' show IterableExtension;

import '../config.dart';

/// Given a set of dependencies, compute the warnings regarding version
/// conflicts.
Iterable<DependencyWarning> computeWarnings(
  List<ResolvedDependency> deps,
) sync* {
  // key: artifact
  // value: Map of (version, artifact:version String)
  final versionsByArtifact = SplayTreeMap<String, Map<String, String>>();

  // Find the artifacts that conflict with each other
  for (final dep in deps) {
    final parts = dep.artifact.split(':');
    if (parts.length < 3) {
      logger.warning(
        () =>
            'Invalid dependency declaration (should be <group:module:version>): '
            '${dep.artifact} ($dep)',
      );
    } else {
      final artifact = parts.sublist(0, 2).join(':');
      final version = parts.sublist(2).join(':');
      versionsByArtifact.update(artifact, (versions) {
        versions[version] = dep.artifact;
        return versions;
      }, ifAbsent: () => {version: dep.artifact});
    }
  }

  for (final entry in versionsByArtifact.entries) {
    final artifact = entry.key;
    final versions = entry.value;
    if (versions.length < 2) continue;
    logger.fine(
      () => 'Artifact "$artifact" has conflicting versions: ${versions.keys}',
    );
    final conflicts = versions.entries
        .map((v) {
          final version = v.key;
          final versionedArtifact = v.value;
          final chain = _requirementChain(
            deps,
            versionedArtifact,
          ).toList(growable: false).reversed.toList(growable: false);
          return VersionConflict(version: version, requestedBy: chain);
        })
        .sortedBy((c) => c.version)
        .toList(growable: false);
    yield DependencyWarning(artifact: artifact, versionConflicts: conflicts);
  }
}

const _maxChainDepth = 256;

Iterable<String> _requirementChain(
  List<ResolvedDependency> deps,
  String versionedArtifact,
) sync* {
  var currentDep = versionedArtifact;
  var depth = 0;
  startLoop:
  while (depth < _maxChainDepth) {
    for (final dep in deps) {
      // there's no chain if the dependency is direct
      if (dep.artifact == currentDep && dep.isDirect) return;
      if (dep.dependencies.contains(currentDep)) {
        yield dep.artifact;
        // we're done if this is a direct dependency
        if (dep.isDirect) return;
        // otherwise, find who depends on the currentDep
        currentDep = dep.artifact;
        depth++;
        continue startLoop;
      }
    }
    // should never get here
    break startLoop;
  }
  throw StateError(
    'Cannot find requirement chain for dependency "$versionedArtifact" '
    '(dependency tree depth higher than $_maxChainDepth)',
  );
}
