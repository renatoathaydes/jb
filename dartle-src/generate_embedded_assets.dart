import 'dart:convert';
import 'dart:io';

import 'package:dartle/dartle_dart.dart';

import 'paths.dart';

final generateEmbeddedAssetsTask = Task(
  generateEmbeddedAssets,
  description: 'Generates Dart sources containing embedded assets.',
  runCondition: RunOnChanges(outputs: file(jbuildGeneratedDartFilePath)),
);

void setupTaskDependencies(DartleDart dartleDart) {
  dartleDart.formatCode.dependsOn(const {'generateEmbeddedAssets'});
  dartleDart.analyzeCode.dependsOn(const {'generateEmbeddedAssets'});
  dartleDart.test.dependsOn(const {'compileExe'});
}

Future<void> generateEmbeddedAssets(_) async {
  final out = File(jbuildGeneratedDartFilePath);
  final outStats = await out.stat();
  if (outStats.type == FileSystemEntityType.file && outStats.size > 32) {
    return print(
      'Will not generate $jbuildGeneratedDartFilePath '
      'as it already exists (size > 32)!',
    );
  }
  final jbuildJar = File(await jbuildJarPath(allowUsingEmbedded: false));
  if (await jbuildJar.exists()) {
    print('Generating Dart asset embedding jbuild jar: ${jbuildJar.path}');
    await _generateEmbeddedJar(jbuildJar, out);
  } else {
    throw Exception('jbuild.jar cannot be found at ${jbuildJar.path}');
  }
}

Future<void> _generateEmbeddedJar(File jar, File out) async {
  final encoded = await _b64Encode(jar);
  final outHandle = await out.open(mode: FileMode.writeOnly);
  try {
    await outHandle.writeString("const jbuildJarB64 = '");
    await outHandle.writeString(encoded);
    await outHandle.writeString("';\n");
  } finally {
    await outHandle.close();
  }
}

Future<String> _b64Encode(File file) async {
  final contents = await file.readAsBytes();
  return base64Encode(contents);
}
