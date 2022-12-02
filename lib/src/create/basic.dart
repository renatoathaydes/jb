import 'dart:io';

import 'package:dartle/dartle.dart';
import 'package:path/path.dart' as p;
import 'helpers.dart';

import '../config.dart' show logger;

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

# default is src/main/java
source-dirs: [ src ]

# default is src/main/resources
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

/// Create a new jb project.
Future<void> createNewProject(List<String> arguments) async {
  if (arguments.length > 1) {
    throw DartleException(
        message: 'create command does not accept any arguments');
  }
  final jbuildFile = File('jbuild.yaml');
  await FileCreator(jbuildFile).check();
  await _create(jbuildFile);
}

Future<void> _create(File jbuildFile) async {
  stdout.write('Please enter a project group ID: ');
  final groupId = stdin.readLineSync().or('my-group');
  stdout.write('\nEnter the artifact ID of this project: ');
  final artifactId = stdin.readLineSync().or('my-app');
  final defaultPackage = '${groupId.toJavaId()}.${artifactId.toJavaId()}';
  stdout.write('\nEnter the root package [$defaultPackage]: ');
  final package = stdin.readLineSync().or(defaultPackage).validateJavaPackage();
  stdout.write('\nWould you like to create a test module [Y/n]? ');
  final createTestModule = stdin.readLineSync().or('yes').yesOrNo();
  const mainClass = 'Main';

  final fileCreators = <FileCreator>[];

  fileCreators.add(FileCreator(
      jbuildFile,
      () => jbuildFile.writeAsString(
          _jbuildYaml(groupId, artifactId, '$package.$mainClass', ''))));

  fileCreators
      .add(_createJavaFile(package, mainClass, 'src', _mainJava(package)));

  if (createTestModule) {
    fileCreators.addAll(_createTestModule(groupId, package));
  }

  await _createAll(fileCreators);

  logger.info(() =>
      PlainMessage('\nJBuild project created at ${Directory.current.path}'));
}

Future<void> _createAll(List<FileCreator> fileCreators) async {
  for (final create in fileCreators) {
    await create.check();
  }
  for (final create in fileCreators) {
    await create();
  }
}

List<FileCreator> _createTestModule(String groupId, String package) {
  final javaTestCreator = _createJavaFile(
      package, 'MainTest', p.join('test', 'src'), _mainTestJava(package));
  final buildFile = File(p.join('test', 'jbuild.yaml'));
  final buildFileCreator = FileCreator(
      buildFile,
      () => buildFile.writeAsString(
          _jbuildYaml(groupId, _testArtifactId, null, _testDependencies)));
  return [javaTestCreator, buildFileCreator];
}

FileCreator _createJavaFile(
    String package, String name, String dir, String contents) {
  final javaDir = p.joinAll([dir] + package.split('.'));
  final javaFile = File(p.join(javaDir, '$name.java'));
  return FileCreator(javaFile, () async {
    await Directory(javaDir).create(recursive: true);
    await javaFile.writeAsString(contents);
  });
}
