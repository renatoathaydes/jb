import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'jbuild_jar.g.dart';
import 'paths.dart';

Future<File> createIfNeededAndGetJBuildJarFile() async {
  final file = File(jbuildJarPath());
  if (!await file.exists()) {
    print('Creating JBuild jar');
    await _createJBuildJar(file);
  }
  return file;
}

Future<void> _createJBuildJar(File jar) async {
  await jar.parent.create(recursive: true);
  await jar.writeAsBytes(base64Decode(jbuildJarB64));
}

Map<String, Object?> asJsonMap(Map map) {
  return map.map((dynamic key, dynamic value) {
    return MapEntry(key is String ? key : '$key', value);
  });
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
