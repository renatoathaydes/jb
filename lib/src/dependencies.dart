import 'dart:io';

import 'package:conveniently/conveniently.dart';
import 'package:dartle/dartle.dart';
import 'package:dartle/dartle_cache.dart';
import 'package:io/ansi.dart' as ansi;

import 'config.dart';
import 'exec.dart';
import 'output_consumer.dart';
import 'tasks.dart' show depsTaskName;

Future<void> writeDependencies(
    {required File depsFile,
    required LocalDependencies localDeps,
    required LocalDependencies localProcessorDeps,
    required Iterable<MapEntry<String, DependencySpec>> deps,
    required Set<String> exclusions,
    required File processorDepsFile,
    required Iterable<MapEntry<String, DependencySpec>> processorDeps,
    required Set<String> processorsExclusions}) async {
  await _withFile(depsFile, (handle) async {
    handle.write('dependencies:\n');
    await _writeDeps(handle, deps, exclusions, localDeps);
  });
  await _withFile(processorDepsFile, (handle) async {
    handle.write('processor-dependencies:\n');
    await _writeDeps(
        handle, processorDeps, processorsExclusions, localProcessorDeps);
  });
}

Future<void> _withFile(File file, Future<void> Function(IOSink) action) async {
  final handle = file.openWrite();
  try {
    await action(handle);
  } finally {
    await handle.flush();
    await handle.close();
  }
}

Future<void> _writeDeps(
    IOSink sink,
    Iterable<MapEntry<String, DependencySpec>> deps,
    Set<String> exclusions,
    LocalDependencies localDeps) async {
  final nonLocalDeps = deps
      .where((e) => e.value.path == null)
      .toList(growable: false)
    ..sort((a, b) => a.key.compareTo(b.key));
  for (final entry in nonLocalDeps) {
    _writeDep(sink, entry.key, entry.value);
  }
  for (final jarDep in [...localDeps.jars]
    ..sort((a, b) => a.path.compareTo(b.path))) {
    _writeDep(sink, "${jarDep.path} (jar)", jarDep.spec);
  }
  for (final subProject in [...localDeps.projectDependencies]
    ..sort((a, b) => a.path.compareTo(b.path))) {
    _writeDep(sink, "${subProject.path} (sub-project)", subProject.spec);
  }
  if (exclusions.isNotEmpty) {
    sink.write('exclusions:\n');
    for (final exclusion in [...exclusions]..sort()) {
      sink
        ..write('  - ')
        ..write(exclusion)
        ..write('\n');
    }
  }
}

void _writeDep(IOSink sink, String name, DependencySpec spec) {
  sink
    ..write('  - ')
    ..write(name)
    ..write(':\n');
  if (spec != defaultSpec) {
    spec.path?.vmap((path) => sink
      ..write('    path: ')
      ..write(path)
      ..write('\n'));
    sink
      ..write('    scope: ')
      ..write(spec.scope.name)
      ..write('\n')
      ..write('    transitive: ')
      ..write(spec.transitive)
      ..write('\n');
  }
}

Future<int> printDependencies(
    File jbuildJar,
    JbConfiguration config,
    String workingDir,
    DartleCache cache,
    LocalDependencies localDependencies,
    LocalDependencies localProcessorDependencies,
    List<String> args) async {
  final deps = config.allDependencies
      .where((dep) => dep.value.path == null)
      .map((dep) => dep.key);
  final procDeps = config.allProcessorDependencies
      .where((dep) => dep.value.path == null)
      .map((dep) => dep.key);

  if (deps.isEmpty &&
      procDeps.isEmpty &&
      localDependencies.isEmpty &&
      localProcessorDependencies.isEmpty) {
    logger.info(
        const PlainMessage('This project does not have any dependencies!'));
    return 0;
  }

  final preArgs = config.preArgs(workingDir);
  var result = 0;
  if (deps.isNotEmpty || localDependencies.isNotEmpty) {
    result = await _print(deps, localDependencies, jbuildJar, preArgs,
        config.dependencyExclusionPatterns,
        header: 'This project has the following dependencies:');
  }
  if (result == 0 &&
      (procDeps.isNotEmpty || localProcessorDependencies.isNotEmpty)) {
    result = await _print(procDeps, localProcessorDependencies, jbuildJar,
        preArgs, config.processorDependencyExclusionPatterns,
        header: 'Annotation processor dependencies:');
  }

  return result;
}

Future<int> _print(Iterable<String> deps, LocalDependencies localDeps,
    File jbuildJar, List<String> preArgs, Iterable<String> exclusionPatterns,
    {required String header}) async {
  logger.info(AnsiMessage([
    AnsiMessagePart.code(ansi.styleItalic),
    AnsiMessagePart.code(ansi.styleBold),
    AnsiMessagePart.text(header)
  ]));

  _printLocalDependencies(localDeps);

  if (deps.isNotEmpty) {
    return await execJBuild(
        depsTaskName,
        jbuildJar,
        preArgs,
        'deps',
        [
          '-t',
          '-s',
          'compile',
          ...exclusionPatterns.expand((ex) => ['-x', ex]),
          ...deps
        ],
        onStdout: _JBuildDepsPrinter());
  }
  return 0;
}

void _printLocalDependencies(LocalDependencies localDependencies) {
  for (var dep in localDependencies.jars
      .map((j) => '* ${j.path} [${j.spec.scope.name}] (local jar)')
      .followedBy(localDependencies.projectDependencies
          .map((s) => '* ${s.path} [${s.spec.scope.name}] (sub-project)'))) {
    logger.info(ColoredLogMessage(dep, LogColor.magenta));
  }
}

class _JBuildDepsPrinter implements ProcessOutputConsumer {
  int pid = -1;

  @override
  void call(String line) {
    if (line.startsWith('Dependencies of ')) {
      _logDirectDependency(line);
    } else if (line.startsWith('  - scope')) {
      _logScopeLine(line);
    } else if (line.isDependency()) {
      _logDependency(line);
    } else if (line.endsWith('is required with more than one version:')) {
      _logDependencyWarning(line);
    } else {
      logger.info(PlainMessage(line));
    }
  }

  void _logDirectDependency(String line) {
    logger.info(ColoredLogMessage(
        '* ${line.substring('Dependencies of '.length)}', LogColor.magenta));
  }

  void _logScopeLine(String line) {
    logger.info(ColoredLogMessage(line, LogColor.blue));
  }

  void _logDependencyWarning(String line) {
    logger.info(ColoredLogMessage(line, LogColor.yellow));
  }

  void _logDependency(String line) {
    if (line.endsWith('(-)')) {
      logger.info(ColoredLogMessage(line, LogColor.gray));
    } else {
      logger.info(PlainMessage(line));
    }
  }
}

final _depPattern = RegExp(r'^\s+\*\s');

extension _DepString on String {
  bool isDependency() {
    return _depPattern.hasMatch(this);
  }
}
