import 'dart:io' show File;

import 'package:schemake/dart_gen.dart';
import 'package:schemake/schemake.dart';

const configFile = 'lib/src/jb_config.g.dart';

const _anyMap = Maps<String, Strings>('Map', valueType: Strings());

const _scm = Objects(
    'SourceControlManagement',
    {
      'connection': Property(Strings()),
      'developer-connection': Property(Strings()),
      'url': Property(Strings()),
    },
    description: 'Source control Management settings.');

const _developer = Objects(
    'Developer',
    {
      'name': Property(Strings()),
      'email': Property(Strings()),
      'organization': Property(Strings()),
      'organization-url': Property(Strings()),
    },
    description: 'Developers that have contributed to this project.');

String _enumComments(String name) => switch (name) {
      'all' =>
        '/// dependency is required both at compile-time and runtime.\n  ',
      'compile-only' =>
        '/// dependency is required at compile-time, but not runtime.\n  ',
      'runtime-only' =>
        '/// dependency is required at runtime, but not compile-time.\n  ',
      _ => throw StateError('unknown scope: "$name"'),
    };

const _scope = Enums(EnumValidator('DependencyScope', {
  'all',
  'compile-only',
  'runtime-only'
}, generatorOptions: [
  DartEnumGeneratorOptions(insertBeforeEnumVariant: _enumComments)
]));

const _dependency = Objects(
    'DependencySpec',
    {
      'transitive': Property(Bools(), defaultValue: true),
      'scope': Property(_scope,
          description: 'Scope of a dependency.', defaultValue: 'all'),
      'path': Property(Nullable(Strings())),
    },
    description: 'Specification of a dependency.');

const jbConfig = Objects(
    'JbConfiguration',
    {
      'group': Property(Nullable(Strings())),
      'module': Property(Nullable(Strings())),
      'name': Property(Nullable(Strings())),
      'version': Property(Nullable(Strings())),
      'description': Property(Nullable(Strings())),
      'url': Property(Nullable(Strings())),
      'main-class': Property(Nullable(Strings())),
      'extension-project': Property(Nullable(Strings())),
      'source-dirs': Property(Arrays(Strings()), defaultValue: []),
      'output-dir': Property(Nullable(Strings())),
      'output-jar': Property(Nullable(Strings())),
      'resource-dirs': Property(Arrays(Strings()), defaultValue: []),
      'repositories': Property(Arrays(Strings()), defaultValue: []),
      'dependencies': Property(
          Maps<Map<String, Object?>?, Nullable<Map<String, Object?>, Objects>>(
              'Map',
              valueType: Nullable(_dependency),
              description: 'Main dependencies of the project.'),
          defaultValue: <String, Object?>{}),
      'processor-dependencies': Property(
          Maps<Map<String, Object?>?, Nullable<Map<String, Object?>, Objects>>(
              'Map',
              valueType: Nullable(_dependency),
              description:
                  'Java annotation processor dependencies of the project.'),
          defaultValue: <String, Object?>{}),
      'dependency-exclusion-patterns':
          Property(Arrays(Strings()), defaultValue: []),
      'processor-dependency-exclusion-patterns':
          Property(Arrays(Strings()), defaultValue: []),
      'compile-libs-dir':
          Property(Strings(), defaultValue: 'build/compile-libs'),
      'runtime-libs-dir':
          Property(Strings(), defaultValue: 'build/runtime-libs'),
      'test-reports-dir':
          Property(Strings(), defaultValue: 'build/test-reports'),
      'javac-args': Property(Arrays(Strings()), defaultValue: []),
      'run-java-args': Property(Arrays(Strings()), defaultValue: []),
      'test-java-args': Property(Arrays(Strings()), defaultValue: []),
      'javac-env': Property(_anyMap, defaultValue: <String, Object?>{}),
      'run-java-env': Property(_anyMap, defaultValue: <String, Object?>{}),
      'test-java-env': Property(_anyMap, defaultValue: <String, Object?>{}),
      'scm': Property(Nullable(_scm)),
      'developers': Property(Arrays(_developer), defaultValue: []),
      'licenses': Property(Arrays(Strings()), defaultValue: []),
      'properties': Property(
          Objects('Map', {},
              unknownPropertiesStrategy: UnknownPropertiesStrategy.keep),
          defaultValue: <String, Object?>{})
    },
    unknownPropertiesStrategy: UnknownPropertiesStrategy.keep,
    description: 'jb configuration model.');

void main() async {
  final writer = File(configFile).openWrite();
  try {
    writer.write(generateDartClasses([jbConfig],
        options: const DartGeneratorOptions(methodGenerators: [
          ...DartGeneratorOptions.defaultMethodGenerators,
          DartToJsonMethodGenerator(),
          DartFromJsonMethodGenerator(),
        ])));
  } finally {
    await writer.flush();
    await writer.close();
  }
}
