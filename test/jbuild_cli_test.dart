import 'dart:io';

import 'package:dartle/dartle.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

const helloProjectDir = 'test/test-projects/hello';
const withDepsProjectDir = 'test/test-projects/with-deps';

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
    test('can install dependencies and compile project', () async {
      var exitCode = await exec(Process.start(jbuildExecutable, const [],
          workingDirectory: withDepsProjectDir));
      expect(exitCode, 0);
      expect(await File('$withDepsProjectDir/out/com/foo/Foo.class').exists(),
          isTrue);

      final output = <String>[];
      exitCode = await exec(
          Process.start(
              'java',
              [
                '-cp',
                classpath(['out', 'java-libs/*']),
                'com.foo.Foo',
              ],
              workingDirectory: withDepsProjectDir),
          onStdoutLine: output.add);
      expect(exitCode, 0);
      expect(output, equals(const ['[1, 2, 3]']));
    });
  });
}

void projectGroup(String projectDir, String name, Function() definition) {
  final outputDirs = dirs([
    '$projectDir/.jbuild-cache',
    '$projectDir/out',
    '$projectDir/java-libs',
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
