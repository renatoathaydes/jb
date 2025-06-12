import 'package:dartle/dartle.dart';

FileCollection patternFileCollection(Iterable<String> patterns) {
  final simpleFiles = <String>[];
  final dirEntries = <DirectoryEntry>[];
  for (var pattern in patterns) {
    final entry = _parsePattern(pattern);
    if (entry is String) {
      simpleFiles.add(entry);
    } else if (entry is DirectoryEntry) {
      dirEntries.add(entry);
    }
  }
  return entities(simpleFiles, dirEntries);
}

Object _parsePattern(String pattern) {
  final parts = pattern.split('/')..removeWhere((f) => f.isEmpty);
  final partsCount = parts.length;
  final recursionCount = parts.where((f) => f == '**').length;
  final recursionIndex = recursionCount > 0 ? parts.indexOf('**') : -1;
  if (recursionCount > 1 ||
      (recursionIndex >= 0 && recursionIndex < partsCount - 2)) {
    throw DartleException(
      message:
          "invalid pattern: '$pattern'. "
          "The '**' (recursion) pattern must be the last or second last part"
          " of a pattern, and may only appear once.",
    );
  }
  final anyCount = parts.where((f) => f == '*').length;
  final anyIndex = anyCount > 0 ? parts.lastIndexOf('*') : -1;
  if (anyCount > 1 ||
      (anyIndex >= 0 && anyIndex != partsCount - 1) ||
      (anyCount != 0 && recursionCount != 0)) {
    throw DartleException(
      message:
          "invalid pattern: '$pattern'. "
          "The '*' (any) pattern must be the last part"
          " of a pattern, may not appear together with '**',"
          " and may only appear once.",
    );
  }
  final extCount = parts.where((f) => f.isExtensionPattern).length;
  final extIndex = extCount > 0
      ? parts.indexWhere((f) => f.isExtensionPattern)
      : -1;
  if (extCount > 1 ||
      (extIndex >= 0 && extIndex != partsCount - 1) ||
      (extCount > 0 && anyCount > 0)) {
    throw DartleException(
      message:
          "invalid pattern: '$pattern'. "
          "The '*.<ext>' pattern must be the last part"
          " of a pattern, may not appear together with '*',"
          " and may only appear once.",
    );
  }
  final endsWithSlash = pattern.endsWith('/');
  if (extCount > 0 && endsWithSlash) {
    throw DartleException(
      message:
          "invalid pattern: '$pattern'. "
          "The '*.<ext>' pattern cannot be used to match a directory.",
    );
  }
  if (recursionCount > 0 && recursionIndex == partsCount - 2) {
    if (extCount == 0) {
      throw DartleException(
        message:
            "invalid pattern: '$pattern'. "
            "The '**' (recursion) pattern must be the last part or be followed"
            " by an extension pattern '*.<ext>'.",
      );
    }
    return DirectoryEntry(
      path: parts.pathTo(recursionIndex),
      recurse: true,
      fileExtensions: {parts.last.substring(1)},
    );
  }
  if (recursionCount > 0 && recursionIndex == partsCount - 1) {
    return DirectoryEntry(path: parts.pathTo(recursionIndex), recurse: true);
  }
  if (anyIndex >= 0) {
    return DirectoryEntry(path: parts.pathTo(anyIndex), recurse: false);
  }
  if (extIndex >= 0) {
    return DirectoryEntry(
      path: parts.pathTo(extIndex),
      recurse: false,
      fileExtensions: {parts.last.substring(1)},
    );
  }
  if (endsWithSlash) {
    return DirectoryEntry(path: parts.join('/'), recurse: false);
  }
  return parts.join('/');
}

extension on String {
  bool get isExtensionPattern => startsWith('*.');
}

extension on List<String> {
  String pathTo(int index) {
    if (index < 1) return '.';
    return sublist(0, index).join('/');
  }
}
