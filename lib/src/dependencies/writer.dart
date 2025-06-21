import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:actors/actors.dart';
import 'package:conveniently/conveniently.dart';
import 'package:dartle/dartle.dart';
import 'package:dartle/dartle_cache.dart' show DartleCache;

import '../config.dart';
import '../java_tests.dart';
import '../jvm_executor.dart';
import '../path_dependency.dart';
import '../tasks.dart' show writeDepsTaskName;
import '../utils.dart';
import 'parse.dart';

Future<void> writeDependencies(
  JBuildSender jBuildSender,
  List<String> preArgs,
  DartleCache cache,
  LocalDependencies localDependencies,
  Set<String> exclusions,
  LocalDependencies localProcessorDependencies,
  Set<String> procExclusions,
  List<String> args, {
  required Iterable<MapEntry<String, DependencySpec>> deps,
  required Iterable<MapEntry<String, DependencySpec>> procDeps,
  required File depsFile,
  required File processorDepsFile,
  required File testDepsFile,
}) async {
  // TODO invoke 'jbuild fetch' to get SHA1:
  // e.g. jbuild fetch -d sha1-dir group:module:version:jar.sha1
  // and then read the file sha1-dir/<module>-<version>.jar.sha1
  final mainDeps = await _write(
    jBuildSender,
    preArgs,
    deps,
    localDependencies,
    exclusions,
    depsFile,
  );
  await _write(
    jBuildSender,
    preArgs,
    procDeps,
    localProcessorDependencies,
    procExclusions,
    processorDepsFile,
  );
  final testRunnerLibs = [?findTestRunnerLib(mainDeps)].map(_testRunnerEntry);
  await _write(
    jBuildSender,
    preArgs,
    testRunnerLibs,
    LocalDependencies.empty,
    const {},
    testDepsFile,
  );
}

MapEntry<String, DependencySpec> _testRunnerEntry(String lib) {
  return MapEntry(lib, DependencySpec(scope: DependencyScope.all));
}

Future<List<ResolvedDependency>> _write(
  JBuildSender jBuildSender,
  List<String> preArgs,
  Iterable<MapEntry<String, DependencySpec>> deps,
  LocalDependencies localDeps,
  Set<String> exclusions,
  File depsFile,
) async {
  if (deps.isEmpty && localDeps.isEmpty) {
    await depsFile.withSink((sink) async {
      sink.write('[]');
    });
    return const [];
  }
  final results = <ResolvedDependency>[];
  if (deps.isNotEmpty) {
    _checkDependenciesAreNotExcludedDirectly(deps, exclusions);
    final collector = Actor.create(_CollectorActor.new);
    await jBuildSender.send(
      RunJBuild(writeDepsTaskName, [
        ...preArgs.where((n) => n != '-V'),
        'deps',
        '--transitive',
        '--licenses',
        '--scope',
        'runtime',
        ...exclusions.expand(_exclusionOption),
        ...deps.expand(
          (d) => [d.key, ...d.value.exclusions.expand(_exclusionOption)],
        ),
      ], _CollectorSendable(await collector.toSendable())),
    );
    (await collector.send(const _Done()))?.vmap(results.addAll);
  }

  results.addAll(localDeps.jars.map(_resolvedJar));
  results.addAll(localDeps.projectDependencies.map(_resolvedProject));

  await depsFile.withSink((sink) async {
    sink.write(jsonEncode(results));
  });
  return results;
}

void _checkDependenciesAreNotExcludedDirectly(
  Iterable<MapEntry<String, DependencySpec>> deps,
  Set<String> exclusions,
) {
  final exclusionPatterns = exclusions.map(RegExp.new).toList();
  final directExclusions = deps
      .where((e) => exclusionPatterns.any((rgx) => rgx.hasMatch(e.key)))
      .toList();
  if (directExclusions.isNotEmpty) {
    final listMsg = directExclusions.map((dep) => '  - ${dep.key}').join('\n');
    failBuild(
      reason:
          'Direct dependenc${directExclusions.length == 1 ? 'y is' : 'ies are'}'
          ' explicitly excluded:\n$listMsg',
    );
  }
}

List<String> _exclusionOption(String exclusion) {
  return ['-x', exclusion];
}

sealed class _CollectorMessage {
  const _CollectorMessage();
}

final class _Done extends _CollectorMessage {
  const _Done();
}

final class _Line extends _CollectorMessage {
  final String line;

  const _Line(this.line);
}

/// Actor that collects lines and passes them to [JBuildDepsCollector]
/// until a [_Done] message is received, when it returns the results.
class _CollectorActor
    with Handler<_CollectorMessage, List<ResolvedDependency>?> {
  final _collector = JBuildDepsCollector();

  @override
  List<ResolvedDependency>? handle(_CollectorMessage message) {
    return switch (message) {
      _Line(line: var line) => () {
        _collector(line);
        return null;
      }(),
      _Done() => () {
        _collector.done();
        return _collector.results;
      }(),
    };
  }
}

/// Wrapper for [_CollectorActor]'s [Sendable] that has the necessary type.
class _CollectorSendable with Sendable<String, void> {
  final Sendable<_CollectorMessage, List<ResolvedDependency>?> delegate;

  _CollectorSendable(this.delegate);

  @override
  Future<void> send(String message) {
    return delegate.send(_Line(message));
  }
}

ResolvedDependency _resolvedJar(JarDependency jar) => ResolvedDependency(
  artifact: jar.path,
  spec: jar.spec,
  sha1: '',
  kind: DependencyKind.localJar,
  isDirect: true,
  dependencies: const [],
);

ResolvedDependency _resolvedProject(ProjectDependency project) =>
    ResolvedDependency(
      artifact: project.path,
      spec: project.spec,
      sha1: '',
      kind: DependencyKind.localProject,
      isDirect: true,
      dependencies: const [],
    );
