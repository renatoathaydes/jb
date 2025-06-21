import 'dart:convert';
import 'dart:io' show File, Directory, Platform;

import 'package:path/path.dart' as path;

// ignore: avoid_relative_lib_imports
import '../lib/src/jbuild_jar.g.dart' show jbuildJarB64;

final _jbuildHome = Platform.environment['JBUILD_HOME'];

final String jbuildGeneratedDartFilePath = path.join(
  'lib',
  'src',
  'jbuild_jar.g.dart',
);

final testProjectsDir = path.join('test', 'test-projects');
final exampleProjectsDir = 'example';

final String testMavenRepo = path.join('test', 'test-projects', 'test-repo');

final String testMavenRepoSrc = path.join(
  'test',
  'test-projects',
  'test-repo-src',
);

final String listsMavenRepoProjectSrc = path.join(testMavenRepoSrc, 'lists');

File? _generatedJBuildJar;

Future<String> jbuildJarPath({bool allowUsingEmbedded = true}) async {
  final home = _jbuildHome;
  if (home != null) {
    final jarPath = path.join(home, 'jbuild.jar');
    final jar = File(jarPath);
    if (await jar.exists()) {
      return jarPath;
    }
    throw Exception(r'$JBUILD_HOME/jbuild.jar file does not exist');
  }
  if (!allowUsingEmbedded) {
    throw Exception('JBUILD_HOME is not set!');
  }
  var generatedJar = _generatedJBuildJar;
  if (generatedJar == null) {
    generatedJar = File(path.join(Directory.systemTemp.path, 'jbuild.jar'));
    _generatedJBuildJar = generatedJar;
    print('Writing embedded JBuild jar to temp file: ${generatedJar.path}');
    await generatedJar.writeAsBytes(base64Decode(jbuildJarB64));
  }
  return generatedJar.path;
}
