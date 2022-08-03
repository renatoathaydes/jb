import 'dart:convert';
import 'dart:io';
import 'package:dartle/dartle_dart.dart';
import 'package:path/path.dart' as path;

final _jbuildHome = Platform.environment['JBUILD_HOME'];

final generateEmbeddedAssetsTask = Task(generateEmbeddedAssets,
    description: 'Generates Dart sources containing embedded assets.',
    runCondition: RunOnChanges(outputs: file(jbuildGeneratedDartFilePath())));

void setupTaskDependencies(DartleDart dartleDart) {
  dartleDart.formatCode.dependsOn(const {'generateEmbeddedAssets'});
  dartleDart.analyzeCode.dependsOn(const {'generateEmbeddedAssets'});
}

String jbuildHome() {
  final result = _jbuildHome;
  if (result == null) {
    throw Exception('JBUILD_HOME is not set.');
  }
  return result;
}

String jbuildJarPath() {
  return path.join(jbuildHome(), 'jbuild.jar');
}

String jbuildGeneratedDartFilePath() {
  return path.join('lib', 'src', 'jbuild_jar.g.dart');
}

Future<void> generateEmbeddedAssets(_) async {
  final jbuildJar = File(jbuildJarPath());
  if (await jbuildJar.exists()) {
    print('Generating Dart asset embedding jbuild jar: ${jbuildJar.path}');
    await _generateEmbeddedJar(jbuildJar);
  } else {
    throw Exception('jbuild.jar cannot be found at $jbuildHome');
  }
}

Future<void> _generateEmbeddedJar(File jar) async {
  final encoded = await _b64Encode(jar);
  final out = File(jbuildGeneratedDartFilePath());
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
