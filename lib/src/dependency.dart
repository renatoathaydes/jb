import 'package:conveniently/conveniently.dart';
import 'package:dartle/dartle.dart';

import 'jb_config.g.dart';
import 'output_consumer.dart';

final whitespace = ' '.runes.first;

List<ResolvedDependency> parse(List<String> lines) {
  final collector = _JBuildDepsCollector();
  for (final line in lines) {
    collector(line);
  }
  collector.done();
  return collector.results;
}

class _DepNode {
  final String id;
  final List<_DepNode> deps = [];

  _DepNode(this.id);
}

class _JBuildDepsCollector implements ProcessOutputConsumer {
  int pid = -1;
  bool _enabled = true;
  DependencyScope? _currentScope;
  int _currentIndentLevel = 4;
  final List<_DepNode> _dependencyStack = [_DepNode('root')];
  final List<ResolvedDependency> results = [];
  final Set<String> _resultIds = {};

  @override
  void call(String line) {
    if (_enabled && line.startsWith('  - scope ')) {
      // finalize the dependencies for this scope
      if (_currentScope != null) done();
      _currentScope = _dependencyScopeFrom(line.substring('  - scope '.length));
    } else if (_enabled && line.isDependency()) {
      final indentationLevel =
          line.runes.takeWhile((c) => c == whitespace).length;
      final dep = _dependencyId(line, indentationLevel + '* '.length);
      if (_currentIndentLevel == indentationLevel) {
        _dependencyStack.last.deps.add(_DepNode(dep));
      } else {
        if (indentationLevel > _currentIndentLevel) {
          // one level up: put the previous dep on the stack,
          // add current dep to it.
          final parent = _dependencyStack.last.deps.last;
          _dependencyStack.add(parent);
          parent.deps.add(_DepNode(dep));
        } else {
          // one level down: remove a dep from the stack,
          // then add the dep as normal.
          _dependencyStack.removeLast();
          _dependencyStack.last.deps.add(_DepNode(dep));
        }
        _currentIndentLevel = indentationLevel;
      }
    } else if (line.endsWith('is required with more than one version:')) {
      _enabled = false;
    }
  }

  void done() {
    final scope = _currentScope
        .orThrow(() => StateError('no current scope for dependency'));
    // do not add the root, but process its dependencies.
    for (final dep in _dependencyStack.first.deps) {
      results.addAll(_resolveDependency(dep, scope, isDirect: true));
    }
    _dependencyStack.first.deps.clear();
    // now, add the other deps from the stack
    for (final dep in _dependencyStack.skip(1)) {
      results.addAll(_resolveDependency(dep, scope, isDirect: false));
    }
    // clear the stack
    _dependencyStack.length = 1;
  }

  Iterable<ResolvedDependency> _resolveDependency(
      _DepNode node, DependencyScope scope,
      {required bool isDirect}) sync* {
    if (_resultIds.add(node.id)) {
      yield ResolvedDependency(
          artifact: node.id,
          spec: DependencySpec(scope: scope),
          kind: DependencyKind.maven,
          isDirect: isDirect,
          sha1: '',
          dependencies: node.deps.map((d) => d.id).toList(growable: false));
    }
    for (final dep in node.deps) {
      yield* _resolveDependency(dep, scope, isDirect: false);
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

String _dependencyId(String line, int start) {
  final lastSpace = line.indexOf(' ', start = start);
  if (lastSpace <= 0) {
    return line.substring(start);
  }
  return line.substring(start, lastSpace);
}

final _depPattern = RegExp(r'^\s+\*\s');

extension _DepString on String {
  bool isDependency() {
    return _depPattern.hasMatch(this);
  }
}
