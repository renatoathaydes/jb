import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'test_helper.dart';

void main() {
  group('Incremental Compilation', () {
    test('can recompile only changed sources', () async {
      final rootDir = await createTempFiles({
        'jbuild.yaml': 'source-dirs: [src]\noutput-dir: build/classes',
        p.join('src', 'util', 'Util.java'): '''
        package util;
        public class Util {
          public static String greeting() { return "Hi"; }
        }
        ''',
        p.join('src', 'Main.java'): '''
        import util.Util;
        class Main {
          public static void main(String[] args) {
            System.out.println(Util.greeting() + " World");
          }
        }
        ''',
      });

      final jbResult = await runJb(rootDir);
      expectSuccess(jbResult);

      await assertDirectoryContents(
          Directory(p.join(rootDir.path, 'build', 'classes')), [
        'Main.class',
        'util',
        p.join('util', 'Util.class'),
      ]);

      final mainTimestamp =
          await File(p.join(rootDir.path, 'build', 'classes', 'Main.class'))
              .lastModified();
      final utilTimestamp = await File(
              p.join(rootDir.path, 'build', 'classes', 'util', 'Util.class'))
          .lastModified();

      final javaResult =
          await runJava(rootDir, ['-cp', p.join('build', 'classes'), 'Main']);
      expectSuccess(javaResult);
      expect(javaResult.stdout, contains('Hi World'));

      // change the Util class and delegate to a new class
      await createFiles(rootDir, {
        p.join('src', 'util', 'Util.java'): '''
        package util;
        public class Util {
          public static String greeting() { return MsgUtil.greeting(); }
        }
        ''',
        p.join('src', 'util', 'MsgUtil.java'): '''
        package util;
        public class MsgUtil {
          public static String greeting() { return "Hello"; }
        }
        ''',
      });

      final jbResult2 = await runJb(rootDir);
      expectSuccess(jbResult2);

      await assertDirectoryContents(
          Directory(p.join(rootDir.path, 'build', 'classes')), [
        'Main.class',
        'util',
        p.join('util', 'Util.class'),
        p.join('util', 'MsgUtil.class'),
      ]);

      final javaResult2 =
          await runJava(rootDir, ['-cp', p.join('build', 'classes'), 'Main']);
      expectSuccess(javaResult2);
      expect(javaResult2.stdout, contains('Hello World'));

      // check that Main was not re-compiled, but Util was
      final mainTimestamp2 =
          await File(p.join(rootDir.path, 'build', 'classes', 'Main.class'))
              .lastModified();
      final utilTimestamp2 = await File(
              p.join(rootDir.path, 'build', 'classes', 'util', 'Util.class'))
          .lastModified();

      expect(mainTimestamp2.millisecondsSinceEpoch,
          equals(mainTimestamp.millisecondsSinceEpoch));
      expect(utilTimestamp2.millisecondsSinceEpoch,
          greaterThan(utilTimestamp.millisecondsSinceEpoch));
    });
  });
}
