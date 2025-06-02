import 'dart:io' show File;

import 'package:schemake/dart_gen.dart';
import 'package:schemake/schemake.dart';

import 'jb_extension_schema.dart';

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

const scope = Enums(EnumValidator('DependencyScope', {
  'all',
  'compile-only',
  'runtime-only'
}, generatorOptions: [
  DartEnumGeneratorOptions(insertBeforeEnumVariant: _enumComments)
]));

const dependency = Objects(
    'DependencySpec',
    {
      'transitive': Property(Bools(), defaultValue: true),
      'scope': Property(scope,
          description: 'Scope of a dependency.', defaultValue: 'all'),
      'path': Property(Nullable(Strings())),
      'exclusions': Property(Arrays(Strings()), defaultValue: []),
    },
    description: 'Specification of a dependency.');

const jbConfig = Objects(
    'JbConfiguration',
    {
      'group': Property(Nullable(Strings()),
          description: 'Name of the Maven group of this project'),
      'module': Property(Nullable(Strings()),
          description: 'Module name (Maven artifactId)'),
      'name': Property(Nullable(Strings()),
          description: 'Human readable name of this project'),
      'version':
          Property(Nullable(Strings()), description: 'Version of this project'),
      'description': Property(Nullable(Strings()),
          description: 'Description of this project'),
      'url': Property(Nullable(Strings()), description: 'Project URL'),
      'main-class': Property(Nullable(Strings()),
          description: 'Main Java class qualified name'),
      'manifest': Property(Nullable(Strings()),
          description: 'Manifest file to pass to the jar tool. '
              'Use "-" to generate no manifest'),
      'extension-project':
          Property(Nullable(Strings()), description: 'Path to a jb extension'),
      'source-dirs': Property(Arrays(Strings()),
          defaultValue: [], description: 'Java Source directories'),
      'output-dir': Property(Nullable(Strings()),
          description:
              'Class files output directory (mutual exclusive with output-jar)'),
      'output-jar': Property(Nullable(Strings()),
          description: 'Output jar path (mutual exclusive with output-dir)'),
      'resource-dirs': Property(Arrays(Strings()),
          defaultValue: [], description: 'Java Resource directories'),
      'repositories': Property(Arrays(Strings()),
          defaultValue: [],
          description: 'Maven repositories to use for obtaining dependencies'),
      'dependencies': Property(
          Maps<Map<String, Object?>?, Nullable<Map<String, Object?>, Objects>>(
              'Map',
              valueType: Nullable(dependency)),
          defaultValue: <String, Object?>{},
          description: 'Main dependencies of the project.'),
      'processor-dependencies': Property(
          Maps<Map<String, Object?>?, Nullable<Map<String, Object?>, Objects>>(
              'Map',
              valueType: Nullable(dependency)),
          defaultValue: <String, Object?>{},
          description:
              'Java annotation processor dependencies of the project.'),
      'dependency-exclusion-patterns': Property(Arrays(Strings()),
          defaultValue: [],
          description: 'Transitive dependencies exclusion patterns'),
      'processor-dependency-exclusion-patterns': Property(Arrays(Strings()),
          defaultValue: [],
          description:
              'Transitive annotation processor dependencies exclusion patterns'),
      'compile-libs-dir': Property(Strings(),
          defaultValue: 'build/compile-libs',
          description: 'Directory to save compile-time dependencies on'),
      'runtime-libs-dir': Property(Strings(),
          defaultValue: 'build/runtime-libs',
          description: 'Directory to save runtime-only dependencies on'),
      'test-reports-dir': Property(Strings(),
          defaultValue: 'build/test-reports',
          description: 'Directory to save test reports on'),
      'javac-args': Property(Arrays(Strings()),
          defaultValue: [],
          description:
              'Arguments to pass directly to "javac" when compiling Java code'),
      'run-java-args': Property(Arrays(Strings()),
          defaultValue: [],
          description:
              'Arguments to pass directly to "java" when running Java code'),
      'test-java-args': Property(Arrays(Strings()),
          defaultValue: [],
          description: 'Arguments to pass to the test runner'),
      'javac-env': Property(_anyMap,
          defaultValue: <String, Object?>{},
          description: 'Environment variables to use when running "javac"'),
      'run-java-env': Property(_anyMap,
          defaultValue: <String, Object?>{},
          description: 'Environment variables to use when running "java"'),
      'test-java-env': Property(_anyMap,
          defaultValue: <String, Object?>{},
          description: 'Environment variables to use when running tests'),
      'scm': Property(Nullable(_scm), description: 'Source Control Management'),
      'developers': Property(Arrays(_developer),
          defaultValue: [],
          description: 'List of developers contributing to this project'),
      'licenses': Property(Arrays(Strings()),
          defaultValue: [],
          description: 'List of licenses used by this project'),
      'properties': Property(
          Objects('Map', {},
              unknownPropertiesStrategy: UnknownPropertiesStrategy.keep),
          defaultValue: <String, Object?>{},
          description: 'Configuration properties '
              '(can be used in String interpolation on most config values)')
    },
    unknownPropertiesStrategy: UnknownPropertiesStrategy.keep,
    description: 'jb configuration model.');

void main() async {
  final writer = File(configFile).openWrite();
  try {
    writer.write(generateDartClasses([jbConfig, extensionTask],
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
