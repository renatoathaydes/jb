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
  return map.map((key, value) => MapEntry(key.toString(), value));
}

extension AnyExtension<T> on T? {
  T orThrow(error) {
    if (this == null) throw error;
    return this!;
  }
}
