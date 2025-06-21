import 'package:jb/jb.dart';
import 'package:jb/src/dependencies/parse.dart';
import 'package:test/expect.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('JBuildDepsCollector Tests', () {
    test('can parse dependency', () {
      final collector = JBuildDepsCollector();
      collector(
        'Dependencies of com.google.errorprone:error_prone_core:2.16 (incl. transitive) [{Apache-2.0}]:',
      );
      collector('  - scope runtime');
      collector('    * foo:bar:1.0 [compile] [{Apache-2.0}]');

      collector.done(emitRoot: false);

      expect(
        collector.results,
        equals([
          ResolvedDependency(
            artifact: 'foo:bar:1.0',
            spec: DependencySpec(scope: DependencyScope.runtimeOnly),
            sha1: '',
            kind: DependencyKind.maven,
            isDirect: false,
            dependencies: const [],
            licenses: [DependencyLicense(name: 'Apache-2.0', url: '')],
          ),
        ]),
      );
    });

    test('can parse dependency (include root)', () {
      final collector = JBuildDepsCollector();
      collector(
        'Dependencies of com.google.errorprone:error_prone_core:2.16 (incl. transitive) [{Apache-2.0}]:',
      );
      collector('  - scope runtime');
      collector('    * foo:bar:1.0 [compile] [{Apache-2.0}]');

      collector.done(emitRoot: true);

      expect(
        collector.results,
        equals([
          ResolvedDependency(
            artifact: "com.google.errorprone:error_prone_core:2.16",
            spec: DependencySpec(
              transitive: true,
              scope: DependencyScope.all,
              path: null,
              exclusions: [],
            ),
            sha1: "",
            licenses: [DependencyLicense(name: "Apache-2.0", url: "")],
            kind: DependencyKind.maven,
            isDirect: true,
            dependencies: ['foo:bar:1.0'],
          ),
          ResolvedDependency(
            artifact: 'foo:bar:1.0',
            spec: DependencySpec(scope: DependencyScope.runtimeOnly),
            sha1: '',
            kind: DependencyKind.maven,
            isDirect: false,
            dependencies: const [],
            licenses: [DependencyLicense(name: 'Apache-2.0', url: '')],
          ),
        ]),
      );
    });

    test('can parse repeated dependencies', () {
      final collector = JBuildDepsCollector();
      collector(
        'Dependencies of com.example:project (incl. transitive) [{Apache-2.0}]:',
      );
      collector('  - scope compile');
      collector('    * foo:bar:1.0 [compile] [{Apache-2.0}]');
      collector('        * bar:zort:2.0 [compile] [{MIT}]');
      collector('            * zort:bar:2.0 [compile] [{Eclipse-2.0}]');
      collector('    * bar:zort:2.0 [compile] (-)');

      collector.done(emitRoot: true);

      expect(
        collector.results,
        containsAll([
          ResolvedDependency(
            artifact: "com.example:project",
            spec: DependencySpec(),
            sha1: "",
            licenses: [DependencyLicense(name: "Apache-2.0", url: "")],
            kind: DependencyKind.maven,
            isDirect: true,
            dependencies: ['foo:bar:1.0', 'bar:zort:2.0'],
          ),
          ResolvedDependency(
            artifact: 'foo:bar:1.0',
            spec: DependencySpec(),
            sha1: '',
            kind: DependencyKind.maven,
            isDirect: false,
            dependencies: ['bar:zort:2.0'],
            licenses: [DependencyLicense(name: 'Apache-2.0', url: '')],
          ),
          ResolvedDependency(
            artifact: 'bar:zort:2.0',
            spec: DependencySpec(),
            sha1: '',
            kind: DependencyKind.maven,
            isDirect: false,
            dependencies: ['zort:bar:2.0'],
            licenses: [DependencyLicense(name: 'MIT', url: '')],
          ),
          ResolvedDependency(
            artifact: 'bar:zort:2.0',
            spec: DependencySpec(),
            sha1: '',
            kind: DependencyKind.maven,
            isDirect: false,
            dependencies: const [],
            // repeated dependency
            licenses: null,
          ),
          ResolvedDependency(
            artifact: 'zort:bar:2.0',
            spec: DependencySpec(),
            sha1: '',
            kind: DependencyKind.maven,
            isDirect: false,
            dependencies: const [],
            // repeated dependency
            licenses: [DependencyLicense(name: 'Eclipse-2.0', url: '')],
          ),
        ]),
      );
    });

    test('can parse multiple scopes and dependency missing license', () {
      final collector = JBuildDepsCollector();
      collector(
        'Dependencies of com.example:with-deps:1.2.3 (incl. transitive):',
      );
      collector('  - scope runtime');
      collector('    * foo:bar:1.0 [runtime]');
      collector('  - scope compile');
      collector('    * com.example:lists:1.0 [compile]');
      collector(
        '    * com.example:other:2.0 [compile] '
        '[{name=Eclipse Distribution License (New BSD License), url=<unspecified>}]',
      );
      collector('        * com.example:transitive:1.1 [compile]');

      collector.done(emitRoot: true);

      expect(
        collector.results,
        containsAll([
          ResolvedDependency(
            artifact: 'com.example:with-deps:1.2.3',
            spec: DependencySpec(),
            sha1: '',
            kind: DependencyKind.maven,
            isDirect: true,
            dependencies: [
              'foo:bar:1.0',
              'com.example:lists:1.0',
              'com.example:other:2.0',
            ],
            licenses: const [],
          ),
          ResolvedDependency(
            artifact: 'foo:bar:1.0',
            spec: DependencySpec(scope: DependencyScope.runtimeOnly),
            sha1: '',
            kind: DependencyKind.maven,
            isDirect: false,
            dependencies: const [],
            licenses: const [],
          ),
          ResolvedDependency(
            artifact: 'com.example:lists:1.0',
            spec: DependencySpec(),
            sha1: '',
            kind: DependencyKind.maven,
            isDirect: false,
            dependencies: const [],
            licenses: const [],
          ),
          ResolvedDependency(
            artifact: 'com.example:other:2.0',
            spec: DependencySpec(),
            sha1: '',
            kind: DependencyKind.maven,
            isDirect: false,
            dependencies: ['com.example:transitive:1.1'],
            licenses: [
              DependencyLicense(
                name: 'Eclipse Distribution License (New BSD License)',
                url: '<unspecified>',
              ),
            ],
          ),
          ResolvedDependency(
            artifact: 'com.example:transitive:1.1',
            spec: DependencySpec(),
            sha1: '',
            kind: DependencyKind.maven,
            isDirect: false,
            dependencies: const [],
            licenses: const [],
          ),
        ]),
      );
    });

    test('can parse dep with exclusions and license', () {
      final collector = JBuildDepsCollector();
      collector(
        'Dependencies of com.google.errorprone:error_prone_core:2.16 (incl. transitive) [{Apache-2.0}]:',
      );
      collector('  - scope runtime');
      collector(
        '    * org.eclipse.jgit:org.eclipse.jgit:4.4.1.201607150455-r '
        '[compile]:exclusions:[commons-codec:commons-codec, commons-logging:commons-logging, '
        'com.jcraft:jsch, com.googlecode.javaewah:JavaEWAH, org.apache.httpcomponents:httpclient, '
        'org.slf4j:slf4j-api] [{name=Eclipse Distribution License (New BSD License), url=<unspecified>}]',
      );

      collector.done(emitRoot: false);

      expect(
        collector.results,
        equals([
          ResolvedDependency(
            artifact: 'org.eclipse.jgit:org.eclipse.jgit:4.4.1.201607150455-r',
            spec: DependencySpec(
              scope: DependencyScope.runtimeOnly,
              exclusions: [
                'commons-codec:commons-codec',
                'commons-logging:commons-logging',
                'com.jcraft:jsch',
                'com.googlecode.javaewah:JavaEWAH',
                'org.apache.httpcomponents:httpclient',
                'org.slf4j:slf4j-api',
              ],
            ),
            sha1: '',
            kind: DependencyKind.maven,
            isDirect: false,
            dependencies: const [],
            licenses: [
              DependencyLicense(
                name: 'Eclipse Distribution License (New BSD License)',
                url: '<unspecified>',
              ),
            ],
          ),
        ]),
      );
    });
  });
}
