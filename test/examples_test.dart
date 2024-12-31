import 'dart:io';

import 'package:dartle/dartle.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'test_helper.dart';

const errorProneProjectDir = 'example/error-prone-java-project';
const minimalProjectDir = 'example/minimal-java-project';
const groovyProjectDir = 'example/groovy-example';

void main() {
  projectGroup(errorProneProjectDir, 'error-prone example', () {
    test('error prone plugin runs and finds problem with the code', () async {
      final jbResult =
          await runJb(Directory(errorProneProjectDir), const ['--no-color']);
      expectSuccess(jbResult, expectedExitCode: 1);
      expect(
          jbResult.stdout.join('\n'),
          allOf(
              contains(
                  'warning: [ConstantField] Fields with CONSTANT_CASE names '
                  'should be both static and final'),
              contains('static String HELLO = "Hello ErrorProne";')));
    });

    test('can print dependencies tree considering exclusions', () async {
      final jbResult = await runJb(
          Directory(errorProneProjectDir), const ['--no-color', 'dep']);
      expectSuccess(jbResult);

      final lines = jbResult.stdout as List<String>;
      final runningTaskIndex = lines.indexWhere(
          (line) => line.endsWith("INFO - Running task 'dependencies'"));
      expect(runningTaskIndex, greaterThan(0));

      // remove line that keeps changing
      final weirdLineIndex = lines.indexWhere(
          (line) => line.contains('org.eclipse.jgit'), runningTaskIndex);
      expect(weirdLineIndex, greaterThan(0));
      final weirdLine = lines.removeAt(weirdLineIndex);
      expect(
          weirdLine,
          startsWith(
              '                * org.eclipse.jgit:org.eclipse.jgit:4.4.1.201607150455-r [compile]'));

      final endIndex = lines.indexWhere(
          (line) => line.endsWith("18 compile dependencies listed"));
      expect(endIndex, greaterThan(runningTaskIndex));

      // exclusions:
      //     - org.checkerframework:.*
      //     - com.google.*error_prone_annotations.*
      expect(
          lines.sublist(runningTaskIndex + 1, endIndex).join('\n'), equals('''
Annotation processor runtime dependencies:
* jb.example:error-prone:0.0.0 (incl. transitive):
  - scope compile
    * com.google.errorprone:error_prone_core:2.16 [compile]
        * com.google.auto.service:auto-service-annotations:1.0.1 [compile]
        * com.google.auto.value:auto-value-annotations:1.9 [compile]
        * com.google.auto:auto-common:1.2.1 [compile]
            * com.google.guava:guava:31.0.1-jre [compile]
                * com.google.code.findbugs:jsr305:3.0.2 [compile]
                * com.google.guava:failureaccess:1.0.1 [compile]
                * com.google.guava:listenablefuture:9999.0-empty-to-avoid-conflict-with-guava [compile]
                * com.google.j2objc:j2objc-annotations:1.3 [compile]
        * com.google.code.findbugs:jsr305:3.0.2 [compile] (-)
        * com.google.errorprone:error_prone_annotation:2.16 [compile]
            * com.google.guava:guava:31.0.1-jre [compile] (-)
        * com.google.errorprone:error_prone_check_api:2.16 [compile]
            * com.github.ben-manes.caffeine:caffeine:3.0.5 [compile]
            * com.github.kevinstern:software-and-algorithms:1.0 [compile]
            * com.google.auto.value:auto-value-annotations:1.9 [compile] (-)
            * com.google.code.findbugs:jsr305:3.0.2 [compile] (-)
            * com.google.errorprone:error_prone_annotation:2.16 [compile] (-)
            * io.github.java-diff-utils:java-diff-utils:4.0 [compile]
        * com.google.errorprone:error_prone_type_annotations:2.16 [compile]
        * com.google.guava:guava:31.0.1-jre [compile] (-)
        * com.google.protobuf:protobuf-java:3.19.2 [compile]
        * org.pcollections:pcollections:3.1.4 [compile]'''));
    });
  });

  projectGroup(minimalProjectDir, 'minimal example', () {
    test('can compile simple Java class into a jar', () async {
      final jbResult = await runJb(Directory(minimalProjectDir));
      expectSuccess(jbResult);
      final jarPath =
          p.join(minimalProjectDir, 'build', 'minimal-java-project.jar');
      expect(await File(jarPath).exists(), isTrue,
          reason: 'jar should be created');

      final jarList = await execRead(Process.start('jar', ['-tf', jarPath]));
      expect(jarList.exitCode, equals(0));
      expect(
          jarList.stdout,
          containsAllInOrder([
            'META-INF/',
            'META-INF/MANIFEST.MF',
            'minimal/',
            'minimal/sample/',
            'minimal/sample/Sample.class',
          ]));
    });

    projectGroup(groovyProjectDir, 'Groovy example', () {
      test('can compile simple Groovy class into a jar', () async {
        final jbResult = await runJb(Directory(groovyProjectDir));
        expectSuccess(jbResult);
        final jarPath = p.join(groovyProjectDir, 'build', 'groovy-example.jar');
        expect(await File(jarPath).exists(), isTrue,
            reason: 'jar should be created');

        final jarList = await execRead(Process.start('jar', ['-tf', jarPath]));
        expect(jarList.exitCode, equals(0));
        expect(
            jarList.stdout,
            containsAllInOrder([
              'META-INF/',
              'META-INF/MANIFEST.MF',
              'example/',
              'example/Main.class',
            ]));
      });
    });

    projectGroup(groovyProjectDir, 'Spock', () {
      test('can run Spock tests', () async {
        final jbResult = await runJb(
            Directory(p.join(groovyProjectDir, 'test')),
            const ['test', '--no-color']);
        expectSuccess(jbResult);
        const unicodeResults = ''
            '└─ Spock ✔\n'
            '   └─ MainSpec ✔\n'
            '      ├─ hello spock ✔\n'
            '      └─ Immutable test ✔\n';
        const asciiResults = '\n'
            '└─ Spock [OK]\n'
            '   └─ MainSpec [OK]\n'
            '      ├─ hello spock [OK]\n'
            '      └─ Immutable test [OK]\n';
        expect(jbResult.stdout.join('\n'),
            anyOf(contains(unicodeResults), contains(asciiResults)));
      });
    });
  });
}
