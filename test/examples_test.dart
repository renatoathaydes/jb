import 'dart:io';

import 'package:dartle/dartle.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'test_helper.dart';

const errorProneProjectDir = 'example/error-prone-java-project';
const minimalProjectDir = 'example/minimal-java-project';

void main() {
  projectGroup(errorProneProjectDir, 'error-prone example', () {
    test('error prone plugin runs and finds problem with the code', () async {
      final jbResult =
          await runJb(Directory(errorProneProjectDir), const ['--no-color']);
      expectSuccess(jbResult, expectedExitCode: 1);
      expect(
          jbResult.stdout.toString(),
          allOf(
              contains(
                  'warning: [ConstantField] Fields with CONSTANT_CASE names '
                  'should be both static and final'),
              contains('static String HELLO = "Hello ErrorProne";')));
    });
  });

  projectGroup(minimalProjectDir, 'minimal example', () {
    test('can compile simple Java class into a jar', () async {
      final jbResult = await runJb(Directory(minimalProjectDir));
      expectSuccess(jbResult);
      final jarPath =
          p.join(minimalProjectDir, 'build', 'minimal-java-project.jar');
      expect(await File(jarPath).exists(), isTrue);

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
  });
}
