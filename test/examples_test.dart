import 'dart:io';

import 'package:dartle/dartle.dart';
import 'package:jb/jb.dart' show groovy3, groovy4;
import 'package:jb/src/java_info.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'test_helper.dart';

const errorProneProjectDir = 'example/error-prone-java-project';
const minimalProjectDir = 'example/minimal-java-project';
const groovyProjectDir = 'example/groovy-example';

const groovy3Version = '3.0.25';
const groovy4Version = '4.0.20';
const groovy5Version = '5.0.0';
const groovy3Dep = '  $groovy3:$groovy3Version:';
const groovy4Dep = '  $groovy4:$groovy4Version:';
const groovy5Dep = '  $groovy4:$groovy5Version:';

void main() async {
  final javaInfo = await detectJavaInfo();
  final javaOlderThan17 = (javaInfo?.majorVersion ?? 21) < 17;

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
          '│   x com.google.errorprone:error_prone_annotations:.*\n'
          '│   x org.checkerframework:.*\n'
          '├── com.google.errorprone:error_prone_annotations:2.49.0\n'
          '├── com.google.errorprone:error_prone_core:2.49.0\n'
          '│   ├── com.google.auto.service:auto-service-annotations:1.0.1\n'
          '│   ├── com.google.auto.value:auto-value-annotations:1.9\n'
          '│   ├── com.google.auto:auto-common:1.2.2\n'
          '│   ├── com.google.errorprone:error_prone_annotation:2.49.0\n'
          '│   ├── com.google.errorprone:error_prone_check_api:2.49.0\n'
          '│   │   ├── com.github.ben-manes.caffeine:caffeine:3.0.5\n'
          '│   │   ├── com.github.kevinstern:software-and-algorithms:1.0\n'
          '│   │   ├── com.google.auto.value:auto-value-annotations:1.9 (-)\n'
          '│   │   ├── com.google.errorprone:error_prone_annotation:2.49.0 (-)\n'
          '│   │   ├── io.github.eisop:dataflow-errorprone:3.41.0-eisop1\n'
          '│   │   ├── io.github.java-diff-utils:java-diff-utils:4.12\n'
          '│   │   ├── javax.inject:javax.inject:1\n'
          '│   │   └── org.jspecify:jspecify:1.0.0\n'
          '│   ├── com.google.googlejavaformat:google-java-format:1.35.0\n'
          '│   ├── com.google.protobuf:protobuf-java:4.33.2\n'
          '│   ├── io.github.eisop:dataflow-errorprone:3.41.0-eisop1 (-)\n'
          '│   ├── javax.inject:javax.inject:1 (-)\n'
          '│   ├── org.jspecify:jspecify:1.0.0 (-)\n'
          '│   └── org.pcollections:pcollections:4.0.1\n'
          '└── com.google.guava:guava:32.1.3-jre\n'
          '    ├── com.google.guava:failureaccess:1.0.1\n'
          '    ├── com.google.guava:listenablefuture:9999.0-empty-to-avoid-conflict-with-guava\n'
          '    └── com.google.j2objc:j2objc-annotations:2.8',
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
          '│   x com.google.errorprone:error_prone_annotations:.*\n'
          '│   x org.checkerframework:.*\n'
          '├── com.google.errorprone:error_prone_annotations:2.49.0 [Apache-2.0]\n'
          '├── com.google.errorprone:error_prone_core:2.49.0 [Apache-2.0]\n'
          '│   ├── com.google.auto.service:auto-service-annotations:1.0.1 [Apache-2.0]\n'
          '│   ├── com.google.auto.value:auto-value-annotations:1.9 [Apache-2.0]\n'
          '│   ├── com.google.auto:auto-common:1.2.2 [Apache-2.0]\n'
          '│   ├── com.google.errorprone:error_prone_annotation:2.49.0 [Apache-2.0]\n'
          '│   ├── com.google.errorprone:error_prone_check_api:2.49.0 [Apache-2.0]\n'
          '│   │   ├── com.github.ben-manes.caffeine:caffeine:3.0.5 [Apache-2.0]\n'
          '│   │   ├── com.github.kevinstern:software-and-algorithms:1.0 [MIT]\n'
          '│   │   ├── com.google.auto.value:auto-value-annotations:1.9 (-)\n'
          '│   │   ├── com.google.errorprone:error_prone_annotation:2.49.0 (-)\n'
          '│   │   ├── io.github.eisop:dataflow-errorprone:3.41.0-eisop1 [GNU General Public License, version 2 (GPL2), with the classpath exception]\n'
          '│   │   ├── io.github.java-diff-utils:java-diff-utils:4.12 [Apache-2.0]\n'
          '│   │   ├── javax.inject:javax.inject:1 [Apache-2.0]\n'
          '│   │   └── org.jspecify:jspecify:1.0.0 [Apache-2.0]\n'
          '│   ├── com.google.googlejavaformat:google-java-format:1.35.0 [Apache-2.0]\n'
          '│   ├── com.google.protobuf:protobuf-java:4.33.2 [BSD-3-Clause]\n'
          '│   ├── io.github.eisop:dataflow-errorprone:3.41.0-eisop1 (-)\n'
          '│   ├── javax.inject:javax.inject:1 (-)\n'
          '│   ├── org.jspecify:jspecify:1.0.0 (-)\n'
          '│   └── org.pcollections:pcollections:4.0.1 [MIT]\n'
          '└── com.google.guava:guava:32.1.3-jre [Apache-2.0]\n'
          '    ├── com.google.guava:failureaccess:1.0.1 [Apache-2.0]\n'
          '    ├── com.google.guava:listenablefuture:9999.0-empty-to-avoid-conflict-with-guava [Apache-2.0]\n'
          '    └── com.google.j2objc:j2objc-annotations:2.8 [Apache-2.0]\n'
          'The listed dependencies use 4 licenses:\n'
          '  - Apache-2.0 (https://spdx.org/licenses/Apache-2.0.html, OSI?=true, FSF?=true)\n'
          '  - BSD-3-Clause (https://spdx.org/licenses/BSD-3-Clause.html, OSI?=true, FSF?=true)\n'
          '  - GNU General Public License, version 2 (GPL2), with the classpath exception (http://www.gnu.org/software/classpath/license.html)\n'
          '  - MIT (https://spdx.org/licenses/MIT.html, OSI?=true, FSF?=true)',
        ),
      );
    });
    // ErrorProne's latest version only works with Java 17+
  }, skip: javaOlderThan17);

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
    // end minimal project group
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

    Future<void> runGroovyProjectTestPublishTask(
      String mavenHome,
      groovyVersion,
    ) async {
      try {
        final jbResult = await runJb(
          Directory(groovyProjectDir),
          const ['publish'],
          {'MAVEN_LOCAL_HOME': mavenHome},
        );

        expectSuccess(jbResult);
        await assertDirectoryContents(
          Directory(p.join(groovyProjectDir, mavenHome)),
          [
            p.join(
              'org',
              (groovyVersion == groovy3Version) ? 'codehaus' : 'apache',
              'groovy',
              'groovy-docgenerator',
              groovyVersion,
              'groovy-docgenerator-$groovyVersion.pom',
            ),
            p.join(
              'org',
              (groovyVersion == groovy3Version) ? 'codehaus' : 'apache',
              'groovy',
              'groovy-docgenerator',
              groovyVersion,
              'groovy-docgenerator-$groovyVersion.jar',
            ),
          ],
          checkLength: false,
        );
      } finally {
        await deleteAll(dir(p.join(groovyProjectDir, mavenHome)));
      }
    }

    test('can publish Groovy project (Groovy 4)', () async {
      const mavenHome = 'mvn-home-groovy-4';
      await runGroovyProjectTestPublishTask(mavenHome, groovy4Version);
    });

    test('can publish Groovy project (Groovy 3)', () async {
      const mavenHome = 'mvn-home-groovy-3';
      final originalJbFileLines = await _changeGroovyProjectToUseGroovy(3);

      try {
        await runGroovyProjectTestPublishTask(mavenHome, groovy3Version);
      } finally {
        await _restoreGroovyProjectJbFile(originalJbFileLines);
      }
    });

    test('can publish Groovy project (Groovy 5)', () async {
      const mavenHome = 'mvn-home-groovy-5';
      final originalJbFileLines = await _changeGroovyProjectToUseGroovy(5);

      try {
        await runGroovyProjectTestPublishTask(mavenHome, groovy5Version);
      } finally {
        await _restoreGroovyProjectJbFile(originalJbFileLines);
      }
    });

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

    test(
      'when upgrading library (Groovy 4 to 5) libs directories are updated',
      () async {
        var jbResult = await runJb(Directory(groovyProjectDir), [
          'installRuntime',
        ]);
        expectSuccess(jbResult);
        final jarPath = p.join(groovyProjectDir, 'build', 'groovy-example.jar');
        expect(
          await File(jarPath).exists(),
          isTrue,
          reason: 'jar should be created',
        );
        await assertDirectoryContents(
          Directory(p.join(groovyProjectDir, 'build', 'compile-libs')),
          ['groovy-$groovy4Version.jar', 'groovy-$groovy4Version.pom'],
        );
        await assertDirectoryContents(
          Directory(p.join(groovyProjectDir, 'build', 'runtime-libs')),
          [
            'groovy-$groovy4Version.jar',
            'groovy-$groovy4Version.pom',
            'groovy-example.jar',
          ],
        );
        // verify the checksum file
        await verifyDependenciesChecksums(Directory(groovyProjectDir), {
          '$groovy4:$groovy4Version':
              'd5bd8f500fc3fac63b6de06e597940defb8320fa',
        });

        // when we upgrade to Groovy 5, the libs dir must be cleaned up
        final originalJbFileLines = await _changeGroovyProjectToUseGroovy(5);

        try {
          var jbResult = await runJb(Directory(groovyProjectDir), [
            'installRuntime',
          ]);
          expectSuccess(jbResult);
          await assertDirectoryContents(
            Directory(p.join(groovyProjectDir, 'build', 'compile-libs')),
            ['groovy-$groovy5Version.jar', 'groovy-$groovy5Version.pom'],
          );
          await assertDirectoryContents(
            Directory(p.join(groovyProjectDir, 'build', 'runtime-libs')),
            [
              'groovy-$groovy5Version.jar',
              'groovy-$groovy5Version.pom',
              'groovy-example.jar',
            ],
          );
          // verify the checksum file was updated correctly
          await verifyDependenciesChecksums(Directory(groovyProjectDir), {
            '$groovy4:$groovy5Version':
                'b4e9817ec0f53d48670a414f9090492c9c459643',
          });
        } finally {
          await _restoreGroovyProjectJbFile(originalJbFileLines);
        }
      },
    );
  }, subDirectories: ['test']);
}

Future<List<String>> _changeGroovyProjectToUseGroovy(int groovyVersion) async {
  final groovyDep = switch (groovyVersion) {
    3 => groovy3Dep,
    5 => groovy5Dep,
    _ => throw Exception('Groovy version is not supported: $groovyVersion'),
  };
  final jbFile = File(p.join(groovyProjectDir, 'jbuild.yaml'));
  final lines = await jbFile.readAsLines();
  final groovyDepLineIndex = lines.indexWhere((line) => line == groovy4Dep);
  if (groovyDepLineIndex < 0) {
    fail('Cannot find the groovy dependency in ${jbFile.path}');
  }
  final jbFileWriter = jbFile.openWrite();
  try {
    for (final (index, line) in lines.indexed) {
      if (index == groovyDepLineIndex) {
        jbFileWriter.writeln(groovyDep);
      } else {
        jbFileWriter.writeln(line);
      }
    }
  } finally {
    await jbFileWriter.close();
  }
  return lines;
}

Future<void> _restoreGroovyProjectJbFile(List<String> originalLines) async {
  final jbFile = File(p.join(groovyProjectDir, 'jbuild.yaml'));
  await jbFile.writeAsString(
    originalLines.join(Platform.lineTerminator) + Platform.lineTerminator,
  );
}
