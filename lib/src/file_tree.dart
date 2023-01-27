import 'package:dartle/dartle.dart';

class FileDeps {
  final String path;
  final Set<String> deps;

  const FileDeps(this.path, this.deps);

  @override
  String toString() => 'File $path depends on $deps';
}

class FileTree {
  final Map<String, FileDeps> depsByFile;

  const FileTree(this.depsByFile);

  Set<String>? transitiveDeps(String file, [Set<String>? visited]) {
    final fileDeps = depsByFile[file];
    if (fileDeps == null) return null;
    final result = <String>{};
    visited ??= <String>{};
    visited.add(fileDeps.path);

    result.addAll(fileDeps.deps);
    for (final next in fileDeps.deps) {
      if (visited.add(next)) {
        final nextDeps = transitiveDeps(next, visited);
        if (nextDeps != null) result.addAll(nextDeps);
      }
    }
    return result;
  }

  @override
  String toString() => depsByFile.values.map((fd) => '$fd').join(', ');
}

class _TypeEntry {
  final String type;
  final String file;

  const _TypeEntry(this.type, this.file);
}

Future<FileTree> loadFileTree(Stream<String> classRequirements) async {
  Map<String, String> fileByType = {};
  Map<String, List<String>> typeDeps = {};
  List<String>? currentTypeDeps;

  await for (final line in classRequirements) {
    if (line.startsWith('  - ')) {
      final typeEntry = _parseTypeLine(line);
      fileByType[typeEntry.type] = typeEntry.file;
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
    final file = fileByType[type]!;
    final fileDeps =
        result.update(file, (deps) => deps, ifAbsent: () => FileDeps(file, {}));
    for (final dep in deps) {
      fileDeps.deps.add(fileByType[dep]!);
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
