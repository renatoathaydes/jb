import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'config.dart';

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
        .where((dep) =>
            dep.kind == DependencyKind.maven && scopeFilter(dep.spec.scope))
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
