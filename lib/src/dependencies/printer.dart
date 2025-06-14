import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:conveniently/conveniently.dart';
import 'package:dartle/dartle.dart'
    show
        ArgsValidator,
        AnsiMessage,
        AnsiMessagePart,
        ColoredLogMessage,
        LogColor,
        PlainMessage;
import 'package:dartle/dartle_cache.dart' show DartleCache;
import 'package:io/ansi.dart' show magenta, styleBold, yellow, styleItalic;

import '../config.dart';
import '../jb_files.dart';
import '../pom.dart';
import '../tasks.dart' show depsTaskName;

final class _Dependency {
  final String name;
  final DependencySpec spec;
  final String localSuffix;

  const _Dependency(this.name, this.spec, this.localSuffix);
}

class _DepsArgs {
  final DependencyScope scope;
  final bool showLicenses;
  final List<String> rest;

  const _DepsArgs({
    DependencyScope? scope,
    bool? showLicenses,
    required this.rest,
  }) : scope = scope ?? DependencyScope.all,
       showLicenses = showLicenses ?? false;
}

class DepsArgValidator with ArgsValidator {
  static const scopeFlag = 'scope';
  static const licensesFlag = 'show-licenses';

  const DepsArgValidator();

  @override
  bool validate(List<String> args) {
    try {
      return _parse(args).rest.isEmpty;
    } on FormatException catch (e) {
      logger.warning('Invalid arguments for $depsTaskName: ${e.message}');
      return false;
    }
  }

  _DepsArgs _parse(List<String> args) {
    final parser = ArgParser()
      ..addOption(
        scopeFlag,
        abbr: 's',
        help: 'the scope to include',
        defaultsTo: DependencyScope.all.name,
        allowed: DependencyScope.values.map((s) => s.name),
      )
      ..addFlag(
        licensesFlag,
        abbr: 'l',
        help: 'show licenses of dependencies',
        defaultsTo: false,
      );

    final ArgResults result = parser.parse(args);
    return _DepsArgs(
      showLicenses: result.flag(licensesFlag),
      scope: result.option(scopeFlag)?.vmap((s) => DependencyScope.from(s)),
      rest: result.rest,
    );
  }

  @override
  String helpMessage() =>
      'Acceptable options:\n'
      '        * $scopeFlag <scope>: the scope of dependencies. One of ${DependencyScope.values.map((s) => s.name)}.\n'
      '        * $licensesFlag: show dependencies\' licenses.';
}

Future<void> printDependencies(
  JbFiles jbFiles,
  JbConfiguration config,
  String workingDir,
  DartleCache cache,
  LocalDependencies localDependencies,
  LocalDependencies localProcessorDependencies,
  List<String> args,
) async {
  final options = const DepsArgValidator()._parse(args);
  final scope = options.scope;
  final mainLocalDeps = _getLocalDependencies(
    localDependencies,
    config.allDependencies,
    scope: scope,
  ).toList(growable: false);
  final processorLocalDeps = _getLocalDependencies(
    localProcessorDependencies,
    config.allProcessorDependencies,
    scope: scope,
  ).toList(growable: false);
  final mainDeps = (await _parseDeps(
    jbFiles.dependenciesFile,
  )).where((dep) => scope.includes(dep.spec.scope)).toList(growable: false);
  final processorDeps = (await _parseDeps(
    jbFiles.processorDependenciesFile,
  )).where((dep) => scope.includes(dep.spec.scope)).toList(growable: false);

  final artifact = _createSimpleArtifact(config);

  if ([
    mainLocalDeps,
    processorLocalDeps,
    mainDeps,
    processorDeps,
  ].every((d) => d.isEmpty)) {
    logger.info(
      PlainMessage(
        'Project ${artifact.identifier} does not have any dependencies'
        '${scope == DependencyScope.all ? '' : ' with scope ${scope.name}'}!',
      ),
    );
    return;
  }

  final printer = _JBuildDepsPrinter(options.showLicenses);
  if (mainDeps.isNotEmpty || mainLocalDeps.isNotEmpty) {
    printer
      ..header(artifact, scope)
      ..print(mainDeps, options)
      ..printLocal(mainLocalDeps);
  }
  if (processorLocalDeps.isNotEmpty || processorDeps.isNotEmpty) {
    printer
      ..header(artifact, scope, forProcessor: true)
      ..print(processorDeps, options)
      ..printLocal(processorLocalDeps);
  }
}

Iterable<_Dependency> _getLocalDependencies(
  LocalDependencies localDependencies,
  Iterable<MapEntry<String, DependencySpec>> dependencies, {
  required DependencyScope scope,
}) {
  return localDependencies.jars
      .where((j) => scope.includes(j.spec.scope))
      .map((j) => _Dependency(j.path, j.spec, ' (local jar)'))
      .followedBy(
        localDependencies.projectDependencies
            .where((d) => scope.includes(d.spec.scope))
            .map((d) => _Dependency(d.path, d.spec, ' (local project)')),
      );
}

Future<Iterable<ResolvedDependency>> _parseDeps(File file) async {
  final text = await file.readAsString();
  return (jsonDecode(text) as List).map(ResolvedDependency.fromJson);
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

class _JBuildDepsPrinter {
  bool showLicenses;

  _JBuildDepsPrinter(this.showLicenses);

  void header(
    Artifact artifact,
    DependencyScope scope, {
    bool forProcessor = false,
  }) {
    final scopeMsg = scope == DependencyScope.all
        ? ''
        : 'with scope ${scope.name}';
    final prefix = forProcessor
        ? 'Annotation processor dependencies'
        : 'Dependencies';
    logger.info(
      AnsiMessage([
        AnsiMessagePart.code(styleItalic),
        AnsiMessagePart.text('$prefix of '),
        AnsiMessagePart.code(styleBold),
        AnsiMessagePart.code(magenta),
        AnsiMessagePart.text('${artifact.identifier}$scopeMsg:'),
      ]),
    );
  }

  void print(List<ResolvedDependency> deps, _DepsArgs options) {
    final map = deps.toMap();
    final visited = <String>{};
    map.forEach((dep, spec) {
      _printTree(dep, map, visited, options);
    });
  }

  void _printTree(
    String dep,
    Map<String, ResolvedDependency> map,
    Set<String> visited,
    _DepsArgs options, {
    String indent = '  ',
  }) {
    final dependency = map[dep]!;
    if (dependency.kind != DependencyKind.maven) {
      return;
    }
    if (indent == '  ' && !dependency.isDirect) {
      // indirect dependency is printed in its parent tree
      return;
    }
    if (visited.add(dep)) {
      if (indent != '  ' && dependency.isDirect) {
        _printVisited(dep, indent: indent);
        visited.remove(dep);
        return;
      }
      final licenseParts = options.showLicenses && dependency.license.isNotEmpty
          ? [
              AnsiMessagePart.code(styleBold),
              AnsiMessagePart.code(yellow),
              AnsiMessagePart.text(' [${dependency.license}]'),
            ]
          : const [];
      logger.info(
        AnsiMessage([
          AnsiMessagePart.code(magenta),
          AnsiMessagePart.text("$indent* $dep"),
          ...licenseParts,
        ]),
      );
      for (final ddep in dependency.dependencies) {
        _printTree(ddep, map, visited, options, indent: '  $indent');
      }
    } else {
      _printVisited(dep, indent: indent);
    }
  }

  void _printVisited(String dep, {required String indent}) {
    logger.info(ColoredLogMessage("$indent* $dep (-)", LogColor.gray));
  }

  void printLocal(List<_Dependency> localDeps) {
    for (var dep in localDeps.map((s) => '  * ${s.name} ${s.localSuffix}')) {
      logger.info(ColoredLogMessage(dep, LogColor.blue));
    }
  }
}

extension _Mapper on Iterable<ResolvedDependency> {
  Map<String, ResolvedDependency> toMap() {
    return {for (var item in this) item.artifact: item};
  }
}

extension ArtifactExtension on Artifact {
  String get identifier => "$group:$module:$version";
}
