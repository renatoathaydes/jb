import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'compile/groovy.dart';
import 'config.dart';
import 'java_tests.dart' show TestConfig;

/// Information about some known dependencies.
/// See also [TestConfig].
class KnownDependencies {
  final bool groovy;

  const KnownDependencies({required this.groovy});
}

/// Create test configurations.
KnownDependencies createKnownDeps(
  Iterable<MapEntry<String, DependencySpec>> dependencies,
) {
  return KnownDependencies(groovy: hasGroovyDependency(dependencies));
}

sealed class Dependencies {
  FutureOr<List<String>> resolveArtifacts();

  const Dependencies();
}

final class FileDependencies extends Dependencies {
  final File file;
  final bool Function(DependencyScope) scopeFilter;

  const FileDependencies(this.file, this.scopeFilter);

  @override
  Future<List<String>> resolveArtifacts() async {
    return (jsonDecode(await file.readAsString()) as List)
        .map(ResolvedDependency.fromJson)
        .where(
          (dep) =>
              dep.kind == DependencyKind.maven && scopeFilter(dep.spec.scope),
        )
        .map((dep) => dep.artifact)
        .toList(growable: false);
  }
}

final class SimpleDependencies extends Dependencies {
  final List<String> artifacts;

  const SimpleDependencies(this.artifacts);

  @override
  List<String> resolveArtifacts() {
    return artifacts;
  }
}
