import 'package:path/path.dart' as path;
import 'dart:io' show Platform;

final _jbuildHome = Platform.environment['JBUILD_HOME'];

String jbuildHome() {
  final result = _jbuildHome;
  if (result == null) {
    throw Exception('JBUILD_HOME is not set.');
  }
  return result;
}

final String jbuildJarPath = path.join(jbuildHome(), 'jbuild.jar');

final String jbuildGeneratedDartFilePath =
    path.join('lib', 'src', 'jbuild_jar.g.dart');

final testProjectsDir = path.join('test', 'test-projects');

final String testMavenRepo = path.join('test', 'test-projects', 'test-repo');

final String testMavenRepoSrc =
    path.join('test', 'test-projects', 'test-repo-src');

final String listsMavenRepoProjectSrc = path.join(testMavenRepoSrc, 'lists');
