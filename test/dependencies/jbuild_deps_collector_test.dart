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
  });
}
