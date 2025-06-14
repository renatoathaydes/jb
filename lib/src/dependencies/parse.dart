import 'package:conveniently/conveniently.dart';
import 'package:dartle/dartle.dart';

import '../config.dart';
import '../jb_config.g.dart';
import '../output_consumer.dart';

final _directDepPattern = RegExp(
  r'^Dependencies of ([^\s]+)\s+\(incl. transitive\) \[({.+})]:$',
);

final _depPattern = RegExp(r'^(\s+)\*\s([^\s]+) \[[a-z]+] \[({.+})]$');

class _DepNode {
  final _DepNode? parent;
  final String id;
  final List<DependencyLicense> licenses;
  final int indentLevel;
  final List<_DepNode> deps = [];

  _DepNode(this.id, this.licenses, this.indentLevel, {required this.parent});

  /// Create a child _DepNode and return it.
  _DepNode add(String dep, List<DependencyLicense> licenses, int indentLevel) =>
      _DepNode(dep, licenses, indentLevel, parent: this).apply$(deps.add);

  _DepNode? findParentAtIndentation(int indentationLevel) {
    if (indentLevel == indentationLevel) return parent;
    return parent?.findParentAtIndentation(indentationLevel);
  }
}

class JBuildDepsCollector implements ProcessOutputConsumer {
  int pid = -1;
  bool _enabled = true;
  DependencyScope? _currentScope;
  int? _currentIndentLevel;
  _DepNode? _currentDep;
  final List<ResolvedDependency> results = [];
  final Set<String> _resultIds = {};

  @override
  void call(String line) {
    if (!_enabled) return;
    if (_currentDep != null && line.startsWith('  - scope ')) {
      // finalize the dependencies for this scope
      if (_currentScope != null) done(emitRoot: false);
      _currentScope = _dependencyScopeFrom(line.substring('  - scope '.length));
      _currentIndentLevel = null;
      return;
    }
    const licenseParser = LicenseParser();

    Match? match = _directDepPattern.matchAsPrefix(line);
    if (match != null) {
      // finalize the previous dep if any
      if (_currentDep != null) {
        _currentScope ??= DependencyScope.all;
        done();
      }
      _currentDep = _DepNode(
        match.group(1)!,
        licenseParser.parseLicenses(match.group(2)!),
        0,
        parent: null,
      );
      _currentScope = null;
      _currentIndentLevel = null;
      return;
    }
    var currentDep = _currentDep;
    if (currentDep == null ||
        _currentScope == null ||
        (currentDep.parent == null && line.endsWith('* no dependencies'))) {
      return;
    }
    match = _depPattern.matchAsPrefix(line);
    if (match != null) {
      final indentationLevel = match.group(1)!.length;
      final dep = match.group(2)!;
      final licenses = licenseParser.parseLicenses(match.group(3)!);
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
      currentDep!.add(dep, licenses, indentationLevel);
      _currentIndentLevel = indentationLevel;
    } else if (line.endsWith('is required with more than one version:')) {
      _enabled = false;
    }
  }

  void done({bool emitRoot = true}) {
    final scope = _currentScope;
    var dep = _currentDep;

    // find the current root
    while (dep?.parent != null) {
      dep = dep?.parent;
    }
    if (dep == null) return;

    if (emitRoot) {
      _resolveDependency(dep, scope, isDirect: dep.parent == null);
    } else {
      for (final d in dep.deps) {
        _resolveDependency(d, scope, isDirect: false);
      }
    }
  }

  void _resolveDependency(
    _DepNode node,
    DependencyScope? scope, {
    required bool isDirect,
  }) {
    if (_resultIds.add(node.id)) {
      results.add(
        ResolvedDependency(
          artifact: node.id,
          spec: DependencySpec(scope: isDirect ? DependencyScope.all : scope!),
          kind: DependencyKind.maven,
          isDirect: isDirect,
          sha1: '',
          licenses: node.licenses,
          dependencies: node.deps.map((d) => d.id).toList(growable: false),
        ),
      );
    }
    for (final dep in node.deps) {
      _resolveDependency(dep, scope, isDirect: false);
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
