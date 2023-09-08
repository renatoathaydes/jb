import 'dart:io';

import 'package:path/path.dart' as p;

import '../config.dart' show jbFile;
import 'helpers.dart';

const _testArtifactId = 'tests';

const _testDependencies = '''\
  - org.junit.jupiter:junit-jupiter-api:5.8.2
  - org.assertj:assertj-core:3.22.0
  - core-module:
      path: ../
''';

String _jbuildYaml(String groupId, String artifactId, String? mainClass,
        String dependencies) =>
    '''
group: $groupId
module: $artifactId
version: '0.0.0'

# default is src
source-dirs: [ src ]

# default is resources
resource-dirs: [ resources ]

${artifactId == _testArtifactId ? ''
            '# do not create a redundant jar for tests\n'
            'output-dir: build/classes\n' : '''
# The following options use the default values and could be omitted
compile-libs-dir: build/compile-libs
runtime-libs-dir: build/runtime-libs
test-reports-dir: build/test-reports

# Specify a jar to package this project into.
# Use `output-dir` instead to keep class files unpacked.
# default is `build/<project-dir>.jar`.
output-jar: build/$artifactId.jar${mainClass == null ? '' : '''\n
# To be able to use the 'run' task without arguments, specify the main-class to run.
# You can also run any class by invoking `jb run :--main-class=some.other.Class`.
main-class: $mainClass'''}
'''}
# dependencies can be Maven artifacts or other jb projects
dependencies:
$dependencies''';

String _mainJava(String package) => '''
package $package;

final class Main {
    static String greeting() {
        return "Hello world!";
    }
    public static void main(String[] args) {
        System.out.println(greeting());
    }
}
''';

String _mainTestJava(String package) => '''
package $package;

import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

final class MainTest {
  @Test
  void greetingTest() {
      assertThat(Main.greeting()).isEqualTo("Hello world!");
  }
}
''';

List<FileCreator> getBasicFileCreators(File jbuildFile,
    {required String groupId,
    required String artifactId,
    required String package,
    required bool createTestModule}) {
  const mainClass = 'Main';

  return [
    FileCreator(
        jbuildFile,
        () => jbuildFile.writeAsString(
            _jbuildYaml(groupId, artifactId, '$package.$mainClass', ''))),
    createJavaFile(package, mainClass, 'src', _mainJava(package)),
    if (createTestModule) ..._createTestModule(groupId, package),
  ];
}

List<FileCreator> _createTestModule(String groupId, String package) {
  final javaTestCreator = createJavaFile(
      package, 'MainTest', p.join('test', 'src'), _mainTestJava(package));
  final buildFile = File(p.join('test', jbFile));
  final buildFileCreator = FileCreator(
      buildFile,
      () => buildFile.writeAsString(
          _jbuildYaml(groupId, _testArtifactId, null, _testDependencies)));
  return [javaTestCreator, buildFileCreator];
}
