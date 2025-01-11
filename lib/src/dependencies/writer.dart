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
  final collector = _CollectorSendable();
  await jBuildSender.send(RunJBuild(writeDepsTaskName,
      [
        ...preArgs.where((n) => n != '-V'),
        'deps',
        '-t',
        '-s',
        'compile',
        ...deps
      ],
      collector));
  collector.delegate.done();
  await depsFile.withSink((sink) async {
    sink.write(jsonEncode(collector.delegate.results));
  });
}

class _CollectorSendable with Sendable<String, void> {
  final JBuildDepsCollector delegate = JBuildDepsCollector();

  @override
  Future<void> send(String message) async {
    delegate(message);
  }
}
