import 'dart:io';

import 'package:dartle/dartle.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

const helloProjectDir = 'test/test-projects/hello';
const withDepsProjectDir = 'test/test-projects/with-deps';
const withSubProjectDir = 'test/test-projects/with-sub-project';
const testsProjectDir = 'test/test-projects/tests';

final jbuildExecutable = p.join(Directory.current.path, 'build', 'bin',
    Platform.isWindows ? 'jb.exe' : 'jb');

void main() {
  activateLogging(Level.FINE);

  projectGroup(helloProjectDir, 'hello project', () {
    test('can compile basic Java class and cache result', () async {
      final stdout = <String>[];
      final stderr = <String>[];
      final exitCode = await exec(
          Process.start(jbuildExecutable, const [],
              workingDirectory: helloProjectDir),
          onStdoutLine: stdout.add,
          onStderrLine: stderr.add);
      expectSuccess(exitCode, stdout, stderr);
      expect(await File('$helloProjectDir/out/Hello.class').exists(), isTrue);

      stdout.clear();
      stderr.clear();

      final exitCode2 = await exec(
          Process.start('java', const ['-cp', 'out', 'Hello'],
              workingDirectory: helloProjectDir),
          onStdoutLine: stdout.add,
          onStderrLine: stderr.add);
      expectSuccess(exitCode2, stdout, stderr);
      expect(stdout, equals(const ['Hi Dartle!']));
    });
  });

  projectGroup(withDepsProjectDir, 'with-deps project', () {
    tearDown(() async {
      await deleteAll(dirs([
        '$withDepsProjectDir/compile-libs',
        '$withDepsProjectDir/runtime-libs',
        '$withDepsProjectDir/.jbuild-cache'
      ], includeHidden: true));
      await deleteAll(file('$withDepsProjectDir/with-deps.jar'));
    });

    test('can install dependencies and compile project', () async {
      final stdout = <String>[];
      final stderr = <String>[];
      var exitCode = await exec(
          Process.start(jbuildExecutable, const [],
              workingDirectory: withDepsProjectDir),
          onStdoutLine: stdout.add,
          onStderrLine: stderr.add);
      expectSuccess(exitCode, stdout, stderr);
      expect(await File('$withDepsProjectDir/build/with-deps.jar').exists(),
          isTrue);
      stdout.clear();
      stderr.clear();
      exitCode = await exec(
          Process.start(
              'java',
              [
                '-cp',
                classpath(['build/with-deps.jar', 'build/compile-libs/*']),
                'com.foo.Foo',
              ],
              workingDirectory: withDepsProjectDir),
          onStdoutLine: stdout.add,
          onStderrLine: stderr.add);

      expectSuccess(exitCode, stdout, stderr);
      expect(stdout, equals(const ['[1, 2, 3]']));
    });
  });

  projectGroup(withSubProjectDir, 'with-sub-project project', () {
    tearDown(() async {
      await deleteAll(dirs(
          ['$withSubProjectDir/build', '$withSubProjectDir/.jbuild-cache'],
          includeHidden: true));
    });

    test('can install dependencies and compile project', () async {
      final stdout = <String>[];
      final stderr = <String>[];
      var exitCode = await exec(
          Process.start(jbuildExecutable, const [],
              workingDirectory: withSubProjectDir),
          onStdoutLine: stdout.add,
          onStderrLine: stderr.add);
      expectSuccess(exitCode, stdout, stderr);
      expect(await File('$withSubProjectDir/build/out/app/App.class').exists(),
          isTrue);
    });

    test('can run project', () async {
      final stdout = <String>[];
      final stderr = <String>[];
      var exitCode = await exec(
          Process.start(jbuildExecutable, const ['run', '--no-color'],
              workingDirectory: withSubProjectDir),
          onStdoutLine: stdout.add,
          onStderrLine: stderr.add);
      expectSuccess(exitCode, stdout, stderr);
      expect(stdout.join('\n'),
          contains(RegExp(r'runJavaMainClass \[java \d+\]: Hello Mary!')));
      expect(stderr, isEmpty);
    });
  });

  projectGroup(testsProjectDir, 'tests project', () {
    test('can run Java tests using two levels of sub-projects', () async {
      final stdout = <String>[];
      final stderr = <String>[];
      final exitCode = await exec(
          Process.start(jbuildExecutable, const ['test', '--no-color'],
              workingDirectory: testsProjectDir),
          onStdoutLine: stdout.add,
          onStderrLine: stderr.add);
      expectSuccess(exitCode, stdout, stderr);
      expect(
          await File('$testsProjectDir/build/out/tests/AppTest.class').exists(),
          isTrue);
      expect(await File('$testsProjectDir/build/comp/greeting.jar').exists(),
          isTrue);
      expect(
          await File('$testsProjectDir/build/runtime/app/App.class').exists(),
          isTrue);
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

      expect(stdout.join('\n'),
          anyOf(contains(unicodeResults), contains(asciiResults)));
    });
  });
}

void projectGroup(String projectDir, String name, Function() definition) {
  final outputDirs = dirs([
    '$projectDir/.jbuild-cache',
    '$projectDir/out',
    '$projectDir/compile-libs',
    '$projectDir/runtime-libs',
  ], includeHidden: true);

  setUp(() async {
    await deleteAll(outputDirs);
  });

  tearDownAll(() async {
    await deleteAll(outputDirs);
  });

  group(name, definition);
}

String classpath(Iterable<String> entries) {
  final separator = Platform.isWindows ? ';' : ':';
  return entries.join(separator);
}

void expectSuccess(int exitCode, List<String> stdout, List<String> stderr) {
  expect(exitCode, 0,
      reason: 'exit code was $exitCode.\n'
          '  => stdout:\n${stdout.join('\n')}\n'
          '  => stderr:\n${stderr.join('\n')}');
}
