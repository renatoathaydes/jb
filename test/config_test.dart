import 'package:dartle/dartle.dart';
import 'package:jb/jb.dart';
import 'package:test/test.dart';

import 'config_matcher.dart';

void main() {
  group('JBuildConfiguration', () {
    test('can load', () {
      final config = JBuildConfiguration(
          version: '0',
          sourceDirs: {'src'},
          output: CompileOutput.jar('lib.jar'),
          resourceDirs: const {},
          mainClass: '',
          dependencies: const {},
          exclusions: const {},
          processorDependencies: const {},
          processorDependenciesExclusions: const {},
          repositories: const {},
          javacArgs: const [],
          runJavaArgs: const [],
          testJavaArgs: const [],
          javacEnv: const {},
          runJavaEnv: const {},
          testJavaEnv: const {},
          compileLibsDir: '',
          runtimeLibsDir: '',
          testReportsDir: '');

      expect(config.sourceDirs, equals(const {'src'}));
      expect(config.output.when(dir: (d) => 'dir', jar: (j) => j), 'lib.jar');
    });

    test('can parse full config', () async {
      final config = await loadConfigString('''
      properties:
        versions:
          guava: "1.2.3"
      group: my-group
      module: mod1
      version: '0.1'
      source-dirs:
        - src/main/groovy
        - src/test/kotlin
      dependencies:
        - com.google:guava:{{versions.guava}}
      exclusion-patterns:
        - test.*
        - .*other\\d+.*
      
      processor-dependencies:
        - foo.bar:zort:1.0
      processor-dependencies-exclusions:
        - others
      output-dir: target/
      resource-dirs:
        - src/resources
      
      compile-libs-dir: libs
      runtime-libs-dir: all-libs
      test-lib-dir: test-libs

      main-class: my.Main

      javac-args:
        - -Xmx2G
        - --verbose
      run-java-args: [ -Xmx1G ]
      test-java-args: [ -Xmx2G, -Xms512m ]
      javac-env:
        JAVAC: 1
      run-java-env:
        JAVA: 11
        CLASSPATH: foo
      test-java-env:
        TEST: true
      repositories:
        - https://maven.org
        - ftp://foo.bar
      ''');

      expect(
          config,
          equalsConfig(const JBuildConfiguration(
            group: 'my-group',
            module: 'mod1',
            version: '0.1',
            sourceDirs: {'src/main/groovy', 'src/test/kotlin'},
            output: CompileOutput.dir('target/'),
            resourceDirs: {'src/resources'},
            mainClass: 'my.Main',
            javacArgs: ['-Xmx2G', '--verbose'],
            runJavaArgs: ['-Xmx1G'],
            testJavaArgs: ['-Xmx2G', '-Xms512m'],
            javacEnv: {'JAVAC': '1'},
            runJavaEnv: {'JAVA': '11', 'CLASSPATH': 'foo'},
            testJavaEnv: {'TEST': 'true'},
            repositories: {'https://maven.org', 'ftp://foo.bar'},
            dependencies: {
              'com.google:guava:1.2.3': DependencySpec.defaultSpec,
            },
            processorDependencies: {'foo.bar:zort:1.0'},
            processorDependenciesExclusions: {'others'},
            exclusions: {'test.*', '.*other\\d+.*'},
            compileLibsDir: 'libs',
            runtimeLibsDir: 'all-libs',
            testReportsDir: 'build/test-reports',
            properties: {
              'versions': {'guava': '1.2.3'}
            },
          )));
    });

    test('can parse string-iterable from single string', () async {
      final config = await loadConfigString('''
      source-dirs: src/java
      exclusion-patterns: one  
      output-dir: out
      resource-dirs: resources
      javac-args: -X
      repositories: https://maven.org
      test-reports-dir: reports
      ''');

      expect(
          config,
          equalsConfig(const JBuildConfiguration(
              sourceDirs: {'src/java'},
              output: CompileOutput.dir('out'),
              resourceDirs: {'resources'},
              javacArgs: ['-X'],
              runJavaArgs: [],
              testJavaArgs: [],
              javacEnv: {},
              runJavaEnv: {},
              testJavaEnv: {},
              repositories: {'https://maven.org'},
              dependencies: {},
              processorDependencies: {},
              processorDependenciesExclusions: {},
              exclusions: {'one'},
              compileLibsDir: 'build/compile-libs',
              runtimeLibsDir: 'build/runtime-libs',
              testReportsDir: 'reports')));
    });

    test('can parse basic string dependencies', () async {
      final config = await loadConfigString('''
      dependencies:
        - foo
        - var
      ''');

      expect(
          config.dependencies,
          equals(const {
            'foo': DependencySpec.defaultSpec,
            'var': DependencySpec.defaultSpec,
          }));
    });

    test('can parse map dependencies', () async {
      final config = await loadConfigString('''
      dependencies:
        - foo:bar:1.0:
            transitive: false
            scope: runtime-only
        - second:dep:0.1
        - var:
      ''');

      expect(
          config.dependencies,
          equals(const {
            'foo:bar:1.0': DependencySpec(
                transitive: false, scope: DependencyScope.runtimeOnly),
            'second:dep:0.1': DependencySpec.defaultSpec,
            'var': DependencySpec.defaultSpec,
          }));
    });

    final config1 = JBuildConfiguration.fromMap(const {
      'group': 'g1',
      'module': 'm1',
      'version': 'v1',
      'main-class': 'm1',
      'source-dirs': ['source', 'src'],
      'output-jar': 'my.jar',
      'resource-dirs': ['rsrc'],
      'javac-args': ['-Xmx1G'],
      'run-java-args': ['-D'],
      'test-java-args': ['-T'],
      'javac-env': {'A': 'B'},
      'run-java-env': {'C': 'D'},
      'test-java-env': {'E': 'F'},
      'repositories': {'r1', 'r2'},
      'dependencies': [
        {
          'dep1': {'transitive': true}
        }
      ],
      'exclusions': {'e1'},
      'compile-libs-dir': 'comp',
      'runtime-libs-dir': 'runtime',
      'test-reports-dir': 'reports'
    });

    test('can merge two full configurations', () async {
      final config2 = JBuildConfiguration.fromMap(const {
        'group': 'g2',
        'module': 'm2',
        'version': 'v2',
        'main-class': 'm2',
        'source-dirs': ['source2'],
        'output-jar': 'my2.jar',
        'resource-dirs': ['rsrc2'],
        'javac-args': ['-Xmx2G'],
        'run-java-args': ['-E'],
        'test-java-args': ['-V'],
        'javac-env': {'P': 'Q'},
        'run-java-env': {'Q': 'R'},
        'test-java-env': {'S': 'T'},
        'repositories': {'r3', 'r4'},
        'dependencies': [
          {
            'dep2': {'transitive': false}
          }
        ],
        'exclusions': {'e2'},
        'compile-libs-dir': 'comp2',
        'runtime-libs-dir': 'runtime2',
        'test-reports-dir': 'reports2'
      });

      expect(
          config1.merge(config2),
          equalsConfig(JBuildConfiguration.fromMap(const {
            'group': 'g2',
            'module': 'm2',
            'version': 'v2',
            'main-class': 'm2',
            'source-dirs': ['source', 'src', 'source2'],
            'output-jar': 'my2.jar',
            'resource-dirs': ['rsrc', 'rsrc2'],
            'javac-args': ['-Xmx1G', '-Xmx2G'],
            'run-java-args': ['-D', '-E'],
            'test-java-args': ['-T', '-V'],
            'javac-env': {'A': 'B', 'P': 'Q'},
            'run-java-env': {'C': 'D', 'Q': 'R'},
            'test-java-env': {'E': 'F', 'S': 'T'},
            'repositories': {'r1', 'r2', 'r3', 'r4'},
            'dependencies': [
              {
                'dep1': {'transitive': true}
              },
              {
                'dep2': {'transitive': false}
              },
            ],
            'exclusions': {'e1', 'e2'},
            'compile-libs-dir': 'comp2',
            'runtime-libs-dir': 'runtime2',
            'test-reports-dir': 'reports2'
          })));

      expect(
          config2.merge(config1),
          equalsConfig(JBuildConfiguration.fromMap(const {
            'group': 'g1',
            'module': 'm1',
            'version': 'v1',
            'main-class': 'm1',
            'source-dirs': ['source2', 'src', 'source'],
            'output-jar': 'my.jar',
            'resource-dirs': ['rsrc2', 'rsrc'],
            'javac-args': ['-Xmx2G', '-Xmx1G'],
            'run-java-args': ['-E', '-D'],
            'test-java-args': ['-V', '-T'],
            'javac-env': {'P': 'Q', 'A': 'B'},
            'run-java-env': {'Q': 'R', 'C': 'D'},
            'test-java-env': {'S': 'T', 'E': 'F'},
            'repositories': {'r3', 'r4', 'r1', 'r2'},
            'dependencies': [
              {
                'dep1': {'transitive': true}
              },
              {
                'dep2': {'transitive': false}
              }
            ],
            'exclusions': {'e2', 'e1'},
            'compile-libs-dir': 'comp',
            'runtime-libs-dir': 'runtime',
            'test-reports-dir': 'reports'
          })));
    });

    test('can merge small config into full configuration', () {
      final smallConfig = JBuildConfiguration.fromMap({
        'module': 'small',
        'dependencies': [
          {
            'big': {'transitive': true}
          }
        ]
      });

      expect(
          config1.merge(smallConfig),
          equalsConfig(JBuildConfiguration.fromMap(const {
            'group': 'g1',
            'module': 'small',
            'version': 'v1',
            'main-class': 'm1',
            'source-dirs': ['source', 'src'],
            'output-jar': 'my.jar',
            'resource-dirs': ['rsrc'],
            'javac-args': ['-Xmx1G'],
            'run-java-args': ['-D'],
            'test-java-args': ['-T'],
            'javac-env': {'A': 'B'},
            'run-java-env': {'C': 'D'},
            'test-java-env': {'E': 'F'},
            'repositories': {'r1', 'r2'},
            'dependencies': [
              {
                'dep1': {'transitive': true}
              },
              {
                'big': {'transitive': true}
              }
            ],
            'exclusions': {'e1'},
            'compile-libs-dir': 'comp',
            'runtime-libs-dir': 'runtime',
            'test-reports-dir': 'reports'
          })));
    });

    test('can merge two small configurations using properties', () {
      final smallConfig1 = JBuildConfiguration.fromMap({
        'version': 'v1',
        'dependencies': [
          {
            '{{DEP}}': {'transitive': true}
          }
        ],
        'test-reports-dir': '{{REPORTS_DIR}}'
      }, const {
        'REPORTS_DIR': 'reports'
      });
      final smallConfig2 = JBuildConfiguration.fromMap({
        'module': 'small',
        'dependencies': [
          {
            'big2': {'transitive': false}
          }
        ]
      }, const {
        'DEP': 'big1'
      });

      expect(
          smallConfig1.merge(smallConfig2),
          equalsConfig(JBuildConfiguration.fromMap({
            'module': 'small',
            'version': 'v1',
            'dependencies': [
              {
                'big1': {'transitive': true}
              },
              {
                'big2': {'transitive': false}
              }
            ],
            'test-reports-dir': 'reports'
          }, {
            'DEP': 'big1',
            'REPORTS_DIR': 'reports'
          })));

      expect(
          smallConfig2.merge(smallConfig1),
          equalsConfig(JBuildConfiguration.fromMap({
            'module': 'small',
            'version': 'v1',
            'dependencies': [
              {
                'big1': {'transitive': true}
              },
              {
                'big2': {'transitive': false}
              }
            ],
            'test-reports-dir': 'reports'
          }, {
            'DEP': 'big1',
            'REPORTS_DIR': 'reports'
          })));
    });
  });

  group('Parsing Errors', () {
    test('cannot parse invalid config', () async {
      createConfig() => loadConfigString('''
      source-dirs: true
      ''');

      expect(
          createConfig,
          throwsA(isA<DartleException>().having(
              (e) => e.message,
              'message',
              equals("expecting a list of String values for 'source-dirs', "
                  "but got 'true'."))));
    });

    test('cannot parse invalid dependencies', () async {
      createConfig() => loadConfigString('''
      dependencies:
        foo:
          transitive: false
      ''');

      expect(
          createConfig,
          throwsA(isA<DartleException>().having(
              (e) => e.message,
              'message',
              equals("'dependencies' should be a List.\n"
                  "$dependenciesSyntaxHelp"))));
    });
  });
}
