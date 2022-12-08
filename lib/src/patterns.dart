import 'package:dartle/dartle.dart';

FileCollection patternFileCollection(Iterable<String> patterns) {
  final simpleFiles = <String>[];
  final dirEntries = <DirectoryEntry>[];
  for (var path in patterns) {
    path = path.sanitize();
    var isDir = path.endsWith('/');
    final parts = path.split('/')..removeWhere((f) => f.isEmpty);
    if (parts.isEmpty) {
      return FileCollection.empty;
    }
    var last = parts.last;
    List<String> pre;
    bool recurse;
    if (parts.where((f) => f == '**' || f == '*').length > 1) {
      throw DartleException(
          message: "invalid pattern: '$path'. "
              "Wildcard pattern must be last part of path or second last, "
              "with a pattern as the last part");
    }
    if (parts.length > 1) {
      recurse = parts[parts.length - 2] == '**';
      pre = parts.sublist(0, parts.length - (recurse ? 2 : 1));
      if (pre.isEmpty) {
        pre = const ['.'];
      }
      if (!recurse && last == '**') {
        isDir = true;
        recurse = true;
      }
    } else {
      pre = const [];
      recurse = false;
    }
    if (last == '*') {
      dirEntries.add(DirectoryEntry(
          path: pre.isEmpty ? '.' : pre.join('/'), recurse: false));
    } else if (last == '**') {
      dirEntries.add(DirectoryEntry(
          path: pre.isEmpty ? '.' : pre.join('/'), recurse: true));
    } else if ((recurse && !last.startsWith('*.')) ||
        pre.contains('*') ||
        pre.contains('**')) {
      throw DartleException(
          message: "invalid pattern: '$path'. "
              "Wildcard pattern must be last part of path or second last, "
              "with a pattern as the last part");
    } else if (last.startsWith('*.') && !isDir) {
      final ext = last.substring(1);
      dirEntries.add(DirectoryEntry(
          path: pre.isEmpty ? '.' : pre.join('/'),
          fileExtensions: {ext},
          recurse: recurse));
    } else if (isDir) {
      dirEntries.add(DirectoryEntry(
          path:
              [...pre, if (last.isNotEmpty) last.removeTrailing('/')].join('/'),
          recurse: recurse));
    } else {
      simpleFiles.add([...pre, last].join('/'));
    }
  }
  return entities(simpleFiles, dirEntries);
}

extension on String {
  String sanitize() {
    if (this == '/') return '.';
    if (startsWith('/')) {
      return substring(1);
    }
    return this;
  }

  String removeTrailing(String end) {
    if (endsWith(end)) return substring(0, length - end.length);
    return this;
  }
}
