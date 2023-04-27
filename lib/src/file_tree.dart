import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dartle/dartle.dart';
import 'package:dartle/dartle.dart' show ChangeSet, DartleException;
import 'package:dartle/dartle_cache.dart';
import 'package:path/path.dart' as p;

import 'config.dart';
import 'exec.dart';
import 'output_consumer.dart';
import 'utils.dart';

final _newLine = utf8.encode(Platform.isWindows ? "\r\n" : '\n');

class FileDeps {
  final String path;
  final Set<String> deps;

  const FileDeps(this.path, this.deps);

  @override
  String toString() => 'File $path depends on ${deps.join(', ')}';
}

class TransitiveChanges {
  final FileTree fileTree;
  final List<FileChange> fileChanges;

  Set<String> get modified => fileChanges
      .where((e) => e.kind != ChangeKind.deleted)
      .map((e) => e.entity.path)
      .toSet();

  Set<String> get deletions => fileChanges
      .where((e) => e.kind == ChangeKind.deleted)
      .map((e) => e.entity.path)
      .toSet();

  TransitiveChanges(this.fileTree, this.fileChanges);

  @override
  String toString() {
    return 'TransitiveChanges{modified: $modified, deletions: $deletions}';
  }
}

/// A tree of files describing files' dependencies.
class FileTree {
  late final Map<String, FileDeps> depsByFile;
  final Map<String, List<String>> _typeDeps;
  final Map<String, String> _pathByType;
  final Map<String, List<String>> _typesByPath;

  FileTree._(this._typeDeps, List<_TypeEntry> typeEntries)
      : _pathByType = typeEntries.byType(),
        _typesByPath = typeEntries.byPath() {
    depsByFile = _computeDepsByFile(_typeDeps, _pathByType);
  }

  void serialize(Sink<List<int>> sink) {
    _typeDeps.forEach((type, deps) {
      final path = _pathByType[type]!;
      sink.add(utf8.encode('  - $type (${p.basename(path)}):'));
      sink.add(_newLine);
      for (final dep in deps) {
        sink.add(utf8.encode('    * $dep'));
        sink.add(_newLine);
      }
    });
    sink.close();
  }

  /// Compute the transitive dependents of a particular file in the tree.
  ///
  /// If the file is not present in the file tree, `null` is returned.
  ///
  /// If `result` is provided, the results are collected into it and it is
  /// returned, otherwise a new `Set` is created and returned.
  Set<String>? dependentsOf(String file, {Set<String>? result}) {
    if (!depsByFile.containsKey(file)) return null;
    result ??= <String>{};
    for (final entry in depsByFile.entries) {
      if (entry.value.deps.contains(file)) {
        final dependent = entry.key;
        result.add(dependent);
        dependentsOf(dependent, result: result);
      }
    }
    return result;
  }

  /// Compute the transitive changes given an initial change Set.
  ///
  /// The transitive dependents of every modified file are included.
  /// This allows incremental compilation to re-compile not just the files
  /// that were directly changed, but also the files that use definitions from
  /// the changed files.
  ///
  /// Deleted files are also returned. Dependents of deleted files are reported
  /// as having been modified, even if they actually weren't, so that they are
  /// re-compiled.
  TransitiveChanges computeTransitiveChanges(List<FileChange> changeSet) {
    final transitiveChanges = <String>{};
    for (final change in changeSet) {
      dependentsOf(change.entity.path, result: transitiveChanges);
    }

    final changeSetPaths = changeSet.map((c) => c.entity.path).toSet();

    final totalChanges = changeSet
        .followedBy(transitiveChanges
            .where(changeSetPaths.contains.not)
            .map((e) => FileChange(File(e), ChangeKind.modified)))
        .toList();

    return TransitiveChanges(this, totalChanges);
  }

  /// Merge this [FileTree] with another, excluding everything in the files
  /// given by `deletions`..
  FileTree merge(FileTree additions, Set<String> deletions) {
    final typeDeps = <String, List<String>>{};
    final typeEntries = <_TypeEntry>[];
    _typeDeps.forEach((type, deps) {
      final path = _pathByType[type]!;
      if (!deletions.contains(path)) {
        typeDeps[type] = deps;
        typeEntries.add(_TypeEntry(type: type, file: path));
      }
    });
    additions._typeDeps.forEach((type, deps) {
      final path = additions._pathByType[type]!;
      typeDeps[type] = deps;
      typeEntries.add(_TypeEntry(type: type, file: path));
    });
    return FileTree._(typeDeps, typeEntries);
  }

  Iterable<String> classFilesOf(String path) {
    return (_typesByPath[path] ?? const []).map(_toClassFile);
  }

  @override
  String toString() => depsByFile.values.map((fd) => '$fd').join(', ');
}

class _TypeEntry {
  final String type;
  final String file;
  String? _path;

  _TypeEntry({required this.type, required this.file});

  String get path {
    var result = _path;
    if (result == null) {
      if (type.contains('.')) {
        final lastDot = type.lastIndexOf('.');
        final pkg = type.substring(0, lastDot).replaceAll('.', '/');
        result = '$pkg/$file';
      } else {
        result = file;
      }
      _path = result;
    }
    return result;
  }
}

Future<FileTree> loadFileTreeFrom(File file) async {
  return await loadFileTree(file
      .openRead()
      .transform(const Utf8Decoder())
      .transform(const LineSplitter()));
}

Future<FileTree> loadFileTree(Stream<String> requirements) async {
  final typeEntries = <_TypeEntry>[];
  final typeDeps = <String, List<String>>{};
  List<String>? currentTypeDeps;

  await for (final line in requirements) {
    if (line.startsWith('  - ')) {
      final typeEntry = _parseTypeLine(line);
      typeEntries.add(typeEntry);
      currentTypeDeps = <String>[];
      typeDeps[typeEntry.type] = currentTypeDeps;
    } else if (line.startsWith('    * ')) {
      final type = _parseDepLine(line);
      currentTypeDeps!.add(type);
    }
  }

  return FileTree._(typeDeps, typeEntries);
}

Map<String, FileDeps> _computeDepsByFile(
    Map<String, List<String>> typeDeps, Map<String, String> pathByType) {
  final result = <String, FileDeps>{};

  typeDeps.forEach((type, deps) {
    final path = pathByType[type]!;
    final fileDeps =
        result.update(path, (d) => d, ifAbsent: () => FileDeps(path, {}));
    for (final dep in deps) {
      final path = pathByType[dep];
      if (path != null && fileDeps.path != path) fileDeps.deps.add(path);
    }
  });

  return result;
}

String _toClassFile(String type) {
  return '${type.replaceAll('.', '/')}.class';
}

_TypeEntry _parseTypeLine(String line) {
  assert(line.startsWith('  - '));
  assert(line.endsWith('):'));
  line = line.substring(4, line.length - 2);
  final parensStart = line.indexOf('(');
  return _TypeEntry(
      type: line.substring(0, parensStart - 1),
      file: line.substring(parensStart + 1));
}

String _parseDepLine(String line) {
  assert(line.startsWith('    * '));
  return line.substring(6);
}

class FileDiff {
  final ChangeSet changes;

  const FileDiff(this.changes);
}

extension on List<_TypeEntry> {
  Map<String, String> byType() {
    final result = <String, String>{};
    for (final entry in this) {
      result[entry.type] = entry.path;
    }
    return result;
  }

  Map<String, List<String>> byPath() {
    final result = <String, List<String>>{};
    for (final entry in this) {
      result.update(entry.path, (types) {
        types.add(entry.type);
        return types;
      }, ifAbsent: () => [entry.type]);
    }
    return result;
  }
}

Future<TransitiveChanges?> computeAllChanges(
    ChangeSet? changeSet, File srcFileTree) async {
  if (changeSet != null && changeSet.outputChanges.isEmpty) {
    if (await srcFileTree.exists()) {
      final currentTree = await loadFileTreeFrom(srcFileTree);
      return currentTree.computeTransitiveChanges(changeSet.inputChanges);
    }
  }
  return null;
}

Future<void> storeNewFileTree(String taskName, File jbuildJar,
    JBuildConfiguration config, String buildOutput, File fileTreeFile) async {
  final jbuildOutput = _FileOutput(fileTreeFile);
  try {
    final exitCode = await execJBuild(taskName, jbuildJar, config.preArgs(),
        'requirements', ['-c', buildOutput],
        onStdout: jbuildOutput);

    if (exitCode != 0) {
      throw DartleException(
          message: 'jbuild requirements command failed', exitCode: exitCode);
    }
  } finally {
    await jbuildOutput.close();
  }
}

class _FileOutput with ProcessOutputConsumer {
  int pid = -1;

  final IOSink _sink;

  _FileOutput(File file) : _sink = file.openWrite();

  @override
  void call(String line) {
    _sink.add(utf8.encode(line));
    _sink.add(_newLine);
  }

  Future<void> close() async {
    await _sink.flush();
    await _sink.close();
  }
}
