import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'test_helper.dart';

void main() {
  group('Incremental Compilation', () {
    test('can recompile only changed sources', () async {
      final rootDir = await createTempFiles({
        'jbuild.yaml': 'source-dirs: [source]\noutput-dir: build/classes',
        p.join('source', 'util', 'Util.java'): '''
        package util;
        public class Util {
          public static String greeting() { return "Hi"; }
        }
        ''',
        p.join('source', 'Main.java'): '''
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
        p.join('source', 'util', 'Util.java'): '''
        package util;
        public class Util {
          public static String greeting() { return MsgUtil.greeting(); }
        }
        ''',
        p.join('source', 'util', 'MsgUtil.java'): '''
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

    test('can delete class and resource from incremental compilation',
        () async {
      final rootDir = await createTempFiles({
        'jbuild.yaml': '''
          source-dirs: [source]
          resource-dirs: [res]
          output-dir: build/classes
        ''',
        p.join('res', 'greeting.txt'): 'Hej',
        p.join('source', 'util', 'Resources.java'): '''
        package util;
        import java.nio.charset.StandardCharsets;
        public class Resources {
          public static String read(String path) { 
            try (var stream = Util.class.getResourceAsStream(path)) {
              return new String(stream.readAllBytes(), StandardCharsets.UTF_8);
            } catch (java.io.IOException e) {
              throw new RuntimeException(e);
            }
          }
        }
        ''',
        p.join('source', 'util', 'Util.java'): '''
        package util;
        public class Util {
          public static String greeting() { 
            return Resources.read("/greeting.txt");
          }
        }
        ''',
        p.join('source', 'Main.java'): '''
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
        'greeting.txt',
        'Main.class',
        'util',
        p.join('util', 'Util.class'),
        p.join('util', 'Resources.class'),
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
      expect(javaResult.stdout, contains('Hej World'));

      // delete the Resources class and the resource, update Utils class
      await File(p.join(rootDir.path, 'source', 'util', 'Resources.java'))
          .delete();
      await File(p.join(rootDir.path, 'res', 'greeting.txt')).delete();
      await createFiles(rootDir, {
        p.join('source', 'util', 'Util.java'): '''
        package util;
        public class Util {
          public static String greeting() { return "Basic Hi"; }
        }
        '''
      });

      final jbResult2 = await runJb(rootDir);
      expectSuccess(jbResult2);

      await assertDirectoryContents(
          Directory(p.join(rootDir.path, 'build', 'classes')), [
        'Main.class',
        'util',
        p.join('util', 'Util.class'),
      ]);

      final javaResult2 =
          await runJava(rootDir, ['-cp', p.join('build', 'classes'), 'Main']);
      expectSuccess(javaResult2);
      expect(javaResult2.stdout, contains('Basic Hi World'));

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

    test('does not perform incremental compilation if output changes',
        () async {
      final rootDir = await createTempFiles({
        'jbuild.yaml': 'source-dirs: [source]\noutput-dir: build/classes',
        p.join('source', 'util', 'Util.java'): '''
        package util;
        public class Util {
          public static String greeting() { return "Hi"; }
        }
        ''',
        p.join('source', 'Main.java'): '''
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

      // change the output dir, which can cause an error if incremental
      // compilation kicked in.
      await File(p.join(rootDir.path, 'build', 'classes', 'util', 'Util.class'))
          .delete();

      final mainTimestamp =
          await File(p.join(rootDir.path, 'build', 'classes', 'Main.class'))
              .lastModified();

      final jbResult2 = await runJb(rootDir);
      expectSuccess(jbResult2);

      await assertDirectoryContents(
          Directory(p.join(rootDir.path, 'build', 'classes')), [
        'Main.class',
        'util',
        p.join('util', 'Util.class'),
      ]);

      final javaResult2 =
          await runJava(rootDir, ['-cp', p.join('build', 'classes'), 'Main']);
      expectSuccess(javaResult2);
      expect(javaResult2.stdout, contains('Hi World'));

      final mainTimestamp2 =
          await File(p.join(rootDir.path, 'build', 'classes', 'Main.class'))
              .lastModified();
      expect(mainTimestamp2.millisecondsSinceEpoch,
          greaterThan(mainTimestamp.millisecondsSinceEpoch));
    });
  });
}
