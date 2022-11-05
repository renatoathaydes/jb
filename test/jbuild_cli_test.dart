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
      final exitCode = await exec(Process.start(jbuildExecutable, const [],
          workingDirectory: helloProjectDir));
      expect(exitCode, 0);
      expect(await File('$helloProjectDir/out/Hello.class').exists(), isTrue);

      final output = <String>[];
      await exec(
          Process.start('java', const ['-cp', 'out', 'Hello'],
              workingDirectory: helloProjectDir),
          onStdoutLine: output.add);
      expect(output, equals(const ['Hi Dartle!']));
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
      var exitCode = await exec(Process.start(jbuildExecutable, const [],
          workingDirectory: withDepsProjectDir));
      expect(exitCode, 0);
      expect(await File('$withDepsProjectDir/with-deps.jar').exists(), isTrue);

      final output = <String>[];
      exitCode = await exec(
          Process.start(
              'java',
              [
                '-cp',
                classpath(['with-deps.jar', 'compile-libs/*']),
                'com.foo.Foo',
              ],
              workingDirectory: withDepsProjectDir),
          onStdoutLine: output.add);

      expect(exitCode, 0,
          reason: "should succeed:\n"
              "------------------\n"
              "${output.join('\n')}\n"
              "------------------");
      expect(output, equals(const ['[1, 2, 3]']));
    });
  });

  projectGroup(withSubProjectDir, 'with-sub-project project', () {
    tearDown(() async {
      await deleteAll(dirs(
          ['$withSubProjectDir/build', '$withSubProjectDir/.jbuild-cache'],
          includeHidden: true));
    });

    test('can install dependencies and compile project', () async {
      var exitCode = await exec(Process.start(jbuildExecutable, const [],
          workingDirectory: withSubProjectDir));
      expect(exitCode, 0);
      expect(await File('$withSubProjectDir/build/out/app/App.class').exists(),
          isTrue);
    });

    test('can run project', () async {
      final stdout = <String>[];
      final stderr = <String>[];
      var exitCode = await exec(
          Process.start(jbuildExecutable, const ['run'],
              workingDirectory: withSubProjectDir),
          onStdoutLine: stdout.add,
          onStderrLine: stderr.add);
      expect(exitCode, 0);
      expect(stdout, contains('Hello Mary!'));
      expect(stderr, isEmpty);
    });
  });

  projectGroup(testsProjectDir, 'tests project', () {
    test('can run Java tests using two levels of sub-projects', () async {
      final output = <String>[];
      final exitCode = await exec(
          Process.start(
              jbuildExecutable, const ['test', '-l', 'error', '--no-color'],
              workingDirectory: testsProjectDir),
          onStdoutLine: output.add);
      expect(exitCode, 0);
      expect(
          await File('$testsProjectDir/build/out/tests/AppTest.class').exists(),
          isTrue);
      expect(await File('$testsProjectDir/build/comp/greeting.jar').exists(),
          isTrue);
      expect(
          await File('$testsProjectDir/build/runtime/app/App.class').exists(),
          isTrue);
      expect(
          output.join('\n'),
          contains('├─ JUnit Jupiter ✔\n'
              '│  └─ AppTest ✔\n'
              '│     ├─ canGetNameFromArgs() ✔\n'
              '│     └─ canGetDefaultName() ✔\n'
              '├─ JUnit Vintage ✔\n'
              '└─ JUnit Platform Suite ✔\n'));
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
