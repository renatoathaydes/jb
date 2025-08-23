import 'package:conveniently/conveniently.dart';
import 'package:dartle/dartle.dart';

import '../config.dart';
import '../jb_config.g.dart';
import '../output_consumer.dart';

final _directDepPattern = RegExp(
  r'^Dependencies of (?<dep>\S+)\s+\(incl. transitive\)( \[(?<lic>{.+})])?:$',
);

final _depPattern = RegExp(
  r'^(?<ind>\s+)\*\s(?<dep>\S+) \[[a-z]+](:exclusions:\[(?<exc>[^\]]+)\])?( ?(?<rep>\(-\))| ?\[(?<lic>\{.+?})])?$',
);

final _versionConflictHeaderPattern = RegExp(
  r'^\s+The artifact (?<art>\S+) is required with more than one version:$',
);

final _versionRequestsPattern = RegExp(r'^\s+\* (?<ver>\S+) \((?<req>.+)\)$');

class _DepNode {
  final _DepNode? parent;
  final String id;
  final List<DependencyLicense>? licenses;
  final List<String> exclusions;
  final int indentLevel;
  final List<_DepNode> deps = [];

  _DepNode(
    this.id,
    this.licenses,
    this.exclusions,
    this.indentLevel, {
    required this.parent,
  });

  /// Create a child _DepNode and return it.
  /// If `licenses` is `null`, then this represents a repeated node.
  _DepNode add(
    String dep,
    List<DependencyLicense>? licenses,
    List<String> exclusions,
    int indentLevel,
  ) => _DepNode(
    dep,
    licenses,
    exclusions,
    indentLevel,
    parent: this,
  ).apply$(deps.add);

  _DepNode? findParentAtIndentation(int indentationLevel) {
    if (indentLevel == indentationLevel) return parent;
    return parent?.findParentAtIndentation(indentationLevel);
  }
}

enum _ParserState { parsingDeps, parsingConflicts }

class JBuildDepsCollector implements ProcessOutputConsumer {
  int pid = -1;
  _ParserState _state = _ParserState.parsingDeps;
  DependencyScope _currentScope = DependencyScope.all;
  int? _currentIndentLevel;
  _DepNode? _currentDep;
  final List<ResolvedDependency> _resolvedDeps = [];
  String? _currentWarningArtifact;
  final List<VersionConflict> _currentWarnings = [];
  final List<DependencyWarning> _allWarnings = [];

  ResolvedDependencies get resolvedDeps => ResolvedDependencies(
    dependencies: _resolvedDeps.toList(growable: false),
    warnings: _allWarnings.toList(growable: false),
  );

  @override
  void call(String line) {
    switch (_state) {
      withDeps:
      case _ParserState.parsingDeps:
        _parseDep(line);
        if (_state == _ParserState.parsingConflicts) {
          continue withConflicts;
        }
      withConflicts:
      case _ParserState.parsingConflicts:
        _parseConflicts(line);
        if (_state == _ParserState.parsingDeps) {
          continue withDeps;
        }
    }
  }

  void _parseDep(String line) {
    if (_currentDep != null && line.startsWith('  - scope ')) {
      _doneDeps(emitRoot: false);
      _currentScope = _dependencyScopeFrom(line.substring('  - scope '.length));
      _currentIndentLevel = null;
      return;
    }
    const licenseParser = LicenseParser();

    RegExpMatch? match = _directDepPattern.firstMatch(line);
    if (match != null) {
      // finalize the previous dep if any
      if (_currentDep != null) {
        _doneDeps(emitRoot: true);
      }
      List<DependencyLicense> licenses = match
          .namedGroup('lic')
          .vmapOr((g) => licenseParser.parseLicenses(g), () => const []);
      _currentDep = _DepNode(
        match.namedGroup('dep')!,
        licenses,
        const [],
        0,
        parent: null,
      );
      _currentIndentLevel = null;
      return;
    }
    var currentDep = _currentDep;
    if (currentDep == null ||
        (currentDep.parent == null && line.endsWith('* no dependencies'))) {
      return;
    }
    match = _depPattern.firstMatch(line);
    if (match != null) {
      final indentationLevel = match.namedGroup('ind')!.length;
      final dep = match.namedGroup('dep')!;
      List<String> exclusions = match
          .namedGroup('exc')
          .vmapOr((s) => s.split(', '), () => const []);
      // set licenses to null in case this is a repeated listing (with `(-)`).
      List<DependencyLicense>? licenses = match.namedGroup('rep') != null
          ? null
          : match
                .namedGroup('lic')
                .vmapOr((g) => licenseParser.parseLicenses(g), () => const []);
      final currentIndentLevel = _currentIndentLevel ?? indentationLevel;
      if (indentationLevel != currentIndentLevel) {
        if (indentationLevel > currentIndentLevel) {
          // one level up: change currentDep to the previous entry
          currentDep = currentDep.deps.last;
        } else {
          // one or more levels down: find the relevant parent
          currentDep = currentDep.findParentAtIndentation(indentationLevel);
        }
        _currentDep = currentDep;
      }
      currentDep!.add(dep, licenses, exclusions, indentationLevel);
      _currentIndentLevel = indentationLevel;
    } else if (_versionConflictHeaderPattern.hasMatch(line)) {
      _state = _ParserState.parsingConflicts;
    }
  }

  void _parseConflicts(String line) {
    var match = _versionConflictHeaderPattern.firstMatch(line);
    if (match != null) {
      _doneWarnings();
      _currentWarningArtifact = match.namedGroup('art');
      return;
    }
    if (_currentWarningArtifact != null) {
      match = _versionRequestsPattern.firstMatch(line);
      if (match != null) {
        // Stop actually parsing version conflicts from JBuild... we need to do
        // it in jb because of the way jb resolves dependencies across projects.
        //
        // final version = match.namedGroup('ver')!;
        // final requestedBy = match.namedGroup('req')!.split(' -> ');
        // _currentWarnings.add(
        //   VersionConflict(version: version, requestedBy: requestedBy),
        // );
        return;
      }
    }
    if (_directDepPattern.hasMatch(line)) {
      _doneWarnings();
      _state = _ParserState.parsingDeps;
    }
  }

  void done({bool emitRoot = true}) {
    _doneDeps(emitRoot: emitRoot);
    _doneWarnings();
  }

  void _doneDeps({required bool emitRoot}) {
    final scope = _currentScope;
    var dep = _currentDep;

    // find the current root
    while (dep?.parent != null) {
      dep = dep?.parent;
    }
    if (dep == null) return;
    if (emitRoot) {
      _currentDep = null;
    }
    if (emitRoot) {
      _resolveDependency(dep, scope, isDirect: dep.parent == null);
    } else {
      for (final d in dep.deps) {
        _resolveDependency(d, scope, isDirect: false);
      }
    }
  }

  void _doneWarnings() {
    final artifact = _currentWarningArtifact;
    if (artifact == null) return;
    _currentWarningArtifact = null;
    final warnings = _currentWarnings.toList(growable: false);
    if (warnings.isEmpty) return;
    _currentWarnings.clear();
    _allWarnings.add(
      DependencyWarning(artifact: artifact, versionConflicts: warnings),
    );
  }

  void _resolveDependency(
    _DepNode node,
    DependencyScope scope, {
    required bool isDirect,
  }) {
    _resolvedDeps.add(
      ResolvedDependency(
        artifact: node.id,
        spec: DependencySpec(
          scope: isDirect ? DependencyScope.all : scope,
          exclusions: node.exclusions,
        ),
        isDirect: isDirect,
        sha1: '',
        licenses: node.licenses,
        dependencies: node.deps.map((d) => d.id).toList(growable: false),
      ),
    );
    // the licenses field is only null if this is a repeated dep,
    // so we know we don't need to recurse in such case.
    if (node.licenses != null) {
      for (final dep in node.deps) {
        _resolveDependency(dep, scope, isDirect: false);
      }
    }
  }
}

class LicenseParser {
  static const nameKey = '{name=';
  static const nameOffset = nameKey.length;
  static const urlKey = ', url=';
  static const urlOffset = urlKey.length;
  static const betweenEntries = '}, {';

  const LicenseParser();

  /// Parse a license text as printed by JBuild.
  /// It normally looks like this (without line breaks):
  /// ```
  /// {name=Apache Software License - Version 2.0,
  ///  url=https://www.apache.org/licenses/LICENSE-2.0},
  /// {name=Eclipse Public License - Version 2.0,
  ///  url=https://www.eclipse.org/legal/epl-2.0}
  /// ```
  ///
  /// But may also look like a simple string:
  /// ```
  /// {MIT}
  /// ```
  List<DependencyLicense> parseLicenses(final String text) {
    final result = <DependencyLicense>[];
    var startIndex = 0;
    while (startIndex < text.length) {
      if (!text.startsWith(nameKey, startIndex)) {
        // simple license without keys?
        if (!text.startsWith('{', startIndex)) {
          _err("does not start with '{'", text, startIndex);
        }
        final endIndex = text.indexOf(betweenEntries, startIndex);
        if (endIndex < 0) {
          // just one license?
          if (!text.endsWith('}')) {
            _err("not closed with '}'", text, text.length - 1);
          }
          result.add(
            DependencyLicense(
              name: text.substring(startIndex + 1, text.length - 1),
              url: '',
            ),
          );
          break;
        }
        result.add(
          DependencyLicense(
            name: text.substring(startIndex + 1, endIndex),
            url: '',
          ),
        );
        startIndex = endIndex + betweenEntries.length - 1;
        continue;
      }

      final nameIndex = text.indexOf(nameKey, startIndex);
      if (nameIndex < 0) {
        _err('missing name', text, startIndex);
      }
      final urlIndex = text.indexOf(urlKey, nameIndex + nameOffset);
      if (urlIndex < 0) {
        _err('missing url', text, nameIndex + nameOffset);
      }
      var closeIndex = text.indexOf(betweenEntries, urlIndex + urlOffset);
      if (closeIndex < 0) {
        if (text.endsWith('}')) {
          closeIndex = text.length - 1;
          startIndex = text.length;
        } else {
          _err('unclosed', text, urlIndex + urlOffset);
        }
      } else {
        startIndex = closeIndex + betweenEntries.length - 1;
      }
      result.add(_createLicense(text, nameIndex, urlIndex, closeIndex));
    }
    return result;
  }

  Never _err(String reason, String text, int startIndex) {
    final at = Iterable.generate(startIndex + 2, (int _) => ' ').join();
    throw StateError(
      'Invalid license text ($reason):\n'
      '  $text\n'
      '$at^',
    );
  }

  DependencyLicense _createLicense(
    String text,
    int nameIndex,
    int urlIndex,
    int closeIndex,
  ) {
    final name = text.substring(nameIndex + nameOffset, urlIndex);
    final url = text.substring(urlIndex + urlOffset, closeIndex);
    return DependencyLicense(name: name, url: url);
  }
}

DependencyScope _dependencyScopeFrom(String mavenScope) {
  return switch (mavenScope) {
    'compile' || 'test' => DependencyScope.all,
    'runtime' => DependencyScope.runtimeOnly,
    'provided' => DependencyScope.compileOnly,
    _ => failBuild(reason: 'Unsupported Maven scope: $mavenScope'),
  };
}
