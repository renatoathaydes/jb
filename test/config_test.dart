import 'package:dartle/dartle.dart';
import 'package:jbuild_cli/jbuild_cli.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

void main() {
  group('CompileConfiguration', () {
    test('can load', () {
      final config = JBuildConfiguration(
          sourceDirs: {'src'},
          classpath: const {},
          output: CompileOutput.jar('lib.jar'),
          resourceDirs: const {},
          mainClass: '',
          dependencies: const {},
          exclusions: const {},
          repositories: const {},
          javacArgs: const [],
          compileLibsDir: '',
          runtimeLibsDir: '',
          testLibsDir: '');

      expect(config.sourceDirs, equals(const {'src'}));
      expect(config.output.when(dir: (d) => 'dir', jar: (j) => j), 'lib.jar');
    });

    test('can parse full config', () async {
      final config = configFromJson(loadYaml('''
      source-dirs:
        - src/main/groovy
        - src/test/kotlin
      dependencies:
        - com.google:guava:1.2.3
      exclusion-patterns:
        - test.*
        - .*other\\d+.*
      classpath: [foo, bar/*]
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
      repositories:
        - https://maven.org
        - ftp://foo.bar
      '''));

      expect(
          config,
          equals(const JBuildConfiguration(
              sourceDirs: {'src/main/groovy', 'src/test/kotlin'},
              classpath: {'foo', 'bar/*'},
              output: CompileOutput.dir('target/'),
              resourceDirs: {'src/resources'},
              mainClass: 'my.Main',
              javacArgs: ['-Xmx2G', '--verbose'],
              repositories: {'https://maven.org', 'ftp://foo.bar'},
              dependencies: {
                'com.google:guava:1.2.3': DependencySpec.defaultSpec,
              },
              exclusions: {'test.*', '.*other\\d+.*'},
              compileLibsDir: 'libs',
              runtimeLibsDir: 'all-libs',
              testLibsDir: 'test-libs')));
    });

    test('can parse string-iterable from single string', () async {
      final config = configFromJson(loadYaml('''
      source-dirs: src/java
      exclusion-patterns: one  
      classpath: the-classes
      output-dir: out
      resource-dirs: resources
      javac-args: -X
      repositories: https://maven.org
      '''));

      expect(
          config,
          equals(const JBuildConfiguration(
              sourceDirs: {'src/java'},
              classpath: {'the-classes'},
              output: CompileOutput.dir('out'),
              resourceDirs: {'resources'},
              mainClass: '',
              javacArgs: ['-X'],
              repositories: {'https://maven.org'},
              dependencies: {},
              exclusions: {'one'},
              compileLibsDir: 'compile-libs',
              runtimeLibsDir: 'runtime-libs',
              testLibsDir: 'test-libs')));
    });

    test('can parse basic string dependencies', () async {
      final config = configFromJson(loadYaml('''
      dependencies:
        - foo
        - var
      '''));

      expect(
          config.dependencies,
          equals(const {
            'foo': DependencySpec.defaultSpec,
            'var': DependencySpec.defaultSpec,
          }));
    });

    test('can parse map dependencies', () async {
      final config = configFromJson(loadYaml('''
      dependencies:
        - foo:bar:1.0:
            transitive: false
            scope: runtimeOnly
        - second:dep:0.1
        - var:
      '''));

      expect(
          config.dependencies,
          equals(const {
            'foo:bar:1.0': DependencySpec(
                transitive: false, scope: DependencyScope.runtimeOnly),
            'second:dep:0.1': DependencySpec.defaultSpec,
            'var': DependencySpec.defaultSpec,
          }));
    });
  });

  group('Parsing Errors', () {
    test('cannot parse invalid config', () async {
      createConfig() => configFromJson(loadYaml('''
      source-dirs: true
      '''));

      expect(
          createConfig,
          throwsA(isA<DartleException>().having(
              (e) => e.message,
              'message',
              equals("expecting a list of String values for 'source-dirs', "
                  "but got 'true'."))));
    });

    test('cannot parse invalid dependencies', () async {
      createConfig() => configFromJson(loadYaml('''
      dependencies:
        foo:
          transitive: false
      '''));

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
