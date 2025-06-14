import 'package:conveniently/conveniently.dart';
import 'package:dartle/dartle.dart';

import '../config.dart';
import '../jb_config.g.dart';
import '../output_consumer.dart';

final _directDepPattern = RegExp(
  r'^Dependencies of ([^\s]+)\s+\(incl. transitive\) \[\{(.+)}]:$',
);

final _depPattern = RegExp(r'^(\s+)\*\s([^\s]+) \[[a-z]+] \[\{(.+)}]$');

class _DepNode {
  final _DepNode? parent;
  final String id;
  final String license;
  final int indentLevel;
  final List<_DepNode> deps = [];

  _DepNode(this.id, this.license, this.indentLevel, {required this.parent});

  /// Create a child _DepNode and return it.
  _DepNode add(String dep, String license, int indentLevel) =>
      _DepNode(dep, license, indentLevel, parent: this).apply$(deps.add);

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
    Match? match = _directDepPattern.matchAsPrefix(line);
    if (match != null) {
      // finalize the previous dep if any
      if (_currentDep != null) {
        _currentScope ??= DependencyScope.all;
        done();
      }
      _currentDep = _DepNode(match.group(1)!, match.group(2)!, 0, parent: null);
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
      final license = match.group(3)!;
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
      currentDep!.add(dep, license, indentationLevel);
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
          license: node.license,
          dependencies: node.deps.map((d) => d.id).toList(growable: false),
        ),
      );
    }
    for (final dep in node.deps) {
      _resolveDependency(dep, scope, isDirect: false);
    }
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
