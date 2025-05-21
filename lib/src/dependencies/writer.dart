import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:actors/actors.dart';
import 'package:dartle/dartle_cache.dart' show DartleCache;

import '../config.dart';
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
  required Set<String> deps,
  required Set<String> procDeps,
  required File depsFile,
  required File processorDepsFile,
}) async {
  // TODO handle localDependencies and exclusions
  final depsFuture = _write(jBuildSender, preArgs, deps, depsFile);
  final procDepsFuture =
      _write(jBuildSender, preArgs, procDeps, processorDepsFile);
  await Future.wait([depsFuture, procDepsFuture]);
}

Future<void> _write(
  JBuildSender jBuildSender,
  List<String> preArgs,
  Set<String> deps,
  File depsFile,
) async {
  final collector = Actor.create(_CollectorActor.new);
  await jBuildSender.send(RunJBuild(
      writeDepsTaskName,
      [
        ...preArgs.where((n) => n != '-V'),
        'deps',
        '-t',
        '-s',
        'compile',
        ...deps
      ],
      _CollectorSendable(await collector.toSendable())));
  final results = await collector.send(const _Done());
  await depsFile.withSink((sink) async {
    sink.write(jsonEncode(results));
  });
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
