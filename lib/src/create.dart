import 'dart:io';

import 'package:dartle/dartle.dart';
import 'package:path/path.dart' as p;

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

source-dirs: [ src ]
compile-libs-dir: build/compile
runtime-libs-dir: build/runtime
output-jar: build/$artifactId.jar${mainClass == null ? '' : '\nmain-class: $mainClass'}

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

Future<void> createNewProject(List<String> arguments) async {
  if (arguments.length > 1) {
    throw DartleException(
        message: 'create command does not accept any arguments');
  }
  final jbuildFile = File('jbuild.yaml');
  if (await jbuildFile.exists()) {
    throw DartleException(
        message: 'Cannot create jb project, jbuildy.yaml already exists.');
  }
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

  await jbuildFile.writeAsString(
      _jbuildYaml(groupId, artifactId, '$package.$mainClass', ''));

  await _createJavaFile(package, mainClass, 'src', _mainJava(package));

  if (createTestModule) {
    await _createTestModule(groupId, package);
  }
  print('JBuild project created at ${Directory.current.path}');
}

Future<void> _createTestModule(String groupId, String package) async {
  await _createJavaFile(
      package, 'MainTest', p.join('test', 'src'), _mainTestJava(package));
  await File(p.join('test', 'jbuild.yaml'))
      .writeAsString(_jbuildYaml(groupId, 'tests', null, _testDependencies));
}

Future<void> _createJavaFile(
    String package, String name, String dir, String contents) async {
  final javaDir = p.joinAll([dir] + package.split('.'));
  await Directory(javaDir).create(recursive: true);
  final javaFile = File(p.join(javaDir, '$name.java'));
  await javaFile.writeAsString(contents);
}

extension on String? {
  String or(String defaultValue) {
    final String? self = this;
    if (self == null) {
      throw DartleException(message: 'No input available');
    }
    if (self.trim().isEmpty) {
      return defaultValue;
    }
    return self;
  }

  bool yesOrNo() {
    final String? s = this;
    return s == null ||
        s.trim().isEmpty ||
        const {'yes', 'y'}.contains(s.toLowerCase());
  }
}

final _javaIdPattern = RegExp(r'^[a-zA-Z_$][a-zA-Z_$\d]*$');

extension on String {
  String toJavaId() {
    return replaceAll('-', '_');
  }

  String validateJavaPackage() {
    if (this == '.' || startsWith('.') || endsWith('.')) {
      throw DartleException(message: 'Invalid Java package name: $this');
    }
    for (final part in split('.')) {
      if (!_javaIdPattern.hasMatch(part)) {
        throw DartleException(
            message:
                'Invalid Java package name: $this (invalid segment: $part)');
      }
    }
    return this;
  }
}
