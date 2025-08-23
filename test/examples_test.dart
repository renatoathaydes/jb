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
      final jbResult = await runJb(Directory(errorProneProjectDir), const [
        '--no-color',
      ]);
      expectSuccess(jbResult, expectedExitCode: 1);
      expect(
        jbResult.stdout.join('\n'),
        allOf(
          contains(
            'warning: [ConstantField] Fields with CONSTANT_CASE names '
            'should be both static and final',
          ),
          contains('static String HELLO = "Hello ErrorProne";'),
        ),
      );
    });

    test('can print dependencies tree considering exclusions', () async {
      final jbResult = await runJb(Directory(errorProneProjectDir), const [
        '--no-color',
        'dep',
      ]);
      expectSuccess(jbResult);

      final lines = jbResult.stdout as List<String>;
      final runningTaskIndex = lines.indexWhere(
        (line) => line.endsWith("INFO - Running task 'dependencies'"),
      );
      expect(runningTaskIndex, greaterThan(0));

      final endIndex = lines.indexWhere(
        (line) => line.startsWith("Build succeeded in "),
      );
      expect(endIndex, greaterThan(runningTaskIndex));

      expect(
        lines.sublist(runningTaskIndex + 1, endIndex).join('\n'),
        equals(
          'Annotation processor dependencies:\n'
          'jb.example:error-prone:0.0.0:\n'
          '│   x com.google.*error_prone_annotation.*\n'
          '│   x org.checkerframework:.*\n'
          '└── com.google.errorprone:error_prone_core:2.16\n'
          '    ├── com.google.auto.service:auto-service-annotations:1.0.1\n'
          '    ├── com.google.auto.value:auto-value-annotations:1.9\n'
          '    ├── com.google.auto:auto-common:1.2.1\n'
          '    │   └── com.google.guava:guava:31.0.1-jre\n'
          '    │       ├── com.google.code.findbugs:jsr305:3.0.2\n'
          '    │       ├── com.google.guava:failureaccess:1.0.1\n'
          '    │       ├── com.google.guava:listenablefuture:9999.0-empty-to-avoid-conflict-with-guava\n'
          '    │       └── com.google.j2objc:j2objc-annotations:1.3\n'
          '    ├── com.google.code.findbugs:jsr305:3.0.2 (-)\n'
          '    ├── com.google.errorprone:error_prone_check_api:2.16\n'
          '    │   ├── com.github.ben-manes.caffeine:caffeine:3.0.5\n'
          '    │   ├── com.github.kevinstern:software-and-algorithms:1.0\n'
          '    │   ├── com.google.auto.value:auto-value-annotations:1.9 (-)\n'
          '    │   ├── com.google.code.findbugs:jsr305:3.0.2 (-)\n'
          '    │   └── io.github.java-diff-utils:java-diff-utils:4.0\n'
          '    │       └── org.eclipse.jgit:org.eclipse.jgit:4.4.1.201607150455-r\n'
          '    │           x com.googlecode.javaewah:JavaEWAH\n'
          '    │           x com.jcraft:jsch\n'
          '    │           x commons-codec:commons-codec\n'
          '    │           x commons-logging:commons-logging\n'
          '    │           x org.apache.httpcomponents:httpclient\n'
          '    │           x org.slf4j:slf4j-api\n'
          '    ├── com.google.errorprone:error_prone_type_annotations:2.16\n'
          '    ├── com.google.guava:guava:31.0.1-jre (-)\n'
          '    ├── com.google.protobuf:protobuf-java:3.19.2\n'
          '    └── org.pcollections:pcollections:3.1.4',
        ),
      );
    });

    test('can print dependencies tree considering exclusions (with licenses)', () async {
      final jbResult = await runJb(Directory(errorProneProjectDir), const [
        '--no-color',
        'dep',
        ':-l',
      ]);
      expectSuccess(jbResult);

      final lines = jbResult.stdout as List<String>;
      final runningTaskIndex = lines.indexWhere(
        (line) => line.endsWith("INFO - Running task 'dependencies'"),
      );
      expect(runningTaskIndex, greaterThan(0));

      final endIndex = lines.indexWhere(
        (line) => line.startsWith("Build succeeded in "),
      );
      expect(endIndex, greaterThan(runningTaskIndex));

      expect(
        lines.sublist(runningTaskIndex + 1, endIndex).join('\n'),
        equals(
          'Annotation processor dependencies:\n'
          'jb.example:error-prone:0.0.0:\n'
          '│   x com.google.*error_prone_annotation.*\n'
          '│   x org.checkerframework:.*\n'
          '└── com.google.errorprone:error_prone_core:2.16 [Apache-2.0]\n'
          '    ├── com.google.auto.service:auto-service-annotations:1.0.1 [Apache-2.0]\n'
          '    ├── com.google.auto.value:auto-value-annotations:1.9 [Apache-2.0]\n'
          '    ├── com.google.auto:auto-common:1.2.1 [Apache-2.0]\n'
          '    │   └── com.google.guava:guava:31.0.1-jre [Apache-2.0]\n'
          '    │       ├── com.google.code.findbugs:jsr305:3.0.2 [Apache-2.0]\n'
          '    │       ├── com.google.guava:failureaccess:1.0.1 [Apache-2.0]\n'
          '    │       ├── com.google.guava:listenablefuture:9999.0-empty-to-avoid-conflict-with-guava [Apache-2.0]\n'
          '    │       └── com.google.j2objc:j2objc-annotations:1.3 [Apache-2.0]\n'
          '    ├── com.google.code.findbugs:jsr305:3.0.2 (-)\n'
          '    ├── com.google.errorprone:error_prone_check_api:2.16 [Apache-2.0]\n'
          '    │   ├── com.github.ben-manes.caffeine:caffeine:3.0.5 [Apache-2.0]\n'
          '    │   ├── com.github.kevinstern:software-and-algorithms:1.0 [MIT]\n'
          '    │   ├── com.google.auto.value:auto-value-annotations:1.9 (-)\n'
          '    │   ├── com.google.code.findbugs:jsr305:3.0.2 (-)\n'
          '    │   └── io.github.java-diff-utils:java-diff-utils:4.0 [Apache-2.0]\n'
          '    │       └── org.eclipse.jgit:org.eclipse.jgit:4.4.1.201607150455-r [Eclipse Distribution License (New BSD License)]\n'
          '    │           x com.googlecode.javaewah:JavaEWAH\n'
          '    │           x com.jcraft:jsch\n'
          '    │           x commons-codec:commons-codec\n'
          '    │           x commons-logging:commons-logging\n'
          '    │           x org.apache.httpcomponents:httpclient\n'
          '    │           x org.slf4j:slf4j-api\n'
          '    ├── com.google.errorprone:error_prone_type_annotations:2.16 [Apache-2.0]\n'
          '    ├── com.google.guava:guava:31.0.1-jre (-)\n'
          '    ├── com.google.protobuf:protobuf-java:3.19.2 [3-Clause BSD License]\n'
          '    └── org.pcollections:pcollections:3.1.4 [MIT]\n'
          'The listed dependencies use 4 licenses:\n'
          '  - 3-Clause BSD License (https://opensource.org/licenses/BSD-3-Clause)\n'
          '  - Apache-2.0 (https://spdx.org/licenses/Apache-2.0.html, OSI?=true, FSF?=true)\n'
          '  - Eclipse Distribution License (New BSD License)\n'
          '  - MIT (https://spdx.org/licenses/MIT.html, OSI?=true, FSF?=true)',
        ),
      );
    });
  });

  projectGroup(minimalProjectDir, 'minimal example', () {
    test('can compile simple Java class into a jar', () async {
      final jbResult = await runJb(Directory(minimalProjectDir));
      expectSuccess(jbResult);
      final jarPath = p.join(
        minimalProjectDir,
        'build',
        'minimal-java-project.jar',
      );
      expect(
        await File(jarPath).exists(),
        isTrue,
        reason: 'jar should be created',
      );

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
        ]),
      );
    });

    projectGroup(groovyProjectDir, 'Groovy example', () {
      test('can compile simple Groovy class into a jar', () async {
        final jbResult = await runJb(Directory(groovyProjectDir));
        expectSuccess(jbResult);
        final jarPath = p.join(groovyProjectDir, 'build', 'groovy-example.jar');
        expect(
          await File(jarPath).exists(),
          isTrue,
          reason: 'jar should be created',
        );

        final jarList = await execRead(Process.start('jar', ['-tf', jarPath]));
        expect(jarList.exitCode, equals(0));
        expect(
          jarList.stdout,
          containsAllInOrder([
            'META-INF/',
            'META-INF/MANIFEST.MF',
            'example/',
            'example/Main.class',
          ]),
        );
      });
    });

    projectGroup(groovyProjectDir, 'Spock', () {
      test('can run Spock tests', () async {
        final jbResult = await runJb(
          Directory(p.join(groovyProjectDir, 'test')),
          const ['test', '--no-color'],
        );
        expectSuccess(jbResult);
        const unicodeResults =
            ''
            '└─ Spock ✔\n'
            '   └─ MainSpec ✔\n'
            '      ├─ hello spock ✔\n'
            '      └─ Immutable test ✔\n';
        const asciiResults =
            '\n'
            '\'-- Spock [OK]\n'
            '  \'-- MainSpec [OK]\n'
            '    +-- hello spock [OK]\n'
            '    \'-- Immutable test [OK]\n';
        expect(
          jbResult.stdout.join('\n'),
          anyOf(contains(unicodeResults), contains(asciiResults)),
        );
      });
    });
  });
}
