import 'dart:io';

import 'package:conveniently/conveniently.dart';
import 'package:dartle/dartle.dart';
import 'package:dartle/dartle_cache.dart';
import 'package:io/ansi.dart' as ansi;

import 'config.dart';
import 'exec.dart';
import 'output_consumer.dart';
import 'pom.dart';
import 'resolved_dependency.dart';
import 'tasks.dart' show depsTaskName;

final class _Dependency {
  final String name;
  final DependencySpec spec;
  final String localSuffix;

  bool get isLocal => localSuffix.isNotEmpty;

  const _Dependency(this.name, this.spec, [this.localSuffix = '']);
}

class DepsArgValidator extends ArgsCount {
  static const flag = '--compile-scope';
  static const instance = DepsArgValidator._();

  const DepsArgValidator._() : super.range(min: 0, max: 1);

  bool isCompileScope(List<String> args) {
    final arg = args.firstOrNull;
    return arg != null && arg == flag;
  }

  @override
  bool validate(List<String> args) {
    final superResult = super.validate(args);
    if (!superResult) return false;
    final arg = args.firstOrNull;
    return arg == null || arg == flag;
  }

  @override
  String helpMessage() => 'Acceptable flags:\n'
      '        * $flag: show only compile-time dependencies.';
}

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
  final compileScope = DepsArgValidator.instance.isCompileScope(args);
  final scopeString = compileScope ? 'compile-time' : 'runtime';
  final mainDeps = _computeDependencies(
          localDependencies, config.allDependencies,
          compileTimeScope: compileScope)
      .toList(growable: false);
  final processorDeps = _computeDependencies(
          localProcessorDependencies, config.allProcessorDependencies,
          compileTimeScope: compileScope)
      .toList(growable: false);

  if (mainDeps.isEmpty && processorDeps.isEmpty) {
    logger.info(PlainMessage(
        'This project does not have any $scopeString dependencies!'));
    return 0;
  }

  final preArgs = config.preArgs(workingDir);

  var result = 0;
  if (mainDeps.isNotEmpty) {
    result = await _print(config, mainDeps, jbuildJar, preArgs,
        config.dependencyExclusionPatterns,
        header: 'This project has the following $scopeString dependencies:',
        compileTimeScope: compileScope);
  }
  if (result == 0 && processorDeps.isNotEmpty) {
    result = await _print(config, processorDeps, jbuildJar, preArgs,
        config.processorDependencyExclusionPatterns,
        header: 'Annotation processor $scopeString dependencies:',
        compileTimeScope: compileScope);
  }

  return result;
}

Iterable<_Dependency> _computeDependencies(LocalDependencies localDependencies,
    Iterable<MapEntry<String, DependencySpec>> dependencies,
    {required bool compileTimeScope}) {
  final bool Function(DependencyScope) scopeFilter = compileTimeScope
      ? (s) => s != DependencyScope.runtimeOnly
      : (s) => s != DependencyScope.compileOnly;
  return localDependencies.jars
      .where((j) => scopeFilter(j.spec.scope))
      .map((j) => _Dependency(j.path, j.spec, ' (local jar)'))
      .followedBy(localDependencies.projectDependencies
          .where((d) => scopeFilter(d.spec.scope))
          .map((d) => _Dependency(d.path, d.spec, ' (local project)')))
      .followedBy(dependencies
          .where(
              (dep) => dep.value.path == null && scopeFilter(dep.value.scope))
          .map((dep) => _Dependency(dep.key, dep.value)));
}

Artifact _createSimpleArtifact(JbConfiguration config) {
  return (
    group: config.group ?? 'group',
    module: config.module ?? 'module',
    name: config.name ?? 'name',
    version: config.version ?? '0.0.0',
    description: config.description,
    developers: config.developers,
    scm: config.scm,
    url: config.url,
    licenses: const [],
  );
}

Future<int> _print(JbConfiguration config, Iterable<_Dependency> deps,
    File jbuildJar, List<String> preArgs, Iterable<String> exclusionPatterns,
    {required String header, required bool compileTimeScope}) async {
  logger.info(AnsiMessage([
    AnsiMessagePart.code(ansi.styleItalic),
    AnsiMessagePart.code(ansi.styleBold),
    AnsiMessagePart.text(header)
  ]));

  _printLocalDependencies(deps.where((d) => d.isLocal));

  final nonLocalDeps = deps.where((d) => !d.isLocal);

  if (nonLocalDeps.isNotEmpty) {
    final artifact = _createSimpleArtifact(config);
    final pomFile = tempFile(extension: '.pom');
    logger.fine(() => 'Writing POM to ${pomFile.path}');
    await pomFile.writeAsString(createPom(artifact, nonLocalDeps.specEntries,
        const ResolvedLocalDependencies([], [])));

    return await execJBuild(
        depsTaskName,
        jbuildJar,
        preArgs,
        'deps',
        [
          '-t',
          '-s',
          compileTimeScope ? 'compile' : 'runtime',
          ...exclusionPatterns.expand((ex) => ['-x', ex]),
          '-p',
          pomFile.path,
        ],
        onStdout: _JBuildDepsPrinter());
  }
  return 0;
}

void _printLocalDependencies(Iterable<_Dependency> deps) {
  for (var dep in deps.map((s) => '* ${s.name} ${s.localSuffix}')) {
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

extension _Deps on Iterable<_Dependency> {
  Iterable<MapEntry<String, DependencySpec>> get specEntries =>
      map((dep) => MapEntry(dep.name, dep.spec));
}
