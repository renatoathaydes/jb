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

void main() {
  activateLogging(Level.FINE);

  projectGroup(helloProjectDir, 'hello project', () {
    tearDown(() async {
      await deleteAll(dirs([
        p.join(helloProjectDir, 'build'),
        p.join(helloProjectDir, '.jb-cache'),
        p.join(helloProjectDir, 'out'),
      ], includeHidden: true));
    });

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
    tearDown(() async {
      await deleteAll(dirs([
        p.join(withDepsProjectDir, 'build', 'compile-libs'),
        p.join(withDepsProjectDir, 'build', 'runtime-libs'),
        p.join(withDepsProjectDir, '.jb-cache'),
      ], includeHidden: true));
      await deleteAll(file(p.join(withDepsProjectDir, 'with-deps.jar')));
    });

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
        '$withSubProjectDir/build',
        '$withSubProjectDir/.jb-cache',
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
  });

  projectGroup(testsProjectDir, 'tests project', () {
    tearDown(() async {
      await deleteAll(dirs([
        p.join(testsProjectDir, 'build'),
        p.join(testsProjectDir, '.jb-cache'),
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
    tearDown(() async {
      await deleteAll(dirs([
        p.join(exampleExtensionDir, 'build'),
        p.join(exampleExtensionDir, '.jb-cache'),
      ], includeHidden: true));
    });

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
        p.join(usesExtensionDir, 'build'),
        p.join(usesExtensionDir, '.jb-cache'),
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
}

void projectGroup(String projectDir, String name, Function() definition) {
  final outputDirs = dirs([
    p.join(projectDir, '.jb-cache'),
    p.join(projectDir, 'out'),
    p.join(projectDir, 'compile-libs'),
    p.join(projectDir, 'runtime-libs'),
  ], includeHidden: true);

  setUp(() async {
    await deleteAll(outputDirs);
  });

  tearDownAll(() async {
    await deleteAll(outputDirs);
  });

  group(name, definition);
}
