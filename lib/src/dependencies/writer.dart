import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:actors/actors.dart';
import 'package:dartle/dartle.dart';
import 'package:dartle/dartle_cache.dart' show DartleCache;
import 'package:path/path.dart' as paths;

import '../config.dart';
import '../java_tests.dart';
import '../jb_files.dart';
import '../jvm_executor.dart';
import '../resolved_dependency.dart';
import '../tasks.dart' show writeDepsTaskName;
import '../utils.dart';
import 'deps_cache.dart';
import 'parse.dart';

typedef _ExclusionsAndProjectDeps = (
  List<String>,
  Future<ResolvedDependencies>,
);

Future<void> writeDependencies(
  JBuildSender jBuildSender,
  List<String> preArgs,
  JbFiles jbFiles,
  DepsCache depsCache,
  DartleCache cache,
  Set<String> exclusions,
  Set<String> procExclusions,
  List<String> args, {
  required Map<String, DependencySpec> deps,
  required Map<String, DependencySpec> procDeps,
  required ResolvedLocalDependencies localDeps,
  required ResolvedLocalDependencies localProcDeps,
}) async {
  final projectDeps = _directProjectDeps(
    localDeps,
    depsCache,
    jbFiles,
    forProcessor: false,
  );
  final procProjectDeps = _directProjectDeps(
    localProcDeps,
    depsCache,
    jbFiles,
    forProcessor: true,
  );

  // TODO invoke 'jbuild fetch' to get SHA1:
  // e.g. jbuild fetch -d sha1-dir group:module:version:jar.sha1
  // and then read the file sha1-dir/<module>-<version>.jar.sha1
  final mainDeps = await _write(
    jBuildSender,
    preArgs,
    jbFiles,
    depsCache,
    deps,
    localDeps,
    exclusions,
    projectDeps,
    jbFiles.dependenciesFile,
  );
  await _write(
    jBuildSender,
    preArgs,
    jbFiles,
    depsCache,
    procDeps,
    localProcDeps,
    procExclusions,
    procProjectDeps,
    jbFiles.processorDependenciesFile,
  );
  final testRunnerLib = findTestRunnerLib(mainDeps);
  if (testRunnerLib != null) {
    logger.fine(() => 'Test runner library: $testRunnerLib');
  }
  final testRunnerLibs = Map.fromEntries(
    [?testRunnerLib].map(_testRunnerEntry),
  );

  await _write(
    jBuildSender,
    preArgs,
    jbFiles,
    depsCache,
    testRunnerLibs,
    ResolvedLocalDependencies.empty,
    const {},
    const [],
    jbFiles.testRunnerDependenciesFile,
  );
}

Iterable<_ExclusionsAndProjectDeps> _directProjectDeps(
  ResolvedLocalDependencies localDeps,
  DepsCache depsCache,
  JbFiles jbFiles, {
  required bool forProcessor,
}) sync* {
  for (final pd in localDeps.projectDependencies) {
    final futureDeps = depsCache.send(
      GetDeps(paths.join(pd.projectDir, jbFiles.dependenciesFile.path)),
    );
    final exclusions = pd.spec.exclusions;
    final rootExclusions = forProcessor ? pd.procExclusions : pd.exclusions;
    // each item includes the root Exclusions as well as the dep's exclusions
    // so that jb will resolve the exact same tree.
    yield ([...rootExclusions, ...exclusions], futureDeps);
  }
}

MapEntry<String, DependencySpec> _testRunnerEntry(String lib) {
  return MapEntry(lib, DependencySpec(scope: DependencyScope.all));
}

Future<ResolvedDependencies> _write(
  JBuildSender jBuildSender,
  List<String> preArgs,
  JbFiles jbFiles,
  DepsCache depsCache,
  Map<String, DependencySpec> deps,
  ResolvedLocalDependencies localDeps,
  Set<String> exclusions,
  Iterable<_ExclusionsAndProjectDeps> projectDeps,
  File depsFile,
) async {
  ResolvedDependencies? results;
  if (deps.isNotEmpty || projectDeps.isNotEmpty) {
    _checkDependenciesAreNotExcludedDirectly(deps, exclusions);

    final allDepsOptions = deps.entries
        .expand((d) => [d.key, ...d.value.exclusions.expand(_exclusionOption)])
        .followedBy(await projectDeps.expandToJBuildOptions().toList());

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
        ...allDepsOptions,
      ], _CollectorSendable(await collector.toSendable())),
    );
    results = await collector.send(const _Done());
  }
  results ??= const ResolvedDependencies(dependencies: [], warnings: []);

  await depsFile.withSink((sink) async {
    sink.write(jsonEncode(results));
  });
  await depsCache.send(AddDeps(depsFile.path, results));
  return results;
}

void _checkDependenciesAreNotExcludedDirectly(
  Map<String, DependencySpec> deps,
  Set<String> exclusions,
) {
  final exclusionPatterns = exclusions.map(RegExp.new).toList();
  final directExclusions = deps.keys
      .where((e) => exclusionPatterns.any((rgx) => rgx.hasMatch(e)))
      .toList();
  if (directExclusions.isNotEmpty) {
    final listMsg = directExclusions.map((dep) => '  - $dep').join('\n');
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
class _CollectorActor with Handler<_CollectorMessage, ResolvedDependencies?> {
  final _collector = JBuildDepsCollector();

  @override
  ResolvedDependencies? handle(_CollectorMessage message) {
    return switch (message) {
      _Line(line: var line) => () {
        _collector(line);
        return null;
      }(),
      _Done() => () {
        _collector.done();
        return _collector.resolvedDeps;
      }(),
    };
  }
}

/// Wrapper for [_CollectorActor]'s [Sendable] that has the necessary type.
class _CollectorSendable with Sendable<String, void> {
  final Sendable<_CollectorMessage, ResolvedDependencies?> delegate;

  _CollectorSendable(this.delegate);

  @override
  Future<void> send(String message) {
    return delegate.send(_Line(message));
  }
}

extension on Iterable<_ExclusionsAndProjectDeps> {
  Stream<String> expandToJBuildOptions() async* {
    for (final entry in this) {
      final (exclusions, depsFuture) = entry;
      final resolvedDeps = await depsFuture;
      for (final dep in resolvedDeps.dependencies) {
        if (dep.isDirect) {
          yield dep.artifact;
          yield* Stream.fromIterable(exclusions.expand(_exclusionOption));
        }
      }
    }
  }
}
