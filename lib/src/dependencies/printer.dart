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
import 'package:io/ansi.dart'
    show
        magenta,
        styleBold,
        yellow,
        styleItalic,
        resetBold,
        red,
        resetAll,
        darkGray,
        blue;
import 'package:path/path.dart' as paths;

import '../config.dart';
import '../jb_files.dart';
import '../licenses.g.dart' show allLicenses;
import '../maven_metadata.dart' show License;
import '../pom.dart';
import '../resolved_dependency.dart';
import '../tasks.dart' show depsTaskName;
import 'deps_cache.dart';

final class _LocalDependency {
  final String name;
  final DependencySpec spec;
  final bool isJar; // is Jar or is Project
  ResolvedDependencies? deps;

  _LocalDependency(this.name, this.spec, {required this.isJar, this.deps});

  String get localSuffix => isJar ? ' (local jar)' : ' (local project)';
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

void printDepWarnings(ResolvedDependencies deps) {
  final printer = _JBuildDepsPrinter(false);
  printer.printWarnings(deps);
}

Future<void> printDependencies(
  JbFiles jbFiles,
  JbConfiguration config,
  String workingDir,
  DepsCache depsCache,
  ResolvedLocalDependencies localDeps,
  ResolvedLocalDependencies localProcDeps,
  List<String> args,
) async {
  final options = const DepsArgValidator()._parse(args);
  final scope = options.scope;
  final mainLocalDeps = await _getLocalDependencies(
    jbFiles,
    depsCache,
    localDeps,
    scope: scope,
  ).toList();
  final processorLocalDeps = await _getLocalDependencies(
    jbFiles,
    depsCache,
    localProcDeps,
    scope: scope,
  ).toList();
  final mainResolved = await depsCache.send(
    GetDeps(jbFiles.dependenciesFile.path),
  );
  final mainDeps = mainResolved.dependencies
      .where((dep) => scope.includes(dep.spec.scope))
      .toList(growable: false);
  final processorResolved = await depsCache.send(
    GetDeps(jbFiles.processorDependenciesFile.path),
  );
  final processorDeps = processorResolved.dependencies
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
      ..print(mainDeps, mainLocalDeps, options)
      ..printWarnings(mainResolved);
  }
  if (processorLocalDeps.isNotEmpty || processorDeps.isNotEmpty) {
    printer
      ..header(artifact, scope, forProcessor: true)
      ..exclusions(config.processorDependencyExclusionPatterns)
      ..print(processorDeps, processorLocalDeps, options)
      ..printWarnings(processorResolved);
  }
  printer.printSeenLicenses();
}

Stream<_LocalDependency> _getLocalDependencies(
  JbFiles jbFiles,
  DepsCache depsCache,
  ResolvedLocalDependencies localDependencies, {
  required DependencyScope scope,
}) async* {
  for (final jar in localDependencies.jars) {
    if (scope.includes(jar.spec.scope)) {
      yield _LocalDependency(jar.path, jar.spec, isJar: true);
    }
  }
  for (final projectDep in localDependencies.projectDependencies) {
    if (scope.includes(projectDep.spec.scope)) {
      final deps = await depsCache.send(
        GetDeps(
          paths.join(projectDep.projectDir, jbFiles.dependenciesFile.path),
        ),
      );
      yield _LocalDependency(
        projectDep.path,
        projectDep.spec,
        isJar: false,
        deps: deps,
      );
    }
  }
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

  static const _indentUnit = '    ';
  static const _indentAdd = '│   ';

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
        ? 'Annotation processor dependencies:\n'
        : 'Project Dependencies:\n';
    logger.info(
      AnsiMessage([
        AnsiMessagePart.code(styleItalic),
        AnsiMessagePart.text(prefix),
        AnsiMessagePart.code(styleBold),
        AnsiMessagePart.code(magenta),
        AnsiMessagePart.text('${artifact.identifier}$scopeMsg:'),
      ]),
    );
  }

  void exclusions(List<String> exclusions) {
    _printExclusions(exclusions, indent: _indentAdd);
  }

  void print(
    List<ResolvedDependency> deps,
    Iterable<_LocalDependency> localDeps,
    _DepsArgs options,
  ) async {
    final visited = <String>{};
    var map = localDeps
        .expand((d) => d.deps?.dependencies ?? const <ResolvedDependency>[])
        .toMap();
    var finalIndex = localDeps.length - 1;
    if (deps.isNotEmpty) {
      // the finalIndex is not reached by the local deps
      finalIndex++;
    }
    for (final (i, dep) in localDeps.sortedBy((d) => d.name).indexed) {
      logger.info(
        AnsiMessage([
          AnsiMessagePart.text(_depPoint(i == finalIndex)),
          AnsiMessagePart.code(blue),
          AnsiMessagePart.text(' ${dep.name} ${dep.localSuffix}'),
          AnsiMessagePart.code(resetAll),
        ]),
      );
      final ddeps = dep.deps;
      if (ddeps != null && ddeps.dependencies.isNotEmpty) {
        finalIndex = ddeps.dependencies.length - 1;
        for (final (i, d)
            in ddeps.dependencies.sortedBy((e) => e.artifact).indexed) {
          final isLast = i == finalIndex;
          _printTree(
            d,
            map,
            visited,
            options,
            indent: "$_indentUnit${isLast ? '' : _indentAdd}",
            isLast: isLast,
          );
        }
      }
    }

    map = deps.toMap();
    final directDeps = deps
        .where((d) => d.isDirect)
        .sortedBy((d) => d.artifact)
        .toList();
    finalIndex = directDeps.length - 1;
    for (final (i, dep) in directDeps.indexed) {
      _printTree(dep, map, visited, options, isLast: i == finalIndex);
    }
  }

  void _printTree(
    ResolvedDependency dependency,
    Map<String, ResolvedDependency> map,
    Set<String> visited,
    _DepsArgs options, {
    String indent = '',
    required bool isLast,
  }) {
    if (!visited.add(dependency.artifact)) {
      _printVisited(dependency.artifact, indent: indent, isLast: isLast);
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
        AnsiMessagePart.text("$indent${_depPoint(isLast)} "),
        AnsiMessagePart.code(styleBold),
        AnsiMessagePart.text(dependency.artifact),
        ...licenseParts,
      ]),
    );

    final nextIndent = '$indent${isLast ? _indentUnit : _indentAdd}';
    _printExclusions(dependency.spec.exclusions, indent: nextIndent);

    final finalIndex = dependency.dependencies.length - 1;
    for (final (i, ddep) in dependency.dependencies.sorted().indexed) {
      final dep = map[ddep]!;
      final isLast = i == finalIndex;
      _printTree(
        dep,
        map,
        visited,
        options,
        indent: nextIndent,
        isLast: isLast,
      );
    }
  }

  void _printExclusions(List<String> exclusions, {String indent = ''}) {
    for (final exclusion in exclusions.sorted()) {
      logger.info(
        AnsiMessage([
          AnsiMessagePart.text(indent),
          AnsiMessagePart.code(red),
          AnsiMessagePart.text('x $exclusion'),
        ]),
      );
    }
  }

  void _printVisited(
    String dep, {
    required String indent,
    required bool isLast,
  }) {
    final point = _depPoint(isLast);
    logger.info(
      AnsiMessage([
        AnsiMessagePart.text("$indent$point "),
        AnsiMessagePart.code(darkGray),
        AnsiMessagePart.text("$dep (-)"),
      ]),
    );
  }

  void printWarnings(ResolvedDependencies deps) {
    final warnings = deps.warnings;
    if (warnings.isEmpty) return;
    final directDepByArtifact = Map.fromEntries(
      deps.dependencies
          .where((d) => d.isDirect)
          .expand((d) => d.dependencies.map((e) => MapEntry(e, d))),
    );
    logger.info(
      ColoredLogMessage('Dependency tree contains conflicts:', LogColor.yellow),
    );
    for (final warning in warnings) {
      logger.info(
        AnsiMessage([
          AnsiMessagePart.code(styleBold),
          AnsiMessagePart.text('  * ${warning.artifact}:\n'),
          AnsiMessagePart.code(resetBold),
          ...warning.versionConflicts.expand(
            (c) => [
              AnsiMessagePart.code(styleBold),
              AnsiMessagePart.code(yellow),
              AnsiMessagePart.text('    - ${c.version}'),
              AnsiMessagePart.code(resetAll),
              AnsiMessagePart.text(': '),
              ..._prefixWithDirectDep(
                c.requestedBy,
                directDepByArtifact,
              ).map(AnsiMessagePart.text).toList().joinWith(const [
                AnsiMessagePart.code(darkGray),
                AnsiMessagePart.text(' -> '),
                AnsiMessagePart.code(resetAll),
              ]),
              AnsiMessagePart.text('\n'),
            ],
          ),
        ]),
      );
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

String _depPoint(bool isLast) {
  if (isLast) return '└──';
  return '├──';
}

Iterable<String> _prefixWithDirectDep(
  List<String> requestedBy,
  Map<String, ResolvedDependency> directDepByArtifact,
) {
  // the first item in the requestedBy List is a dep of some direct dependency,
  // we need to locate which one.
  if (requestedBy.isEmpty) return requestedBy;
  final dep = requestedBy.first;
  final directDep = directDepByArtifact[dep];
  if (directDep != null) {
    return [directDep.artifact].followedBy(requestedBy);
  }
  return requestedBy;
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

extension<T> on List<T> {
  Iterable<T> joinWith(List<T> joins) sync* {
    final lastIndex = length - 1;
    for (final e in indexed) {
      final (index, item) = e;
      yield item;
      if (index != lastIndex) {
        yield* joins;
      }
    }
  }
}
