import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'jbuild_jar.g.dart';
import 'paths.dart';

Future<File> createIfNeededAndGetJBuildJarFile() async {
  final file = File(jbuildJarPath()).absolute;
  if (!await file.exists()) {
    print('Creating JBuild jar');
    await _createJBuildJar(file);
  }
  return file;
}

Future<void> _createJBuildJar(File jar) async {
  await jar.parent.create(recursive: true);
  await jar.writeAsBytes(base64Decode(jbuildJarB64));
  print('JBuild jar saved at ${jar.path}');
}

extension AnyExtension<T> on T? {
  T orThrow(error) {
    if (this == null) throw error;
    return this!;
  }
}

extension FunctionExtension<T> on bool Function(T) {
  bool Function(T) get not => (v) => !this(v);
}

extension NullIterable<T> on Iterable<T?> {
  Iterable<T> whereNonNull() sync* {
    for (final item in this) {
      if (item != null) yield item;
    }
  }
}

extension AsyncIterable<T> on Iterable<FutureOr<T>> {
  Stream<T> toStream() async* {
    for (final item in this) {
      yield await item;
    }
  }
}

extension MapEntryIterable<K, V> on Iterable<MapEntry<K, V>> {
  Map<K, V> toMap() {
    return {for (final entry in this) entry.key: entry.value};
  }
}

extension DirectoryExtension on Directory {
  Future<void> copyContentsInto(String destinationDir) async {
    if (!await exists()) return;
    await for (final child in list(recursive: true)) {
      if (child is Directory) {
        await Directory(
                p.join(destinationDir, p.relative(child.path, from: path)))
            .create();
      } else if (child is File) {
        await child
            .copy(p.join(destinationDir, p.relative(child.path, from: path)));
      }
    }
  }
}

extension NullableStringExtension on String? {
  String? removeFromEnd(Set<String> suffixes) {
    final self = this;
    if (self == null || suffixes.isEmpty) return self;
    var result = self;
    for (final suffix in suffixes) {
      if (result.endsWith(suffix)) {
        result = result.substring(0, result.length - suffix.length);
        return result;
      }
    }
    return result;
  }
}
