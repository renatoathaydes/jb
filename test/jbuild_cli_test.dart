import 'dart:io';

import 'package:dartle/dartle.dart';
import 'package:logging/logging.dart';
import 'package:test/test.dart';

Future<File> jbExec = _compileJbExec();

Future<File> _compileJbExec() {
  return createDartExe(File('bin/jbuild_cli.dart'));
}

const _projectDir = 'test/test-projects/hello';

final _outputDirs = dirs(
    const ['$_projectDir/.jbuild-cache', '$_projectDir/out'],
    includeHidden: true);

void main() {
  activateLogging(Level.FINE);
  group('hello project', () {
    setUp(() async {
      await deleteAll(_outputDirs);
    });

    tearDownAll(() async {
      await deleteAll(_outputDirs);
    });

    test('can compile basic Java class and cache result', () async {
      final exe = await jbExec;
      final exitCode = await exec(
          runDartExe(exe, args: const [], workingDirectory: _projectDir));
      expect(exitCode, 0);
      expect(await File('$_projectDir/out/Hello.class').exists(), isTrue);

      final output = <String>[];
      await exec(
          Process.start('java', const ['-cp', 'out', 'Hello'],
              workingDirectory: _projectDir),
          onStdoutLine: output.add);
      expect(output, equals(const ['Hi Dartle!']));
    });
  });
}
