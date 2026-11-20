import 'dart:io';

import 'package:dartle/dartle.dart' show DartleException;
import 'package:jb/src/crypto.dart' show computeSha1;
import 'package:jb/src/dependencies/checksums.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('jb-checksums-test');
  });

  tearDown(() async {
    await dir.delete(recursive: true);
  });

  Future<String> writeJar(String name, String contents) async {
    await File(p.join(dir.path, name)).writeAsString(contents);
    return computeSha1(p.join(dir.path, name));
  }

  group('verifyChecksums', () {
    test('succeeds when all jars match their checksums', () async {
      final listsSha = await writeJar('lists-1.0.jar', 'lists');
      final apiSha = await writeJar('slf4j-api-1.7.36.jar', 'api');

      await verifyChecksums(dir.path, {
        'com.example:lists:1.0': listsSha,
        'org.slf4j:slf4j-api:1.7.36': apiSha,
      }, 'dependencies.sum');
    });

    test('succeeds when the recorded checksum has surrounding space', () async {
      final sha = await writeJar('lists-1.0.jar', 'lists');

      await verifyChecksums(dir.path, {
        'com.example:lists:1.0': '$sha\r',
      }, 'dependencies.sum');
    });

    test('succeeds when a checksum has no jar in the directory', () async {
      // artifacts without a jar (e.g. POM-only) are not verified
      await verifyChecksums(dir.path, {
        'com.example:pom-only:1.0': '0' * 40,
      }, 'dependencies.sum');
    });

    test('succeeds with no checksums', () async {
      await verifyChecksums(dir.path, const {}, 'dependencies.sum');
    });

    test('fails when a jar does not match its checksum', () async {
      await writeJar('lists-1.0.jar', 'tampered');
      final expected = '0' * 40;

      await expectLater(
        verifyChecksums(dir.path, {
          'com.example:lists:1.0': expected,
        }, 'dependencies.sum'),
        throwsA(
          isA<DartleException>().having(
            (e) => e.message,
            'message',
            allOf(
              contains('Checksum mismatch for com.example:lists:1.0'),
              contains('expected $expected'),
              contains('**Delete the jar ${p.join(dir.path, 'lists-1.0.jar')}'),
              contains('remove its entry from dependencies.sum'),
            ),
          ),
        ),
      );
    });

    test('reports every mismatch, not only the first', () async {
      await writeJar('lists-1.0.jar', 'a');
      await writeJar('slf4j-api-1.7.36.jar', 'b');

      await expectLater(
        verifyChecksums(dir.path, {
          'com.example:lists:1.0': '1' * 40,
          'org.slf4j:slf4j-api:1.7.36': '2' * 40,
        }, 'dependencies.sum'),
        throwsA(
          isA<DartleException>().having(
            (e) => e.message,
            'message',
            allOf(
              contains('Checksum mismatch for com.example:lists:1.0'),
              contains('Checksum mismatch for org.slf4j:slf4j-api:1.7.36'),
            ),
          ),
        ),
      );
    });
  });
}
