import 'package:dartle/dartle.dart';
import 'package:jb/jb.dart';
import 'package:test/test.dart';

import 'config_matcher.dart';

const _fullConfig = '''
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
    - foo.bar:zort:1.0:
        scope: runtime-only
        transitive: false
        path: foo/bar/zort
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
  ''';

const _fullConfigExpanded =
    '\x1B[90m######################## Full jb configuration ########################\n'
    '    \n'
    '### For more information, visit https://github.com/renatoathaydes/jb\n'
    '\x1B[0m\n'
    '\x1B[90m# Maven artifact groupId\x1B[0m\n'
    'group: \x1B[34m"my-group"\x1B[0m\n'
    '\x1B[90m# Maven artifactId\x1B[0m\n'
    'module: \x1B[34m"mod1"\x1B[0m\n'
    '\x1B[90m# Maven version\x1B[0m\n'
    'version: \x1B[34m"0.1"\x1B[0m\n'
    '\x1B[90m# List of source directories\x1B[0m\n'
    'source-dirs: [\x1B[34m"src/main/groovy"\x1B[0m, \x1B[34m"src/test/kotlin"\x1B[0m]\n'
    '\x1B[90m# List of resource directories (assets)\x1B[0m\n'
    'resource-dirs: [\x1B[34m"src/resources"\x1B[0m]\n'
    '\x1B[90m# Output directory (class files)\x1B[0m\n'
    'output-dir: \x1B[34m"target/"\x1B[0m\n'
    '\x1B[90m# Output jar (may be used instead of output-dir)\x1B[0m\n'
    'output-jar: \x1B[35mnull\x1B[0m\n'
    '\x1B[90m# Java Main class name\x1B[0m\n'
    'main-class: \x1B[34m"my.Main"\x1B[0m\n'
    '\x1B[90m# Java Compiler arguments\x1B[0m\n'
    'javac-args: [\x1B[34m"-Xmx2G"\x1B[0m, \x1B[34m"--verbose"\x1B[0m]\n'
    '\x1B[90m# Java runtime arguments\x1B[0m\n'
    'run-java-args: [\x1B[34m"-Xmx1G"\x1B[0m]\n'
    '\x1B[90m# Java test run arguments\x1B[0m\n'
    'test-java-args: [\x1B[34m"-Xmx2G"\x1B[0m, \x1B[34m"--verbose"\x1B[0m]\n'
    '\x1B[90m# Maven repositories (URLs or directories)\x1B[0m\n'
    'repositories: [\x1B[34m"https://maven.org"\x1B[0m, \x1B[34m"ftp://foo.bar"\x1B[0m]\n'
    '\x1B[90m# Maven dependencies\x1B[0m\n'
    'dependencies:\n'
    '  - \x1B[34m"com.google:guava:1.2.3"\x1B[0m:\n'
    '    transitive: true\n'
    '    scope: all\n'
    '    path: null\n'
    '\x1B[90m# Dependency exclusions (may use regex)\x1B[0m\n'
    'exclusions: [\x1B[34m"test.*"\x1B[0m, \x1B[34m".*other\\d+.*"\x1B[0m]\n'
    '\x1B[90m# Annotation processor Maven dependencies\x1B[0m\n'
    'processor-dependencies:\n'
    '  - \x1B[34m"foo.bar:zort:1.0"\x1B[0m:\n'
    '    transitive: false\n'
    '    scope: runtime-only\n'
    '    path: foo/bar/zort\n'
    '\x1B[90m# Annotation processor dependency exclusions (may use regex)\x1B[0m\n'
    'processor-dependencies-exclusions: [\x1B[34m"others"\x1B[0m]\n'
    '\x1B[90m# Compile-time libs output dir\x1B[0m\n'
    'compile-libs-dir: \x1B[34m"libs"\x1B[0m\n'
    '\x1B[90m# Runtime libs output dir\x1B[0m\n'
    'runtime-libs-dir: \x1B[34m"all-libs"\x1B[0m\n'
    '\x1B[90m# Test reports output dir\x1B[0m\n'
    'test-reports-dir: \x1B[34m"build/test-reports"\x1B[0m\n'
    '\x1B[90m# jb extension project path (for custom tasks)\x1B[0m\n'
    'extension-project: \x1B[35mnull\x1B[0m\n'
    '';

void main() {
  group('JBuildConfiguration', () {
    test('can load', () {
      final config = JbConfiguration(
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
      final config = await loadConfigString(_fullConfig);

      expect(
          config,
          equalsConfig(const JbConfiguration(
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
            processorDependencies: {
              'foo.bar:zort:1.0': DependencySpec(
                  transitive: true,
                  scope: DependencyScope.runtimeOnly,
                  path: 'foo/bar/zort'),
            },
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

    test('can print full config as YAML', () async {
      expect((await loadConfigString(_fullConfig)).toYaml(),
          equals(_fullConfigExpanded));
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
          equalsConfig(const JbConfiguration(
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

    final config1 = JbConfiguration.fromMap(const {
      'group': 'g1',
      'module': 'm1',
      'version': 'v1',
      'main-class': 'm1',
      'source-dirs': ['source', 'other-src'],
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
      final config2 = JbConfiguration.fromMap(const {
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
          equalsConfig(JbConfiguration.fromMap(const {
            'group': 'g2',
            'module': 'm2',
            'version': 'v2',
            'main-class': 'm2',
            'source-dirs': ['source', 'other-src', 'source2'],
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
          equalsConfig(JbConfiguration.fromMap(const {
            'group': 'g1',
            'module': 'm1',
            'version': 'v1',
            'main-class': 'm1',
            'source-dirs': ['source2', 'other-src', 'source'],
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

    test('can merge small config into full configuration and vice-versa', () {
      final smallConfig = JbConfiguration.fromMap({
        'module': 'small',
        'dependencies': [
          {
            'big': {'transitive': true}
          }
        ]
      });

      expect(
          config1.merge(smallConfig),
          equalsConfig(JbConfiguration.fromMap(const {
            'group': 'g1',
            'module': 'small',
            'version': 'v1',
            'main-class': 'm1',
            'source-dirs': ['source', 'other-src'],
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

      expect(
          smallConfig.merge(config1),
          equalsConfig(JbConfiguration.fromMap(const {
            'group': 'g1',
            'module': 'm1',
            'version': 'v1',
            'main-class': 'm1',
            'source-dirs': ['source', 'other-src'],
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
      final smallConfig1 = JbConfiguration.fromMap({
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
      final smallConfig2 = JbConfiguration.fromMap({
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
          equalsConfig(JbConfiguration.fromMap({
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
          equalsConfig(JbConfiguration.fromMap({
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
