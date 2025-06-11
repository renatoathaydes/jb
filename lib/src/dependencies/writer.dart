import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:actors/actors.dart';
import 'package:dartle/dartle_cache.dart' show DartleCache;

import '../config.dart';
import '../java_tests.dart';
import '../jvm_executor.dart';
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
  required TestConfig testConfig,
}) async {
  await _write(jBuildSender, preArgs, deps, exclusions, depsFile);
  await _write(
      jBuildSender, preArgs, procDeps, procExclusions, processorDepsFile);

  final testDeps = [
    if (testConfig.apiVersion != null) junitConsoleLib(testConfig),
    if (testConfig.spockVersion != null) ...[
      spockRunnerLib(testConfig),
      if (testConfig.apiVersion == null) junitConsoleLib(testConfig),
    ],
  ].map(_testRunnerEntry);

  await _write(jBuildSender, preArgs, testDeps, const {}, testDepsFile);
}

MapEntry<String, DependencySpec> _testRunnerEntry(String lib) {
  return MapEntry(lib, DependencySpec(scope: DependencyScope.all));
}

Future<void> _write(
  JBuildSender jBuildSender,
  List<String> preArgs,
  Iterable<MapEntry<String, DependencySpec>> deps,
  Set<String> exclusions,
  File depsFile,
) async {
  if (deps.isEmpty) {
    return await depsFile.withSink((sink) async {
      sink.write('[]');
    });
  }
  final collector = Actor.create(_CollectorActor.new);
  await jBuildSender.send(RunJBuild(
      writeDepsTaskName,
      [
        ...preArgs.where((n) => n != '-V'),
        'deps',
        '-t',
        '-s',
        'runtime',
        ...exclusions.expand(_exclusionOption),
        ...deps.expand(
            (d) => [d.key, ...d.value.exclusions.expand(_exclusionOption)])
      ],
      _CollectorSendable(await collector.toSendable())));
  final results = await collector.send(const _Done());
  await depsFile.withSink((sink) async {
    sink.write(jsonEncode(results));
  });
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
