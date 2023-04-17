import 'package:dartle/dartle.dart';
import 'package:dartle/dartle_cache.dart';

class FileDeps {
  final String path;
  final Set<String> deps;

  const FileDeps(this.path, this.deps);

  @override
  String toString() => 'File $path depends on $deps';
}

/// A tree of files describing files' dependencies.
class FileTree {
  final Map<String, FileDeps> depsByFile;

  const FileTree(this.depsByFile);

  /// Compute the transitive dependencies of a particular file in the tree.
  ///
  /// The given file is included in the result unless `null` is returned, which
  /// implies the file is not part of the [FileTree].
  ///
  /// If `result` is provided, the results are collected into it and it is
  /// returned, otherwise a new `Set` is created and returned.
  Set<String>? transitiveDeps(String file, [Set<String>? result]) {
    final fileDeps = depsByFile[file];
    if (fileDeps == null) return null;
    result ??= <String>{};
    result.add(file);
    for (final next in fileDeps.deps) {
      if (result.add(next)) {
        final nextDeps = transitiveDeps(next, result);
        if (nextDeps != null) result.addAll(nextDeps);
      }
    }
    return result;
  }

  /// Compute the transitive changes given an initial change Set.
  ///
  /// The transitive dependencies of every modified file are included.
  /// Deleted files are not included and their transitive dependencies
  /// are assumed to have also been deleted.
  Set<String> computeTransitiveChanges(List<FileChange> changeSet) {
    final modified = changeSet
        .where(
            (c) => c.kind == ChangeKind.modified || c.kind == ChangeKind.added)
        .expand((c) => transitiveDeps(c.entity.path) ?? <String>{})
        .toSet();

    for (final del in changeSet
        .where((c) => c.kind == ChangeKind.deleted)
        .expand((c) => transitiveDeps(c.entity.path) ?? <String>{})) {
      modified.remove(del);
    }
    return modified;
  }

  @override
  String toString() => depsByFile.values.map((fd) => '$fd').join(', ');
}

class _TypeEntry {
  final String type;
  final String file;

  const _TypeEntry(this.type, this.file);

  String get path {
    if (type.contains('.')) {
      final lastDot = type.lastIndexOf('.');
      final pkg = type.substring(0, lastDot).replaceAll('.', '/');
      return '$pkg/$file';
    } else {
      return file;
    }
  }
}

Future<FileTree> loadFileTree(Stream<String> classRequirements) async {
  Map<String, String> pathByType = {};
  Map<String, List<String>> typeDeps = {};
  List<String>? currentTypeDeps;

  await for (final line in classRequirements) {
    if (line.startsWith('  - ')) {
      final typeEntry = _parseTypeLine(line);
      pathByType[typeEntry.type] = typeEntry.path;
      currentTypeDeps = <String>[];
      typeDeps[typeEntry.type] = currentTypeDeps;
    } else if (line.startsWith('    * ')) {
      final type = _parseDepLine(line);
      currentTypeDeps!.add(type);
    }
  }

  // convert type deps to file deps
  final result = <String, FileDeps>{};
  typeDeps.forEach((type, deps) {
    final path = pathByType[type]!;
    final fileDeps =
        result.update(path, (deps) => deps, ifAbsent: () => FileDeps(path, {}));
    for (final dep in deps) {
      fileDeps.deps.add(pathByType[dep]!);
    }
  });
  return FileTree(result);
}

_TypeEntry _parseTypeLine(String line) {
  assert(line.startsWith('  - '));
  assert(line.endsWith('):'));
  line = line.substring(4, line.length - 2);
  final parensStart = line.indexOf('(');
  return _TypeEntry(
      line.substring(0, parensStart - 1), line.substring(parensStart + 1));
}

String _parseDepLine(String line) {
  assert(line.startsWith('    * '));
  return line.substring(6);
}

class FileDiff {
  final ChangeSet changes;

  const FileDiff(this.changes);
}
