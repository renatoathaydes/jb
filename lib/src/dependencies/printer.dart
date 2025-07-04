import 'package:args/args.dart';
import 'package:collection/collection.dart';
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
import 'package:io/ansi.dart'
    show magenta, styleBold, yellow, styleItalic, resetBold, styleDim, red;

import '../config.dart';
import '../jb_files.dart';
import '../licenses.g.dart' show allLicenses;
import '../maven_metadata.dart' show License;
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
      '        * --$scopeFlag\n'
      '          -s <scope>: the scope of dependencies. One of ${DependencyScope.values.map((s) => s.name)}.\n'
      '        * --$licensesFlag\n'
      '          -l: show dependencies\' licenses.';
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
  final mainDeps = (await parseDeps(jbFiles.dependenciesFile)).dependencies
      .where((dep) => scope.includes(dep.spec.scope))
      .toList(growable: false);
  final processorDeps = (await parseDeps(jbFiles.processorDependenciesFile))
      .dependencies
      .where((dep) => scope.includes(dep.spec.scope))
      .toList(growable: false);

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
      ..exclusions(config.dependencyExclusionPatterns)
      ..print(mainDeps, options)
      ..printLocal(mainLocalDeps);
  }
  if (processorLocalDeps.isNotEmpty || processorDeps.isNotEmpty) {
    printer
      ..header(artifact, scope, forProcessor: true)
      ..exclusions(config.processorDependencyExclusionPatterns)
      ..print(processorDeps, options)
      ..printLocal(processorLocalDeps);
  }
  printer.printSeenLicenses();
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
  Set<_License> seenLicenses = {};

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

  void exclusions(List<String> exclusions) {
    _printExclusions(exclusions);
  }

  void print(List<ResolvedDependency> deps, _DepsArgs options) {
    final map = deps.toMap();
    final visited = <String>{};
    for (final dep
        in deps.where((d) => d.isDirect).sortedBy((d) => d.artifact)) {
      _printTree(dep, map, visited, options);
    }
  }

  static const _indentUnit = '  ';

  void _printTree(
    ResolvedDependency dependency,
    Map<String, ResolvedDependency> map,
    Set<String> visited,
    _DepsArgs options, {
    String indent = _indentUnit,
  }) {
    if (!visited.add(dependency.artifact)) {
      _printVisited(dependency.artifact, indent: indent);
      return;
    }

    final licenses = dependency.licenses ?? const [];
    List<AnsiMessagePart> licenseParts = const [];
    if (options.showLicenses) {
      final depLicenses = licenses
          .map((d) => _findLicense(d))
          .toList(growable: false);
      if (depLicenses.isNotEmpty) {
        seenLicenses.addAll(depLicenses);
        licenseParts = [
          AnsiMessagePart.code(styleBold),
          AnsiMessagePart.code(yellow),
          AnsiMessagePart.text(' [${depLicenses.join(', ')}]'),
        ];
      }
    }

    logger.info(
      AnsiMessage([
        AnsiMessagePart.code(styleBold),
        AnsiMessagePart.text("$indent* ${dependency.artifact}"),
        ...licenseParts,
      ]),
    );

    _printExclusions(dependency.spec.exclusions, indent: indent);

    for (final ddep in dependency.dependencies.sorted()) {
      final dep = map[ddep]!;
      _printTree(dep, map, visited, options, indent: '$_indentUnit$indent');
    }
  }

  void _printExclusions(List<String> exclusions, {String indent = ''}) {
    for (final exclusion in exclusions.sorted()) {
      logger.info(
        AnsiMessage([
          AnsiMessagePart.code(red),
          AnsiMessagePart.code(styleDim),
          AnsiMessagePart.text('$indent${_indentUnit}x $exclusion'),
        ]),
      );
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

  void printSeenLicenses() {
    if (seenLicenses.isEmpty) return;
    logger.info(
      AnsiMessage([
        AnsiMessagePart.code(styleItalic),
        AnsiMessagePart.text(
          'The listed dependencies use ${seenLicenses.length} '
          'license${seenLicenses.length == 1 ? '' : 's'}:',
        ),
      ]),
    );
    for (final license in seenLicenses.sortedBy((l) => l.toString())) {
      logger.info(
        AnsiMessage([
          AnsiMessagePart.code(styleBold),
          AnsiMessagePart.text('  - $license'),
          AnsiMessagePart.code(resetBold),
          ...switch (license) {
            _SpdxLicense(license: final lic) => [
              AnsiMessagePart.text(' ('),
              AnsiMessagePart.text(
                [
                  lic.uri,
                  if (lic.isOsiApproved != null) 'OSI?=${lic.isOsiApproved}',
                  if (lic.isFsfLibre != null) 'FSF?=${lic.isFsfLibre}',
                ].join(', '),
              ),
              AnsiMessagePart.text(')'),
            ],
            _UnknownLicense(license: final lic) => [
              if (lic.url.isNotEmpty && lic.url != '<unspecified>')
                AnsiMessagePart.text(' (${lic.url})'),
            ],
          },
        ]),
      );
    }
  }
}

_License _findLicense(DependencyLicense license) {
  // try to find the license by ID
  var knowLicense = allLicenses[license.name];
  if (knowLicense != null) {
    return _SpdxLicense(knowLicense);
  }
  // try by name
  knowLicense = allLicenses.values
      .where((lic) => license.name == lic.name)
      .firstOrNull;
  if (knowLicense != null) {
    return _SpdxLicense(knowLicense);
  }
  // if available, try by URL
  if (license.url.isNotEmpty) {
    knowLicense = allLicenses.values
        .where((lic) => license.url == lic.uri)
        .firstOrNull;
    if (knowLicense != null) {
      return _SpdxLicense(knowLicense);
    }
  }
  // try some commonly used licenses
  if (license.name.startsWith('Apache')) {
    if (license.name.endsWith('1.0')) {
      return _SpdxLicense(allLicenses['Apache-1.0']!);
    }
    if (license.name.endsWith('1.1')) {
      return _SpdxLicense(allLicenses['Apache-1.1']!);
    }
    if (license.name.endsWith(' 2.0')) {
      return _SpdxLicense(allLicenses['Apache-2.0']!);
    }
  }
  if (license.name.startsWith('Eclipse Public')) {
    if (license.name.endsWith('1.0')) {
      return _SpdxLicense(allLicenses['EPL-1.0']!);
    }
    if (license.name.endsWith('2.0')) {
      return _SpdxLicense(allLicenses['EPL-2.0']!);
    }
  }
  logger.fine(
    () =>
        'Could not find dependency license in the '
        'current SPDX registry: $license',
  );
  return _UnknownLicense(license);
}

sealed class _License {
  const _License();

  /// This is used to print the license in the dependency tree.
  @override
  String toString() => switch (this) {
    _SpdxLicense(license: var lic) => lic.licenseId,
    _UnknownLicense(license: var lic) => lic.name,
  };
}

final class _SpdxLicense extends _License {
  final License license;

  const _SpdxLicense(this.license);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _SpdxLicense && license.licenseId == other.license.licenseId;

  @override
  int get hashCode => license.licenseId.hashCode;
}

final class _UnknownLicense extends _License {
  final DependencyLicense license;

  const _UnknownLicense(this.license);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _UnknownLicense && license.name == other.license.name;

  @override
  int get hashCode => license.name.hashCode;
}

extension _Mapper on Iterable<ResolvedDependency> {
  /// Create a Map with the resolved dependencies by the artifact identifier.
  ///
  /// The Iterable may contain repeated dependencies because they may appear
  /// on multiple branches. In case of repetition, the one with a non-null
  /// license value is kept because only repeated dependencies, as printed by
  /// JBuild, have a null licenses field.
  Map<String, ResolvedDependency> toMap() {
    final map = <String, ResolvedDependency>{};
    for (final dep in this) {
      final key = dep.artifact;
      final current = map[key];
      if (current == null) {
        map[key] = dep;
      } else if (dep.licenses != null) {
        map[key] = dep;
      }
    }
    return map;
  }
}

extension ArtifactExtension on Artifact {
  String get identifier => "$group:$module:$version";
}
