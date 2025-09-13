import 'package:jb/src/compilation_path.g.dart';
import 'package:jb/src/compute_compilation_path.dart';
import 'package:test/test.dart';

void main() {
  test('can parse simple jar', () {
    final compilationPath = parseModules([
      'Jar junit-platform-console-standalone-1.9.1.jar is not a module.',
      '  JavaVersion: 17',
    ]);
    expect(
      compilationPath.jars,
      equals([
        Jar(
          javaVersion: '17',
          path: 'junit-platform-console-standalone-1.9.1.jar',
        ),
      ]),
    );
    expect(compilationPath.modules, isEmpty);
  });

  test('can parse Automatic-Module', () {
    final compilationPath = parseModules([
      'Jar build/compile-libs/commons-io-2.11.0.jar is an automatic module: org.apache.commons.io',
      '  JavaVersion: 8',
    ]);

    expect(
      compilationPath.modules,
      equals([
        Module(
          javaVersion: '8',
          path: 'build/compile-libs/commons-io-2.11.0.jar',
          name: 'org.apache.commons.io',
          version: '',
          flags: '',
          automatic: true,
          requires: const [],
        ),
      ]),
    );
    expect(compilationPath.jars, isEmpty);
  });

  test('can parse Java Module', () {
    final compilationPath = parseModules([
      'File ../libs/slf4j-simple-2.0.16.jar contains a Java module:',
      '  JavaVersion: 9',
      '  Name: org.slf4j.simple',
      '  Version: 2.0.16',
      '  Flags: none',
      '  Requires:',
      '    Module: java.base',
      '      Version:',
      '      Flags: mandated',
      '    Module: org.slf4j',
      '      Version: 2.0.16',
      '      Flags: none',
      '  Exports:',
      '    Package: org/slf4j/simple',
      '      Flags: none',
      '      ToModules:',
      '  Opens:',
      '    Package: org/slf4j/simple',
      '      Flags: none',
      '      ToModules: org.slf4j',
      '  Uses:',
      '    Provides:',
      '      Service: org/slf4j/spi/SLF4JServiceProvider',
      '      With: org/slf4j/simple/SimpleServiceProvider',
    ]);

    expect(
      compilationPath.modules,
      equals([
        Module(
          javaVersion: '9',
          path: '../libs/slf4j-simple-2.0.16.jar',
          name: 'org.slf4j.simple',
          version: '2.0.16',
          flags: 'none',
          automatic: false,
          requires: [
            Requirement(module: 'java.base', version: '', flags: 'mandated'),
            Requirement(module: 'org.slf4j', version: '2.0.16', flags: 'none'),
          ],
        ),
      ]),
    );
    expect(compilationPath.jars, isEmpty);
  });

  test('can parse all variations together', () {
    final compilationPath = parseModules([
      'Jar junit-platform-console-standalone-1.9.1.jar is not a module.',
      '  JavaVersion: 17',
      'Jar build/compile-libs/commons-io-2.11.0.jar is an automatic module: org.apache.commons.io',
      '  JavaVersion: 8',
      'File ../libs/slf4j-simple-2.0.16.jar contains a Java module:',
      '  JavaVersion: 9',
      '  Name: org.slf4j.simple',
      '  Version: 2.0.16',
      '  Flags: none',
      '  Requires:',
      '    Module: java.base',
      '      Version:',
      '      Flags: mandated',
      '    Module: org.slf4j',
      '      Version: 2.0.16',
      '      Flags: none',
      '  Exports:',
      'Jar my.jar is not a module.',
      '  JavaVersion: 1.5',
    ]);
    expect(
      compilationPath.jars,
      equals([
        Jar(
          javaVersion: '17',
          path: 'junit-platform-console-standalone-1.9.1.jar',
        ),
        Jar(javaVersion: '1.5', path: 'my.jar'),
      ]),
    );
    expect(
      compilationPath.modules,
      equals([
        Module(
          javaVersion: '8',
          path: 'build/compile-libs/commons-io-2.11.0.jar',
          name: 'org.apache.commons.io',
          version: '',
          flags: '',
          automatic: true,
          requires: const [],
        ),
        Module(
          javaVersion: '9',
          path: '../libs/slf4j-simple-2.0.16.jar',
          name: 'org.slf4j.simple',
          version: '2.0.16',
          flags: 'none',
          automatic: false,
          requires: [
            Requirement(module: 'java.base', version: '', flags: 'mandated'),
            Requirement(module: 'org.slf4j', version: '2.0.16', flags: 'none'),
          ],
        ),
      ]),
    );
  });
}
