import 'package:dartle/dartle.dart';
import 'package:io/ansi.dart';
import 'package:jb/jb.dart';
import 'package:test/test.dart';

import 'config_matcher.dart';

const _fullConfig = '''
  properties:
    versions:
      guava: "1.2.3"
  group: my-group
  module: mod1
  name: Module 1
  version: '0.1'
  description: A simple module
  url: https://my.mod
  licenses:
    - "0BSD"
  developers:
    - name: Joe
      email: joe
      organization: ACME
      organization-url: http://acme.org
  scm:
    connection: git
    developer-connection: git-dev
    url: github
  source-dirs:
    - src/main/groovy
    - src/test/kotlin
  dependencies:
    - com.google:guava:{{versions.guava}}
  dependency-exclusion-patterns:
    - test.*
    - .*other\\d+.*
  
  processor-dependencies:
    - foo.bar:zort:1.0:
        scope: runtime-only
        transitive: false
        path: foo/bar/zort
  processor-dependency-exclusion-patterns:
    - others
  output-dir: target/
  resource-dirs:
    - src/resources
  
  compile-libs-dir: libs
  runtime-libs-dir: all-libs
  test-reports-dir: reports-dir

  main-class: my.Main

  javac-args:
    - -Xmx2G
    - --verbose
  javac-env:
    CLASSPATH: foo
  run-java-args: [ -Xmx1G ]
  run-java-env:
    HELLO: hi
    FOO: bar
  test-java-args: [ -Xmx2G, -Xms512m ]
  test-java-env:
    TESTING: 'true'
  repositories:
    - https://maven.org
    - ftp://foo.bar
  ''';

const _fullConfigExpanded = '''
\x1B[90m######################## Full jb configuration ########################

### For more information, visit https://github.com/renatoathaydes/jb
\x1B[0m
\x1B[90m# Maven artifact groupId\x1B[0m
group: \x1B[34m"my-group"\x1B[0m
\x1B[90m# Maven artifactId\x1B[0m
module: \x1B[34m"mod1"\x1B[0m
\x1B[90m# Maven version\x1B[0m
version: \x1B[34m"0.1"\x1B[0m
\x1B[90m# Project name\x1B[0m
name: \x1B[34m"Module 1"\x1B[0m
\x1B[90m# Description for this project\x1B[0m
description: \x1B[34m"A simple module"\x1B[0m
\x1B[90m# URL of this project\x1B[0m
url: \x1B[34m"https://my.mod"\x1B[0m
\x1B[90m# Licenses this project uses\x1B[0m
licenses: [\x1B[34m"0BSD"\x1B[0m]
\x1B[90m# Developers who have contributed to this project\x1B[0m
developers:
  - name: \x1B[34m"Joe"\x1B[0m
    email: \x1B[34m"joe"\x1B[0m
    organization: \x1B[34m"ACME"\x1B[0m
    organization-url: \x1B[34m"http://acme.org"\x1B[0m
\x1B[90m# Source control management\x1B[0m
scm:
  connection: \x1B[34m"git"\x1B[0m
  developer-connection: \x1B[34m"git-dev"\x1B[0m
  url: \x1B[34m"github"\x1B[0m
\x1B[90m# List of source directories\x1B[0m
source-dirs: [\x1B[34m"src/main/groovy"\x1B[0m, \x1B[34m"src/test/kotlin"\x1B[0m]
\x1B[90m# List of resource directories (assets)\x1B[0m
resource-dirs: [\x1B[34m"src/resources"\x1B[0m]
\x1B[90m# Output directory (class files)\x1B[0m
output-dir: \x1B[34m"target/"\x1B[0m
\x1B[90m# Output jar (may be used instead of output-dir)\x1B[0m
output-jar: \x1B[35mnull\x1B[0m
\x1B[90m# Java Main class name\x1B[0m
main-class: \x1B[34m"my.Main"\x1B[0m
\x1B[90m# Java Compiler arguments\x1B[0m
javac-args: [\x1B[34m"-Xmx2G"\x1B[0m, \x1B[34m"--verbose"\x1B[0m]
\x1B[90m# Java Compiler environment variables\x1B[0m
javac-env:
  \x1B[34m"CLASSPATH"\x1B[0m: \x1B[34m"foo"\x1B[0m
\x1B[90m# Java Runtime arguments\x1B[0m
run-java-args: [\x1B[34m"-Xmx1G"\x1B[0m]
\x1B[90m# Java Runtime environment variables\x1B[0m
run-java-env:
  \x1B[34m"HELLO"\x1B[0m: \x1B[34m"hi"\x1B[0m
  \x1B[34m"FOO"\x1B[0m: \x1B[34m"bar"\x1B[0m
\x1B[90m# Java Test run arguments\x1B[0m
test-java-args: [\x1B[34m"-Xmx2G"\x1B[0m, \x1B[34m"--verbose"\x1B[0m]
\x1B[90m# Java Test environment variables\x1B[0m
test-java-env:
  \x1B[34m"TESTING"\x1B[0m: \x1B[34m"true"\x1B[0m
\x1B[90m# Maven repositories (URLs or directories)\x1B[0m
repositories: [\x1B[34m"https://maven.org"\x1B[0m, \x1B[34m"ftp://foo.bar"\x1B[0m]
\x1B[90m# Maven dependencies\x1B[0m
dependencies:
  - \x1B[34m"com.google:guava:1.2.3"\x1B[0m:
    transitive: \x1B[35mtrue\x1B[0m
    scope: \x1B[34m"all"\x1B[0m
    path: \x1B[35mnull\x1B[0m
\x1B[90m# Dependency exclusions (regular expressions)\x1B[0m
dependency-exclusion-patterns:
  - \x1B[34m"test.*"\x1B[0m
  - \x1B[34m".*other\\d+.*"\x1B[0m
\x1B[90m# Annotation processor Maven dependencies\x1B[0m
processor-dependencies:
  - \x1B[34m"foo.bar:zort:1.0"\x1B[0m:
    transitive: \x1B[35mfalse\x1B[0m
    scope: \x1B[34m"runtime-only"\x1B[0m
    path: \x1B[34m"foo/bar/zort"\x1B[0m
\x1B[90m# Annotation processor dependency exclusions (regular expressions)\x1B[0m
processor-dependency-exclusion-patterns:
  - \x1B[34m"others"\x1B[0m
\x1B[90m# Compile-time libs output dir\x1B[0m
compile-libs-dir: \x1B[34m"libs"\x1B[0m
\x1B[90m# Runtime libs output dir\x1B[0m
runtime-libs-dir: \x1B[34m"all-libs"\x1B[0m
\x1B[90m# Test reports output dir\x1B[0m
test-reports-dir: \x1B[34m"reports-dir"\x1B[0m
\x1B[90m# jb extension project path (for custom tasks)\x1B[0m
extension-project: \x1B[35mnull\x1B[0m
''';

const _basicConfigWithDependencies = '''
module: basic
output-jar: "my.jar"
dependencies:
 - foo:bar:zort:1.0
 - other-dep:
     path: "../"
 - more-dep:1.0:
     scope: runtime-only
     transitive: false
''';

const _basicConfigWithDependenciesExpanded = '''
######################## Full jb configuration ########################

### For more information, visit https://github.com/renatoathaydes/jb

# Maven artifact groupId
group: null
# Maven artifactId
module: "basic"
# Maven version
version: null
# Project name
name: null
# Description for this project
description: null
# URL of this project
url: null
# Licenses this project uses
licenses: []
# Developers who have contributed to this project
developers: []
# Source control management
scm: null
# List of source directories
source-dirs: ["src"]
# List of resource directories (assets)
resource-dirs: ["resources"]
# Output directory (class files)
output-dir: null
# Output jar (may be used instead of output-dir)
output-jar: "my.jar"
# Java Main class name
main-class: null
# Java Compiler arguments
javac-args: []
# Java Compiler environment variables
javac-env: {}
# Java Runtime arguments
run-java-args: []
# Java Runtime environment variables
run-java-env: {}
# Java Test run arguments
test-java-args: []
# Java Test environment variables
test-java-env: {}
# Maven repositories (URLs or directories)
repositories: []
# Maven dependencies
dependencies:
  - "foo:bar:zort:1.0":
    transitive: true
    scope: "all"
    path: null
  - "other-dep":
    transitive: true
    scope: "all"
    path: ".."
  - "more-dep:1.0":
    transitive: false
    scope: "runtime-only"
    path: null
# Dependency exclusions (regular expressions)
dependency-exclusion-patterns: []
# Annotation processor Maven dependencies
processor-dependencies: []
# Annotation processor dependency exclusions (regular expressions)
processor-dependency-exclusion-patterns: []
# Compile-time libs output dir
compile-libs-dir: "build/compile-libs"
# Runtime libs output dir
runtime-libs-dir: "build/runtime-libs"
# Test reports output dir
test-reports-dir: "build/test-reports"
# jb extension project path (for custom tasks)
extension-project: null
''';

void main() {
  group('JBuildConfiguration', () {
    test('can load', () async {
      final config = await loadConfigString('''
      output-jar: lib.jar
      ''');

      expect(config.sourceDirs, equals(const {'src'}));
      expect(config.output.when(dir: (d) => 'dir', jar: (j) => j), 'lib.jar');
    });

    test('can parse full config', () async {
      final config = await loadConfigString(_fullConfig);

      expect(
          config,
          equalsConfig(JbConfiguration(
            group: 'my-group',
            module: 'mod1',
            version: '0.1',
            description: 'A simple module',
            url: 'https://my.mod',
            licenses: [allLicenses['0BSD']!],
            developers: [
              Developer(
                name: 'Joe',
                email: 'joe',
                organization: 'ACME',
                organizationUrl: 'http://acme.org',
              )
            ],
            scm: SourceControlManagement(
              connection: 'git',
              developerConnection: 'git-dev',
              url: 'github',
            ),
            sourceDirs: {'src/main/groovy', 'src/test/kotlin'},
            output: CompileOutput.dir('target/'),
            resourceDirs: {'src/resources'},
            mainClass: 'my.Main',
            javacArgs: ['-Xmx2G', '--verbose'],
            runJavaArgs: ['-Xmx1G'],
            testJavaArgs: ['-Xmx2G', '-Xms512m'],
            javacEnv: {'CLASSPATH': 'foo'},
            runJavaEnv: {'HELLO': 'hi', 'FOO': 'bar'},
            testJavaEnv: {'TESTING': 'true'},
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
            processorDependencyExclusionPatterns: {'others'},
            dependencyExclusionPatterns: {'test.*', '.*other\\d+.*'},
            compileLibsDir: 'libs',
            runtimeLibsDir: 'all-libs',
            testReportsDir: 'reports-dir',
            properties: {
              'versions': {'guava': '1.2.3'}
            },
          )));
    });

    test('can print full config as YAML', () async {
      final config = await loadConfigString(_fullConfig);
      expect(overrideAnsiOutput(true, () => config.toYaml(false)),
          equals(_fullConfigExpanded));
    });

    test('can print basic config with dependencies as YAML', () async {
      expect(
          (await loadConfigString(_basicConfigWithDependencies)).toYaml(true),
          equals(_basicConfigWithDependenciesExpanded));
    });

    test('can parse string-iterable from single string', () async {
      final config = await loadConfigString('''
      source-dirs: src/java
      dependency-exclusion-patterns: one  
      output-dir: out
      resource-dirs: resources
      javac-args: -X
      repositories: https://maven.org
      test-reports-dir: reports
      ''');

      expect(
          config,
          equalsConfig(const JbConfiguration(
              licenses: [],
              developers: [],
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
              processorDependencyExclusionPatterns: {},
              dependencyExclusionPatterns: {'one'},
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
      'dependency-exclusion-patterns': {'e1'},
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
        'dependency-exclusion-patterns': {'e2'},
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
            'dependency-exclusion-patterns': {'e1', 'e2'},
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
            'dependency-exclusion-patterns': {'e2', 'e1'},
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
            'dependency-exclusion-patterns': {'e1'},
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
            'dependency-exclusion-patterns': {'e1'},
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

    test('invalid keys are not allowed on top config', () async {
      createConfig() => loadConfigString('''
      module: foo
      version: 1.0
      custom: true
      ''');

      expect(
          createConfig,
          throwsA(isA<DartleException>().having(
              (e) => e.message,
              'message',
              equals('Invalid jbuild configuration: '
                  'unrecognized field: "custom"'))));
    });

    test('invalid keys are not allowed in dependency', () async {
      createConfig() => loadConfigString('''
      module: foo
      dependencies:
        - foo:
          transitive: false
          checked: true
      ''');

      expect(
          createConfig,
          throwsA(isA<DartleException>().having((e) => e.message, 'message',
              startsWith('bad dependency declaration:'))));
    });

    test('invalid keys are not allowed in scm', () async {
      createConfig() => loadConfigString('''
      module: foo
      scm:
        connection: foo
        developer: me
      ''');

      expect(
          createConfig,
          throwsA(isA<DartleException>().having(
              (e) => e.message,
              'message',
              startsWith('invalid "scm" definition, only '
                  '"connection", "developer-connection" and "url" '
                  'fields can be set:'))));
    });

    test('invalid keys are not allowed in developer', () async {
      createConfig() => loadConfigString('''
      module: foo
      developers:
        - name: Renato
          email: a@b.com
          surname: Athaydes
      ''');

      expect(
          createConfig,
          throwsA(isA<DartleException>().having(
              (e) => e.message,
              'message',
              startsWith('invalid "developer" definition, only "name", '
                  '"email", "organization" and "organization-url" '
                  'fields can be set:'))));
    });

    test('duplicate keys are not allowed', () async {
      createConfig() => loadConfigString('''
      module: foo
      version: 1.0
      module: foo
      ''');

      expect(
          createConfig,
          throwsA(isA<DartleException>().having(
              (e) => e.message,
              'message',
              startsWith('Invalid jbuild configuration: parsing error: '
                  'Error on line 3, column 7: Duplicate mapping key.'))));
    });
  });
}
