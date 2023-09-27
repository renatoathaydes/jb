import 'dart:io';

import 'package:jb/src/eclipse.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test('can write basic project Eclipse classpath file', () async {
    final tempDir = p.join(Directory.systemTemp.path, 'eclipse-test');
    await Directory(tempDir).create();
    final fooJar = await File(p.join(tempDir, 'foo.jar')).create();
    final barJar = await File(p.join(tempDir, 'bar.jar')).create();

    final cp = await generateClasspath(['src/main'], ['res'], tempDir);

    expect(cp.rootElement.name.local, equals('classpath'));
    expect(
        cp.rootElement.childElements
            .where((c) => c.name.local == 'classpathentry')
            .map((e) => Map.fromEntries(
                e.attributes.map((a) => MapEntry(a.name.local, a.value)))),
        unorderedEquals([
          {'kind': 'con', 'path': 'org.eclipse.jdt.launching.JRE_CONTAINER'},
          {'kind': 'src', 'path': 'src/main'},
          {'kind': 'src', 'path': 'res'},
          {'kind': 'lib', 'path': fooJar.path},
          {'kind': 'lib', 'path': barJar.path},
        ]));
  });
}
