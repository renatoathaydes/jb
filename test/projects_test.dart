import 'dart:convert';
import 'dart:io';

import 'package:dartle/dartle.dart';
import 'package:logging/logging.dart' show Level;
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'test_helper.dart';

const projectsDir = 'test/test-projects';
const helloProjectDir = '$projectsDir/hello';
const emptyProjectDir = '$projectsDir/empty';
const withDepsProjectDir = '$projectsDir/with-deps';
const withSubProjectDir = '$projectsDir/with-sub-project';
const exampleExtensionDir = '$projectsDir/example-extension';
const usesExtensionDir = '$projectsDir/uses-extension';
const testsProjectDir = '$projectsDir/tests';
const runEnvProjectDir = '$projectsDir/run-env';

const _expectedWithSubProjectPom = '''\
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">
  <modelVersion>4.0.0</modelVersion>
  <groupId>tests</groupId>
  <artifactId>greetings-app</artifactId>
  <version>1.0</version>
  <name>Greetings App</name>
  <dependencies>
    <dependency>
      <groupId>tests</groupId>
      <artifactId>greetings</artifactId>
      <version>1.0</version>
      <scope>compile</scope>
    </dependency>
  </dependencies>
</project>''';

const _fooJavaFileContents = '''\
class Foo {}
''';

void main() {
  activateLogging(Level.INFO);

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
      final jbResult = await runJb(Directory(withDepsProjectDir), const []);
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
      var jbResult = await runJb(Directory(withSubProjectDir),
          ['generatePom', ':${tempPom.path}', '--no-color']);
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
          '\'-- JUnit Vintage [OK]\n';
      const unicodeResults = '├─ JUnit Jupiter ✔\n'
          '│  └─ AppTest ✔\n'
          '│     ├─ canGetNameFromArgs() ✔\n'
          '│     └─ canGetDefaultName() ✔\n'
          '└─ JUnit Vintage ✔\n';

      expect(jbResult.stdout.join('\n'),
          anyOf(contains(unicodeResults), contains(asciiResults)));
    }, testOn: '!windows');

    test('can run single Java test', () async {
      // install compile dependencies and check they are installed
      final jbInstallResult = await runJb(Directory(testsProjectDir),
          const ['installCompileDependencies', '--no-color']);
      expectSuccess(jbInstallResult);
      await assertDirectoryContents(
          Directory(p.join(testsProjectDir, 'build', 'comp')),
          ['app', p.join('app', 'App.class')],
          checkLength: false);
      // run the test
      final jbResult = await runJb(Directory(testsProjectDir),
          const ['test', ':--include-tag', ':t1', '--no-color']);
      expectSuccess(jbResult);
      const asciiResults = '+-- JUnit Jupiter [OK]\n'
          '| \'-- AppTest [OK]\n'
          '|   \'-- canGetDefaultName() [OK]\n'
          '\'-- JUnit Vintage [OK]\n';
      const unicodeResults = '├─ JUnit Jupiter ✔\n'
          '│  └─ AppTest ✔\n'
          '│     └─ canGetDefaultName() ✔\n'
          '└─ JUnit Vintage ✔\n';

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
        p.join('compile-libs', 'jbuild-api-0.10.0.jar'),
      ]);
    });
  });

  projectGroup(usesExtensionDir, 'uses extension project', () {
    tearDown(() async {
      await deleteAll(MultiFileCollection([
        dirs([
          // uses the example extension project
          p.join(exampleExtensionDir, 'build'),
          p.join(exampleExtensionDir, '.jb-cache'),
          p.join(usesExtensionDir, 'output-resources'),
        ], includeHidden: true),
        // these files are created by the test
        file(p.join(usesExtensionDir, 'input-resources', 'new.txt')),
        file(p.join(exampleExtensionDir, 'src', 'Foo.java')),
      ]));
    });

    test('can run custom task defined by extension project', () async {
      var jbResult = await runJb(
          Directory(usesExtensionDir), const ['sample-task', '--no-color']);
      expectSuccess(jbResult);
      expect(jbResult.stdout.join('\n'),
          contains('Extension task running: SampleTask'));
    }, timeout: const Timeout(Duration(seconds: 10)));

    test('can run custom task defined by extension project from another dir',
        () async {
      var jbResult = await runJb(Directory(projectsDir),
          ['copyFile', '--no-color', '-p', p.basename(usesExtensionDir)]);
      expectSuccess(jbResult);

      // ensure we did not copy the file to the wrong place
      expect(await Directory(p.join(projectsDir, 'output-resources')).exists(),
          isFalse);

      await assertDirectoryContents(
          Directory(p.join(usesExtensionDir, 'output-resources')), [
        'hello.txt',
        'bye.txt',
      ]);
      expect(
          await File(p.join(usesExtensionDir, 'output-resources', 'hello.txt'))
              .readAsString(),
          equals('Hello'));
      expect(
          await File(p.join(usesExtensionDir, 'output-resources', 'bye.txt'))
              .readAsString(),
          equals('Bye'));

      // should not run again as the task output is cached
      jbResult = await runJb(Directory(projectsDir),
          ['copyFile', '--no-color', '-p', p.basename(usesExtensionDir)]);
      expectSuccess(jbResult);
      expect(
          jbResult.stdout.where(
              (String line) => line.endsWith('to output-resources directory')),
          isEmpty);
      expect(jbResult.stdout, hasLength(greaterThan(2)));
      expect(lastItems(2, jbResult.stdout), [
        'Everything is up-to-date!',
        startsWith('Build succeeded in '),
      ]);

      // modify a file in the extension project
      await File(p.join(exampleExtensionDir, 'src', 'Foo.java'))
          .writeAsString(_fooJavaFileContents);

      // running the task again causes the extension to re-compile
      jbResult = await runJb(Directory(projectsDir),
          ['copyFile', '--no-color', '-p', p.basename(usesExtensionDir)]);
      expectSuccess(jbResult);
      expect(jbResult.stdout, isA<List<String>>());
      var lines = jbResult.stdout as List<String>;
      final loadingLineIndex = lines.indexed
              .where((e) => e.$2.endsWith(
                  '========= Loading jb extension project: ../example-extension ========='))
              .map((e) => e.$1)
              .firstOrNull ??
          fail('Could not find line for Loading extension');
      lines = lines.sublist(loadingLineIndex + 1);

      expect(lines.length, greaterThan(2));
      expect(lines[0], contains('Executing 1 task'));
      expect(lines[1], endsWith(" Running task 'compile'"));

      // change the inputs and make sure the task runs incrementally
      await File(p.join(usesExtensionDir, 'input-resources', 'new.txt'))
          .writeAsString('hello there');

      jbResult = await runJb(Directory(projectsDir),
          ['copyFile', '--no-color', '-p', p.basename(usesExtensionDir)]);
      expectSuccess(jbResult);

      expect(
          jbResult.stdout,
          contains(matches(RegExp(r'^copyFile:stdout \[jvm \d+]: '
              r'Copying 1 file\(s\) to output-resources directory$'))));
      await assertDirectoryContents(
          Directory(p.join(usesExtensionDir, 'output-resources')), [
        'hello.txt',
        'bye.txt',
        'new.txt',
      ]);
    }, timeout: const Timeout(Duration(seconds: 10)));

    test('can run custom task with config defined by extension project',
        () async {
      var jbResult = await runJb(
          Directory(usesExtensionDir), const ['copyFile', '--no-color']);
      expectSuccess(jbResult);
      expect(
          jbResult.stdout,
          contains(matches(RegExp(r'^copyFile:stdout \[jvm \d+]: '
              r'Copying 2 file\(s\) to output-resources directory$'))));
      await assertDirectoryContents(
          Directory(p.join(usesExtensionDir, 'output-resources')), [
        'hello.txt',
        'bye.txt',
      ]);
      expect(
          await File(p.join(usesExtensionDir, 'output-resources', 'hello.txt'))
              .readAsString(),
          equals('Hello'));
      expect(
          await File(p.join(usesExtensionDir, 'output-resources', 'bye.txt'))
              .readAsString(),
          equals('Bye'));

      // should not run again as the task output is cached
      jbResult = await runJb(
          Directory(usesExtensionDir), const ['copyFile', '--no-color']);
      expectSuccess(jbResult);
      expect(
          jbResult.stdout.where(
              (String line) => line.endsWith('to output-resources directory')),
          isEmpty);
      expect(jbResult.stdout, hasLength(greaterThan(2)));
      expect(lastItems(2, jbResult.stdout), [
        'Everything is up-to-date!',
        startsWith('Build succeeded in '),
      ]);

      // change the inputs and make sure the task runs incrementally
      await File(p.join(usesExtensionDir, 'input-resources', 'new.txt'))
          .writeAsString('hello there');

      jbResult = await runJb(
          Directory(usesExtensionDir), const ['copyFile', '--no-color']);
      expectSuccess(jbResult);

      expect(
          jbResult.stdout,
          contains(matches(RegExp(r'^copyFile:stdout \[jvm \d+]: '
              r'Copying 1 file\(s\) to output-resources directory$'))));
      await assertDirectoryContents(
          Directory(p.join(usesExtensionDir, 'output-resources')), [
        'hello.txt',
        'bye.txt',
        'new.txt',
      ]);

      await File(p.join(usesExtensionDir, 'input-resources', 'new.txt'))
          .delete();

      jbResult = await runJb(
          Directory(usesExtensionDir), const ['copyFile', '--no-color']);
      expectSuccess(jbResult);

      expect(
          jbResult.stdout,
          contains(matches(RegExp(r'^copyFile:stdout \[jvm \d+]: '
              r'Deleted new.txt$'))));
      await assertDirectoryContents(
          Directory(p.join(usesExtensionDir, 'output-resources')), [
        'hello.txt',
        'bye.txt',
      ]);

      // skip on Windows because the jar command fails due to the jar being
      // used by another process.
    }, timeout: const Timeout(Duration(seconds: 20)), testOn: '!windows');
  });

  projectGroup(runEnvProjectDir, 'Run with Env Var project', () {
    test('can run Java class that uses the environment', () async {
      var jbResult = await runJb(Directory(runEnvProjectDir), const ['run']);
      expectSuccess(jbResult);
      expect(jbResult.stdout.join('\n'), contains("MY_VAR is 'hello jbuild'"));
    }, timeout: const Timeout(Duration(seconds: 10)));
  });

  Future<void> cleanupEmptyProjectDir() async {
    await for (final entity in Directory(emptyProjectDir).list()) {
      if (entity.path.endsWith('.gitkeep')) continue;
      try {
        await entity.delete(recursive: true);
      } on PathAccessException catch (e) {
        print("cleanupEmptyProjectDir: UNABLE TO CLEANUP: $e");
      }
    }
  }

  projectGroup(emptyProjectDir, 'jb create', () {
    test('can create and run a jb project', () async {
      final jbProc = await startJb(
          Directory(emptyProjectDir), const ['create', '--no-color']);
      addTearDown(jbProc.kill);
      addTearDown(cleanupEmptyProjectDir);
      final out = jbProc.stdout.transform(utf8.decoder).asBroadcastStream();
      expect(await out.first, equals('Please enter a project group ID: '));
      jbProc.stdin.writeln('testing.foo');
      expect(
          await out.first, equals('\nEnter the artifact ID of this project: '));
      jbProc.stdin.writeln();
      expect(await out.first,
          equals('\nEnter the root package [testing.foo.my_app]: '));
      jbProc.stdin.writeln('testing.foo');
      expect(await out.first,
          equals('\nWould you like to create a test module [Y/n]? '));
      jbProc.stdin.writeln('n');
      expect(
          await out.first,
          equals('\nSelect a project type:\n'
              '  1. basic project.\n'
              '  2. jb extension.\n'
              'Choose [1]: '));
      jbProc.stdin.writeln();
      expect(await out.first, startsWith('\njb project created at '));
      expect(await jbProc.exitCode, isZero);

      await assertDirectoryContents(Directory(emptyProjectDir), [
        '.gitkeep',
        'jbuild.yaml',
        'src',
        p.join('src', 'testing'),
        p.join('src', 'testing', 'foo'),
        p.join('src', 'testing', 'foo', 'Main.java')
      ]);

      // ensure everything is valid by running a build
      final runResult = await runJb(Directory(emptyProjectDir), const ['run']);
      expectSuccess(runResult);
      expect(runResult.stdout.join('\n'), contains('Hello world!'));
    }, timeout: const Timeout(Duration(seconds: 15)));

    test('can create and test a jb project', () async {
      final jbProc = await startJb(
          Directory(emptyProjectDir),
          const ['create', '--no-color'],
          // freeze the assertj version so the tests work on Java 11 forever
          const {'ASSERTJ_VERSION': '3.27.3'});
      addTearDown(jbProc.kill);
      addTearDown(cleanupEmptyProjectDir);

      // group ID
      jbProc.stdin.writeln('testing.foo');
      // artifact ID
      jbProc.stdin.writeln();
      // root package
      jbProc.stdin.writeln('testing.foo');
      // test module?
      jbProc.stdin.writeln('y');
      // 1. basic, 2. jb-extension
      jbProc.stdin.writeln('1');
      // done
      expect(await jbProc.exitCode, isZero);

      // ensure everything is valid by running a build
      final runResult =
          await runJb(Directory(emptyProjectDir), const ['-p', 'test', 'test']);
      expectSuccess(runResult);
      final allOutput = runResult.stdout.join('\n');
      expect(allOutput, contains('Test run finished after '));
      expect(allOutput, contains(' 1 tests found '));
      expect(allOutput, contains(' 1 tests successful '));
    }, timeout: const Timeout(Duration(seconds: 15)));
  });
}
