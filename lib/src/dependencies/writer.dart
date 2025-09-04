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
import 'warnings.dart';

typedef _ExclusionsAndProjectDeps = (List<String>, ResolvedDependency);

Future<void> writeDependencies(
  JBuildSender jBuildSender,
  List<String> preArgs,
  JbFiles jbFiles,
  DepsCache depsCache,
  DartleCache cache,
  Set<String> exclusions,
  Set<String> procExclusions,
  List<String> args, {
  required Map<String, DependencySpec> nonLocalDeps,
  required Map<String, DependencySpec> nonLocalProcDeps,
  required ResolvedLocalDependencies localDeps,
  required ResolvedLocalDependencies localProcDeps,
}) async {
  final projectDeps = _projectDepsAndExclusions(
    localDeps,
    depsCache,
    jbFiles,
    forProcessor: false,
  );
  final procProjectDeps = _projectDepsAndExclusions(
    localProcDeps,
    depsCache,
    jbFiles,
    forProcessor: true,
  );

  // TODO invoke 'jbuild fetch' to get SHA1:
  // e.g. jbuild fetch -d sha1-dir group:module:version:jar.sha1
  // and then read the file sha1-dir/<module>-<version>.jar.sha1
  final mainDeps = await _write(
    'Project dependencies',
    jBuildSender,
    preArgs,
    jbFiles,
    depsCache,
    nonLocalDeps,
    exclusions,
    await projectDeps.toList(),
    jbFiles.dependenciesFile,
  );
  await _write(
    'Annotation processor dependencies',
    jBuildSender,
    preArgs,
    jbFiles,
    depsCache,
    nonLocalProcDeps,
    procExclusions,
    await procProjectDeps.toList(),
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
    'Test runner dependencies',
    jBuildSender,
    preArgs,
    jbFiles,
    depsCache,
    testRunnerLibs,
    const {},
    const [],
    jbFiles.testRunnerDependenciesFile,
  );
}

Stream<_ExclusionsAndProjectDeps> _projectDepsAndExclusions(
  ResolvedLocalDependencies localDeps,
  DepsCache depsCache,
  JbFiles jbFiles, {
  required bool forProcessor,
}) async* {
  for (final pd in localDeps.projectDependencies) {
    final projectDeps = await depsCache.send(
      GetDeps(paths.join(pd.projectDir, jbFiles.dependenciesFile.path)),
    );
    final exclusions = pd.spec.exclusions;
    final rootExclusions = forProcessor ? pd.procExclusions : pd.exclusions;
    yield (
      [...rootExclusions, ...exclusions],
      pd.toResolvedDependency(isDirect: true),
    );

    for (final dep in projectDeps.dependencies.where((d) => d.isDirect)) {
      yield (
        [...rootExclusions, ...exclusions, ...dep.spec.exclusions],
        dep.copyWith(isDirect: false),
      );
    }
  }

  for (final jar in localDeps.jars) {
    final rd = ResolvedDependency(
      artifact: jar.artifact,
      spec: jar.spec,
      sha1: '',
      isDirect: true,
      dependencies: const [],
    );
    yield (const [], rd);
  }
}

MapEntry<String, DependencySpec> _testRunnerEntry(String lib) {
  return MapEntry(lib, DependencySpec(scope: DependencyScope.all));
}

Future<ResolvedDependencies> _write(
  String description,
  JBuildSender jBuildSender,
  List<String> preArgs,
  JbFiles jbFiles,
  DepsCache depsCache,
  Map<String, DependencySpec> nonLocalDeps,
  Set<String> exclusions,
  List<_ExclusionsAndProjectDeps> projectDeps,
  File depsFile,
) async {
  ResolvedDependencies? results;
  if (nonLocalDeps.isNotEmpty || projectDeps.isNotEmpty) {
    _checkDependenciesAreNotExcludedDirectly(nonLocalDeps, exclusions);

    final nonLocalDepsOptions = nonLocalDeps.entries
        .map((e) => (e.key, e.value.exclusions))
        .expand((e) => [e.$1, ...e.$2.expand(_exclusionOption)]);

    final collector = Actor.create(
      wrapHandlerWithCurrentDir(_CollectorActor.new),
    );
    await jBuildSender.send(
      RunJBuild(writeDepsTaskName, [
        ...preArgs.where((n) => n != '-V'),
        'deps',
        '--transitive',
        '--licenses',
        '--scope',
        'runtime',
        ...exclusions.expand(_exclusionOption),
        ...nonLocalDepsOptions,
      ], _CollectorSendable(await collector.toSendable())),
    );

    // the Done response must NOT be null
    final allDeps = [...(await collector.send(const _Done()))!];

    for (final (_, dep) in projectDeps) {
      allDeps.add(dep);
    }

    logger.fine(() => '$description: found ${allDeps.length} dependencies');

    final stopwatch = Stopwatch()..start();
    final warnings = computeWarnings(allDeps).toList(growable: false);
    logger.log(
      profile,
      () =>
          '$description: computed ${warnings.length} '
          'warnings in ${elapsedTime(stopwatch)}',
    );
    results = ResolvedDependencies(dependencies: allDeps, warnings: warnings);
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
        return _collector.resolvedDeps.dependencies;
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
