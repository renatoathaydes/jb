import 'dart:io';

import 'package:dartle/dartle.dart';
import 'package:logging/logging.dart' show Level;
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'test_helper.dart';

const helloProjectDir = 'test/test-projects/hello';
const withDepsProjectDir = 'test/test-projects/with-deps';
const withSubProjectDir = 'test/test-projects/with-sub-project';
const exampleExtensionDir = 'test/test-projects/example-extension';
const usesExtensionDir = 'test/test-projects/uses-extension';
const testsProjectDir = 'test/test-projects/tests';
const runEnvProjectDir = 'test/test-projects/run-env';

const _expectedWithSubProjectPom = '''\
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>

    <groupId>tests</groupId>
    <artifactId>greetings-app</artifactId>
    <version>1.0</version>
    <dependencies>
        <dependency>
            <groupId>tests</groupId>
            <artifactId>greetings</artifactId>
            <version>1.0</version>
            <scope>compile</scope>
        </dependency>
    </dependencies>
</project>
''';

void main() {
  activateLogging(Level.FINE);

  projectGroup(helloProjectDir, 'hello project', () {
    test('can compile basic Java class and cache result', () async {
      final jbResult = await runJb(Directory(helloProjectDir));
      expectSuccess(jbResult);
      expect(await File(p.join(helloProjectDir, 'out', 'Hello.class')).exists(),
          isTrue);

      final javaResult = await runJava(
          Directory(helloProjectDir), const ['-cp', 'out', 'Hello']);
      expectSuccess(javaResult);
      expect(javaResult.stdout, equals(const ['Hi Dartle!']));
    });
  });

  projectGroup(withDepsProjectDir, 'with-deps project', () {
    test('can install dependencies and compile project', () async {
      final jbResult =
          await runJb(Directory(withDepsProjectDir), const ['-l', 'debug']);
      expectSuccess(jbResult);

      await assertDirectoryContents(
          Directory(p.join(withDepsProjectDir, 'build')),
          [
            'with-deps.jar',
            'compile-libs',
            p.join('compile-libs', 'lists-1.0.jar'),
            p.join('compile-libs', 'minimal-java-project.jar'),
          ],
          reason: 'Did not create all artifacts.\n\n'
              'Stdout:\n${jbResult.stdout.join('\n')}\n\n'
              'Stderr:\n${jbResult.stderr.join('\n')}');

      final javaResult = await runJava(Directory(withDepsProjectDir), [
        '-cp',
        classpath(['build/with-deps.jar', 'build/compile-libs/*']),
        'com.foo.Foo',
      ]);

      expectSuccess(javaResult);
      expect(javaResult.stdout, equals(const ['Minimal jb project[1, 2, 3]']));
    });
  });

  projectGroup(withSubProjectDir, 'with-sub-project project', () {
    tearDown(() async {
      await deleteAll(dirs([
        '$withSubProjectDir/greeting/build',
        '$withSubProjectDir/greeting/.jb-cache',
      ], includeHidden: true));
    });

    test('can install dependencies and compile project', () async {
      var jbResult = await runJb(Directory(withSubProjectDir));
      expectSuccess(jbResult);
      await assertDirectoryContents(
          Directory(p.join(withSubProjectDir, 'build')), [
        p.join('out'),
        p.join('out', 'app'),
        p.join('out', 'app', 'App.class'),
        p.join('comp'),
        p.join('comp', 'greeting.jar'),
      ]);
    });

    test('can run project', () async {
      var jbResult = await runJb(
          Directory(withSubProjectDir), const ['run', '--no-color']);
      expectSuccess(jbResult);
      expect(jbResult.stdout.join('\n'),
          contains(RegExp(r'runJavaMainClass \[java \d+\]: Hello Mary!')));
      expect(jbResult.stderr, isEmpty);
    });

    test('can generate POM', () async {
      final tempPom = tempFile(extension: '.xml');
      await tempPom.delete(); // ensure  that the task can create the file
      var jbResult = await runJb(
          Directory(withSubProjectDir), ['generatePom', ':${tempPom.path}']);
      expectSuccess(jbResult);
      expect(
          jbResult.stdout.join('\n'), contains("Running task 'generatePom'"));
      expect(jbResult.stderr, isEmpty);
      expect(await tempPom.readAsString(), equals(_expectedWithSubProjectPom));
    });
  });

  projectGroup(testsProjectDir, 'tests project', () {
    tearDown(() async {
      await deleteAll(dirs([
        // this project depends on the with-sub-project project
        p.join(withSubProjectDir, 'build'),
        p.join(withSubProjectDir, '.jb-cache'),
        p.join(withSubProjectDir, 'greeting/build'),
        p.join(withSubProjectDir, 'greeting/.jb-cache'),
      ], includeHidden: true));
    });

    test('can run Java tests using two levels of sub-projects', () async {
      final jbResult =
          await runJb(Directory(testsProjectDir), const ['test', '--no-color']);
      expectSuccess(jbResult);
      await assertDirectoryContents(
          Directory(p.join(testsProjectDir, 'build')),
          [
            p.join('out', 'tests', 'AppTest.class'),
            p.join('comp', 'greeting.jar'),
            p.join('runtime', 'app', 'App.class'),
          ],
          checkLength: false); // build/runtime will contain test lib jars

      const asciiResults = '+-- JUnit Jupiter [OK]\n'
          '| \'-- AppTest [OK]\n'
          '|   +-- canGetNameFromArgs() [OK]\n'
          '|   \'-- canGetDefaultName() [OK]\n'
          '+-- JUnit Vintage [OK]\n'
          '\'-- JUnit Platform Suite [OK]\n';
      const unicodeResults = '├─ JUnit Jupiter ✔\n'
          '│  └─ AppTest ✔\n'
          '│     ├─ canGetNameFromArgs() ✔\n'
          '│     └─ canGetDefaultName() ✔\n'
          '├─ JUnit Vintage ✔\n'
          '└─ JUnit Platform Suite ✔\n';

      expect(jbResult.stdout.join('\n'),
          anyOf(contains(unicodeResults), contains(asciiResults)));
    });

    test('can run single Java test', () async {
      final jbResult = await runJb(Directory(testsProjectDir),
          const ['test', ':--include-tag', ':t1', '--no-color']);
      expectSuccess(jbResult);
      const asciiResults = '+-- JUnit Jupiter [OK]\n'
          '| \'-- AppTest [OK]\n'
          '|   \'-- canGetDefaultName() [OK]\n'
          '+-- JUnit Vintage [OK]\n'
          '\'-- JUnit Platform Suite [OK]\n';
      const unicodeResults = '├─ JUnit Jupiter ✔\n'
          '│  └─ AppTest ✔\n'
          '│     └─ canGetDefaultName() ✔\n'
          '├─ JUnit Vintage ✔\n'
          '└─ JUnit Platform Suite ✔\n';

      expect(jbResult.stdout.join('\n'),
          anyOf(contains(unicodeResults), contains(asciiResults)));
    });
  });

  projectGroup(exampleExtensionDir, 'extension project', () {
    test('can compile extension project', () async {
      var jbResult = await runJb(Directory(exampleExtensionDir));
      expectSuccess(jbResult);
      await assertDirectoryContents(
          Directory(p.join(exampleExtensionDir, 'build')), [
        'example-extension.jar',
        'compile-libs',
        p.join('compile-libs', 'jb-api.jar'),
      ]);
    });
  });

  projectGroup(usesExtensionDir, 'uses extension project', () {
    tearDown(() async {
      await deleteAll(dirs([
        // uses the example extension project
        p.join(exampleExtensionDir, 'build'),
        p.join(exampleExtensionDir, '.jb-cache'),
      ], includeHidden: true));
    });

    test('can run custom task defined by extension project', () async {
      var jbResult = await runJb(
          Directory(usesExtensionDir), const ['sample-task', '--no-color']);
      expectSuccess(jbResult);
      expect(jbResult.stdout.join('\n'),
          contains('Extension task running: SampleTask'));
    }, timeout: const Timeout(Duration(seconds: 10)));
  });

  projectGroup(runEnvProjectDir, 'Run with Env Var project', () {
    test('can run Java class that uses the environment', () async {
      var jbResult = await runJb(Directory(runEnvProjectDir), const ['run']);
      expectSuccess(jbResult);
      expect(jbResult.stdout.join('\n'), contains("MY_VAR is 'hello jbuild'"));
    }, timeout: const Timeout(Duration(seconds: 10)));
  });
}
