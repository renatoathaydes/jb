import 'dart:async';
import 'dart:io';

import 'compile/groovy.dart';
import 'config.dart' show DependencySpec, DependencyScope;
import 'dependencies/deps_cache.dart';

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
  FutureOr<List<String>> resolveArtifacts({required bool includeLocal});

  const Dependencies();
}

final class FileDependencies extends Dependencies {
  final File file;
  final DepsCache depsCache;
  final bool Function(DependencyScope) scopeFilter;

  const FileDependencies(this.file, this.depsCache, this.scopeFilter);

  @override
  Future<List<String>> resolveArtifacts({required bool includeLocal}) async {
    return (await depsCache.send(GetDeps(file.path))).dependencies
        .where(
          (dep) =>
              scopeFilter(dep.spec.scope) &&
              (includeLocal || dep.spec.path == null),
        )
        .map((dep) => dep.artifact)
        .toList(growable: false);
  }
}
