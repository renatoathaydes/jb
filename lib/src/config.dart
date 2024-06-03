import 'dart:io';

import 'package:collection/collection.dart';
import 'package:conveniently/conveniently.dart';
import 'package:dartle/dartle.dart' show failBuild, DartleException, TaskPhase;
import 'package:dartle/dartle_cache.dart' show ChangeKind;
import 'package:logging/logging.dart' as log;
import 'package:path/path.dart' as p;
import 'package:schemake/schemake.dart';
import 'package:yaml/yaml.dart';

import 'ansi.dart';
import 'config_import.dart';
import 'file_tree.dart';
import 'jb_config.g.dart';
import 'licenses.g.dart';
import 'maven_metadata.dart';
import 'path_dependency.dart';
import 'properties.dart';
import 'utils.dart';

export 'jb_config.g.dart';

final logger = log.Logger('jb');

const yamlJbFile = 'jbuild.yaml';
const jsonJbFile = 'jbuild.json';

const jbuild = 'com.athaydes.jbuild:jbuild';
const jbApi = 'com.athaydes.jbuild:jbuild-api';

/// Parse the YAML/JSON jbuild file.
///
/// Applies defaults and resolves properties and imports.
Future<JbConfiguration> loadConfig(File configFile) async {
  logger.fine(() => 'Reading config file: ${configFile.path}');
  String configString;
  try {
    configString = await configFile.readAsString();
  } on PathNotFoundException {
    throw DartleException(
        message: 'jb config file not found.\n'
            "To create one, run 'jb create'.\n"
            "Run 'jb --help' to see usage.");
  }
  return await loadConfigString(configString);
}

/// Parse the YAML/JSON jb configuration.
///
/// Applies defaults and resolves properties and imports.
Future<JbConfiguration> loadConfigString(String config) async {
  final dynamic json;
  try {
    json = loadYaml(config);
  } catch (e) {
    throw DartleException(
        message: 'Invalid jbuild configuration: '
            'parsing error: $e');
  }
  if (json is Map) {
    final resolvedMap = resolvePropertiesFromMap(json);
    final imports = resolvedMap.map.remove('imports');
    try {
      return await JbConfiguration.fromJson(resolvedMap.map)
          .applyImports(imports);
    } on PropertyTypeException catch (e) {
      final help = _helpForProperty(e.propertyPath);
      if (help.isEmpty) {
        throw DartleException(
            message: 'Invalid jb configuration: '
                "at '${e.propertyPath.join('/')}': ${e.message}");
      }
      throw DartleException(
          message: 'Invalid jb configuration: '
              "at '${e.propertyPath.join('/')}': invalid syntax.\n$help");
    } on UnknownPropertyException catch (e) {
      final help = _helpForProperty(e.propertyPath);
      throw DartleException(
          message: 'Invalid jb configuration: '
              "at '${e.propertyPath.join('/')}': property does not exist."
              "${help.isEmpty ? '' : '\n$help'}");
    } on MissingPropertyException catch (e) {
      final help = _helpForProperty(e.propertyPath);
      throw DartleException(
          message: 'Invalid jb configuration: '
              "at '${e.propertyPath.join('/')}': mandatory property is missing."
              "${help.isEmpty ? '' : '\n$help'}");
    }
  } else {
    throw DartleException(
        message: 'Expecting jb configuration to be a Map, '
            'but it is ${json?.runtimeType}');
  }
}

String _helpForProperty(List<String> propertyPath) {
  if (propertyPath.isEmpty) return '';
  final property = propertyPath.first;
  if (property == 'dependencies' || property == 'processor-dependencies') {
    return dependenciesSyntaxHelp;
  }
  if (propertyPath.first == 'scm') {
    return scmSyntaxHelp;
  }
  if (propertyPath.first == 'developers') {
    return developerSyntaxHelp;
  }
  return '';
}

/// Parse the YAML/JSON jb extension model.
///
/// Applies defaults and resolves properties and imports.
Future<List<ExtensionTaskConfig>> loadExtensionTaskConfigs(
    JbConfiguration jbConfig, String config, Uri yamlUri) async {
  final json = loadYaml(config, sourceUrl: yamlUri);
  if (json is Map) {
    final resolvedMap = resolvePropertiesFromMap(json);
    return _extensionTasks(resolvedMap.map);
  } else {
    throw DartleException(
        message: '$yamlUri: Expecting jb extension to be a Map, '
            'but it is ${json?.runtimeType}');
  }
}

class _Value<T> {
  final bool isDefault;
  final T value;

  const _Value(this.isDefault, this.value);
}

typedef NullableInt = int?;

/// The jb configuration value's types.
enum ConfigType {
  string,
  boolean,
  int,
  float,
  listOfStrings,
  arrayOfStrings,
  jbuildLogger,
  jbConfig,
  ;

  static ConfigType from(String value) => switch (value) {
        'STRING' => ConfigType.string,
        'BOOLEAN' => ConfigType.boolean,
        'INT' => ConfigType.int,
        'FLOAT' => ConfigType.float,
        'LIST_OF_STRINGS' => ConfigType.listOfStrings,
        'ARRAY_OF_STRINGS' => ConfigType.arrayOfStrings,
        'JBUILD_LOGGER' => ConfigType.jbuildLogger,
        'JB_CONFIG' => ConfigType.jbConfig,
        _ => failBuild(reason: 'Unsupported Java type: $value'),
      };

  bool isInstance(Object? object) => switch (this) {
        ConfigType.string => object is String?,
        ConfigType.boolean => object is bool?,
        ConfigType.int => object is NullableInt,
        ConfigType.float => object is double?,
        ConfigType.listOfStrings ||
        ConfigType.arrayOfStrings =>
          object is List<String>,
        ConfigType.jbuildLogger || ConfigType.jbConfig => false,
      };

  bool mayBeConfigured() => switch (this) {
        ConfigType.jbuildLogger || ConfigType.jbConfig => false,
        _ => true,
      };

  @override
  String toString() => switch (this) {
        string => 'String',
        boolean => 'boolean',
        int => 'int',
        float => 'float',
        listOfStrings => 'List<String>',
        arrayOfStrings => 'String[]',
        jbuildLogger => 'jbuild.api.JBuildLogger',
        jbConfig => 'jbuild.api.config.JbConfig',
      };
}

/// Java constructor representation.
typedef JavaConstructor = Map<String, ConfigType>;

/// Basic definitions of a jb extension task configuration.
///
/// Includes only the parts of [ExtensionTask] which do not require
/// instantiating the Java extension class.
typedef ExtensionTaskConfig = ({
  String name,
  String description,
  TaskPhase phase,
  String className,
  String methodName,
  List<JavaConstructor> constructors,
});

/// Definition of a jb extension task.
class ExtensionTask {
  final String name;
  final String description;
  final TaskPhase phase;
  final Set<String> inputs;
  final Set<String> outputs;
  final Set<String> dependsOn;
  final Set<String> dependents;
  final String className;
  final String methodName;
  final List<JavaConstructor> constructors;
  final List<Object?> constructorData;

  const ExtensionTask({
    required this.name,
    required this.description,
    required this.phase,
    required this.inputs,
    required this.outputs,
    required this.dependsOn,
    required this.className,
    required this.methodName,
    required this.dependents,
    required this.constructors,
    required this.constructorData,
  });

  factory ExtensionTask.from(
    ExtensionTaskConfig config, {
    required Set<String> inputs,
    required Set<String> outputs,
    required Set<String> dependsOn,
    required Set<String> dependents,
    required List<Object?> constructorData,
  }) {
    return ExtensionTask(
        name: config.name,
        description: config.description,
        phase: config.phase,
        className: config.className,
        methodName: config.methodName,
        constructors: config.constructors,
        constructorData: constructorData,
        inputs: inputs,
        outputs: outputs,
        dependsOn: dependsOn,
        dependents: dependents);
  }
}

/// jb extension model.
class JbExtensionModel {
  final JbConfiguration config;
  final String classpath;
  final List<ExtensionTask> extensionTasks;

  const JbExtensionModel(this.config, this.classpath, this.extensionTasks);
}

class JbConfigContainer {
  final JbConfiguration config;
  final CompileOutput output;

  JbConfigContainer(this.config)
      : output = config.outputDir.vmapOr(
            CompileOutput.dir,
            () => CompileOutput.jar(config.outputJar ??
                '${p.join('build', p.basename(Directory.current.path))}.jar'));

  @override
  String toString() {
    return 'JbConfigContainer{config: $config, output: $output}';
  }
}

/// jb configuration model.
extension JbConfigExtension on JbConfiguration {
  /// Merge this configuration with another.
  ///
  /// Values from the other configuration take precedence.
  JbConfiguration merge(JbConfiguration other) {
    final props = properties.union(other.properties);

    return JbConfiguration(
      group: resolveOptionalString(other.group ?? group, props),
      module: resolveOptionalString(other.module ?? module, props),
      name: resolveOptionalString(other.name ?? name, props),
      version: resolveOptionalString(other.version ?? version, props),
      description:
          resolveOptionalString(other.description ?? description, props),
      url: resolveOptionalString(other.url ?? url, props),
      mainClass: resolveOptionalString(other.mainClass ?? mainClass, props),
      extensionProject: resolveOptionalString(
          other.extensionProject ?? extensionProject, props),
      sourceDirs: sourceDirs.merge(other.sourceDirs, props),
      outputDir: resolveOptionalString(other.outputDir ?? outputDir, props),
      outputJar:
          resolveOptionalString(other.outputJar ?? outputJar, properties),
      resourceDirs: resourceDirs.merge(other.resourceDirs, props),
      repositories: repositories.merge(other.repositories, props),
      dependencies: dependencies.merge(other.dependencies, props),
      processorDependencies:
          processorDependencies.merge(other.processorDependencies, props),
      dependencyExclusionPatterns: dependencyExclusionPatterns.merge(
          other.dependencyExclusionPatterns, props),
      processorDependencyExclusionPatterns: processorDependencyExclusionPatterns
          .merge(other.processorDependencyExclusionPatterns, props),
      compileLibsDir: resolveString(
          other.compileLibsDir == 'build/compile-libs'
              ? compileLibsDir
              : other.compileLibsDir,
          props),
      runtimeLibsDir: resolveString(
          other.runtimeLibsDir == 'build/runtime-libs'
              ? runtimeLibsDir
              : other.runtimeLibsDir,
          props),
      testReportsDir: resolveString(
          other.testReportsDir == 'build/test-reports'
              ? testReportsDir
              : other.testReportsDir,
          props),
      javacArgs: javacArgs.merge(other.javacArgs, props),
      runJavaArgs: runJavaArgs.merge(other.runJavaArgs, props),
      testJavaArgs: testJavaArgs.merge(other.testJavaArgs, props),
      javacEnv: javacEnv.merge(other.javacEnv, props),
      runJavaEnv: runJavaEnv.merge(other.runJavaEnv, props),
      testJavaEnv: testJavaEnv.merge(other.testJavaEnv, props),
      scm: scm.merge(other.scm, props),
      developers: developers.merge(other.developers, props),
      licenses: licenses.merge(other.licenses, props),
      properties: props,
      extras: extras.union(other.extras),
    );
  }

  void validate() {
    if (outputDir != null && outputJar != null) {
      throw DartleException(
          message: 'Invalid configuration: '
              'only one of "output-dir" and "output-jar" should be provided');
    }
    final invalidLicenses =
        licenses.where(allLicenses.containsKey.not$).toSet();
    if (invalidLicenses.isNotEmpty) {
      throw _invalidLicense(invalidLicenses);
    }
  }

  Iterable<MapEntry<String, DependencySpec>> get allDependencies =>
      _depsIterable(dependencies);

  Iterable<MapEntry<String, DependencySpec>> get allProcessorDependencies =>
      _depsIterable(processorDependencies);

  Iterable<MapEntry<String, DependencySpec>> _depsIterable(
      Map<String, DependencySpec?> deps) sync* {
    for (final dep in deps.entries) {
      final value = dep.value;
      yield MapEntry(dep.key, value ?? defaultSpec);
    }
  }

  /// Get the list of JBuild global arguments (pre-args)
  /// from this configuration.
  List<String> preArgs() {
    final result = <String>['-w', Directory.current.path, '-q'];
    if (logger.isLoggable(log.Level.FINE)) {
      result.add('-V');
    }
    for (final repo in repositories.toSet()) {
      result.add('-r');
      result.add(repo);
    }
    return result;
  }

  /// Get the compile task arguments from this configuration.
  Future<List<String>> compileArgs(String processorLibsDir,
      [TransitiveChanges? changes]) async {
    final result = <String>[];
    if (compileLibsDir.isNotEmpty) {
      result.addAll(['-cp', compileLibsDir]);
    }
    outputDir?.vmap((d) => result.addAll(['-d', d]));
    outputJar?.vmap((jar) => result.addAll(['-j', jar]));
    for (final r in resourceDirs.toSet()) {
      result.addAll(['-r', r]);
    }
    final main = mainClass;
    if (main != null && main.isNotEmpty) {
      result.addAll(['-m', main]);
    }
    if (dependencies.keys.any((d) => d.startsWith(jbApi))) {
      result.add('--jb-extension');
    }
    if (changes == null || !_addIncrementalCompileArgs(result, changes)) {
      result.addAll(sourceDirs);
    }
    if (javacArgs.isNotEmpty || processorDependencies.isNotEmpty) {
      result.add('--');
      result.addAll(javacArgs);
      if (processorDependencies.isNotEmpty) {
        result.add('-processorpath');
        (await Directory(processorLibsDir).toClasspath())?.vmap(result.add);
      }
    }
    return result;
  }

  /// Add the incremental compilation args if applicable.
  ///
  /// Return true if added, false otherwise.
  bool _addIncrementalCompileArgs(
      List<String> args, TransitiveChanges changes) {
    var incremental = false;
    for (final change in changes.fileChanges) {
      if (change.entity is! File) continue;
      incremental = true;
      if (change.kind == ChangeKind.deleted) {
        final path = change.entity.path;
        if (path.endsWith('.java')) {
          for (final classFile in changes.fileTree
              .classFilesOf(sourceDirs, change.entity.path)) {
            args.add('--deleted');
            args.add(classFile);
          }
        } else {
          args.add('--deleted');
          args.add(change.entity.path);
        }
      } else {
        args.add('--added');
        args.add(change.entity.path);
      }
    }

    // previous compilation output must be part of the classpath
    (outputDir ?? outputJar ?? '').ifNonBlank((cp) {
      args.add('-cp');
      args.add(cp);
    });

    return incremental;
  }

  /// Get the install arguments for the compile task from this configuration.
  List<String> installArgsForCompilation() {
    final depsToInstall = allDependencies
        .where((e) =>
            e.value.scope.includedInCompilation() && e.value.path == null)
        .map((e) => e.key)
        .toList(growable: false);

    if (depsToInstall.isEmpty) return const [];

    final result = ['-s', 'compile', '-m', '-d', compileLibsDir];
    for (final exclude in dependencyExclusionPatterns.toSet()) {
      result.add('--exclusion');
      result.add(exclude);
    }
    result.addAll(depsToInstall);
    return result;
  }

  /// Get the install arguments for the installRuntime task from this configuration.
  List<String> installArgsForRuntime() {
    return _installArgs(
        allDependencies, dependencyExclusionPatterns.toSet(), runtimeLibsDir);
  }

  /// Get the install arguments for the installProcessor task from this configuration.
  List<String> installArgsForProcessor(String destinationDir) {
    return _installArgs(allProcessorDependencies,
        processorDependencyExclusionPatterns.toSet(), destinationDir);
  }

  static List<String> _installArgs(
      Iterable<MapEntry<String, DependencySpec>> deps,
      Set<String> exclusions,
      String destinationDir) {
    if (deps.isEmpty) return const [];

    final depsToInstall = deps
        .where((e) => e.value.scope.includedAtRuntime() && e.value.path == null)
        .map((e) => e.key)
        .toList(growable: false);

    if (depsToInstall.isEmpty) return const [];

    final result = ['-s', 'runtime', '-m', '-d', destinationDir];
    for (final exclude in exclusions.toSet()) {
      result.add('--exclusion');
      result.add(exclude);
    }
    result.addAll(depsToInstall);
    return result;
  }

  String toYaml(bool noColor) {
    final color = createAnsiColor(noColor);
    String quote(String? value) =>
        value == null ? color('null', kwColor) : color('"$value"', strColor);

    String multilineList(Iterable<String> lines, {bool isMap = false}) {
      if (lines.isEmpty) {
        if (isMap) return ' {}';
        return ' []';
      }
      final dash = isMap ? '' : '- ';
      return '\n${lines.map((line) => '  $dash$line').join('\n')}';
    }

    String depsToYaml(Iterable<MapEntry<String, DependencySpec>> deps) {
      return multilineList(
          deps.map((dep) =>
              '${quote(dep.key)}:\n${dep.value.toYaml(color, '    ')}'),
          isMap: true);
    }

    String developersToYaml(Iterable<Developer> developers) {
      return multilineList(developers.map((dev) => dev.toYaml(color, '    ')));
    }

    String scmToYaml(SourceControlManagement? scm) {
      if (scm == null) return color(' null', kwColor);
      return '\n  ${scm.toYaml(color, '  ')}';
    }

    String mapToYaml(Map<String, String> map) {
      if (map.isEmpty) return ' {}';
      return '\n${map.entries.map((e) => '  ${quote(e.key)}: '
          '${quote(e.value)}').join('\n')}';
    }

    return '''
${color('''
######################## Full jb configuration ########################

### For more information, visit https://github.com/renatoathaydes/jb
''', commentColor)}
${color('# Maven artifact groupId', commentColor)}
group: ${quote(group)}
${color('# Module name (Maven artifactId)', commentColor)}
module: ${quote(module)}
${color('# Human readable name of this project', commentColor)}
name: ${quote(name)}
${color('# Maven version', commentColor)}
version: ${quote(version)}
${color('# Description for this project', commentColor)}
description: ${quote(description)}
${color('# URL of this project', commentColor)}
url: ${quote(url)}
${color('# Licenses this project uses', commentColor)}
licenses: [${licenses.map((lic) => quote(lic)).join(', ')}]
${color('# Developers who have contributed to this project', commentColor)}
developers:${developersToYaml(developers)}
${color('# Source control management', commentColor)}
scm:${scmToYaml(scm)}
${color('# List of source directories', commentColor)}
source-dirs: [${sourceDirs.map(quote).join(', ')}]
${color('# List of resource directories (assets)', commentColor)}
resource-dirs: [${resourceDirs.map(quote).join(', ')}]
${color('# Output directory (class files)', commentColor)}
output-dir: ${quote(outputDir)}
${color('# Output jar (may be used instead of output-dir)', commentColor)}
output-jar: ${quote(outputJar)}
${color('# Java Main class name', commentColor)}
main-class: ${quote(mainClass)}
${color('# Java Compiler arguments', commentColor)}
javac-args: [${javacArgs.map(quote).join(', ')}]
${color('# Java Compiler environment variables', commentColor)}
javac-env:${mapToYaml(javacEnv)}
${color('# Java Runtime arguments', commentColor)}
run-java-args: [${runJavaArgs.map(quote).join(', ')}]
${color('# Java Runtime environment variables', commentColor)}
run-java-env:${mapToYaml(runJavaEnv)}
${color('# Java Test run arguments', commentColor)}
test-java-args: [${javacArgs.map(quote).join(', ')}]
${color('# Java Test environment variables', commentColor)}
test-java-env:${mapToYaml(testJavaEnv)}
${color('# Maven repositories (URLs or directories)', commentColor)}
repositories: [${repositories.map(quote).join(', ')}]
${color('# Maven dependencies', commentColor)}
dependencies:${depsToYaml(allDependencies)}
${color('# Dependency exclusions (regular expressions)', commentColor)}
dependency-exclusion-patterns:${multilineList(dependencyExclusionPatterns.map(quote))}
${color('# Annotation processor Maven dependencies', commentColor)}
processor-dependencies:${depsToYaml(allProcessorDependencies)}
${color('# Annotation processor dependency exclusions (regular expressions)', commentColor)}
processor-dependency-exclusion-patterns:${multilineList(processorDependencyExclusionPatterns.map(quote))}
${color('# Compile-time libs output dir', commentColor)}
compile-libs-dir: ${quote(compileLibsDir)}
${color('# Runtime libs output dir', commentColor)}
runtime-libs-dir: ${quote(runtimeLibsDir)}
${color('# Test reports output dir', commentColor)}
test-reports-dir: ${quote(testReportsDir)}
${color('# jb extension project path (for custom tasks)', commentColor)}
extension-project: ${quote(extensionProject)}
''';
  }
}

Exception _invalidLicense(Iterable<String> ids) {
  final prefix = ids.length == 1 ? 'License is' : 'Licenses are';
  return DartleException(
      message: '$prefix not recognized: $ids. '
          'See https://spdx.org/licenses/ for valid licenses.\n'
          'Currently known license IDs: ${allLicenses.keys.join(', ')}');
}

/// Grouping of all local dependencies, which can be local
/// [JarDependency] or [ProjectDependency]s.
class LocalDependencies {
  final List<JarDependency> jars;
  final List<ProjectDependency> projectDependencies;

  const LocalDependencies(this.jars, this.projectDependencies);

  bool get isEmpty => jars.isEmpty && projectDependencies.isEmpty;

  bool get isNotEmpty => !isEmpty;
}

enum _CompileOutputTag { dir, jar }

/// Compilation output destination.
class CompileOutput {
  final _CompileOutputTag _tag;

  final String _value;

  const CompileOutput._(String value, _CompileOutputTag tag)
      : _value = value,
        _tag = tag;

  const CompileOutput.dir(String directory)
      : this._(directory, _CompileOutputTag.dir);

  const CompileOutput.jar(String jar) : this._(jar, _CompileOutputTag.jar);

  T when<T>(
      {required T Function(String) dir, required T Function(String) jar}) {
    switch (_tag) {
      case _CompileOutputTag.dir:
        return dir(_value);
      case _CompileOutputTag.jar:
        return jar(_value);
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CompileOutput &&
          runtimeType == other.runtimeType &&
          _tag == other._tag &&
          _value == other._value;

  @override
  int get hashCode => _tag.hashCode ^ _value.hashCode;

  @override
  String toString() {
    return switch (_tag) {
      _CompileOutputTag.dir => 'DIR($_value)',
      _CompileOutputTag.jar => 'JAR($_value)',
    };
  }
}

extension DependencyScopeExtension on DependencyScope {
  bool includedInCompilation() {
    return this != DependencyScope.runtimeOnly;
  }

  bool includedAtRuntime() {
    return this != DependencyScope.compileOnly;
  }

  String toYaml(AnsiColor color) {
    return color(
        switch (this) {
          DependencyScope.runtimeOnly => '"runtime-only"',
          DependencyScope.compileOnly => '"compile-only"',
          DependencyScope.all => '"all"',
        },
        strColor);
  }
}

const DependencySpec defaultSpec =
    DependencySpec(transitive: true, scope: DependencyScope.all);

extension DependencySpecExtension on DependencySpec {
  Future<PathDependency>? toPathDependency() {
    final thisPath = path;
    if (thisPath == null) return null;
    return FileSystemEntity.isFile(thisPath).then((isFile) => isFile
        ? PathDependency.jar(this, thisPath)
        : PathDependency.jbuildProject(this, thisPath));
  }

  DependencySpec resolveProperties(Properties properties) {
    final p = path;
    if (p != null && p.contains('{')) {
      return DependencySpec(
          transitive: transitive,
          scope: scope,
          path: resolveString(p, properties));
    }
    return this;
  }

  String toYaml(AnsiColor color, String ident) {
    final colorPath =
        path == null ? color('null', kwColor) : color('"$path"', strColor);
    return '${ident}transitive: ${color('$transitive', kwColor)}\n'
        '${ident}scope: ${scope.toYaml(color)}\n'
        '${ident}path: $colorPath';
  }
}

_Value<String> _stringValue(
    Map<String, Object?> map, String key, String? defaultValue,
    {String? type}) {
  final value = map.remove(key);
  String result;
  bool isDefault = false;
  if (value == null && defaultValue != null) {
    result = defaultValue;
    isDefault = true;
  } else if (value is String) {
    result = value;
  } else {
    final prefix = type == null ? '' : 'on $type: ';
    throw DartleException(
        message:
            "${prefix}expecting a String value for '$key', but got '$value'.");
  }
  return _Value(isDefault, result);
}

String? _optionalStringValue(Map<String, Object?> map, String key,
    {bool allowNumber = false, String? type}) {
  final value = map.remove(key);
  if (value == null) return null;
  if (value is String) {
    return value;
  }
  if (allowNumber && value is num) {
    return value.toString();
  }
  final prefix = type == null ? '' : 'on $type: ';
  throw DartleException(
      message:
          "${prefix}expecting a String value for '$key', but got '$value'.");
}

const dependenciesSyntaxHelp = '''
Use the following syntax to declare dependencies:

  dependencies:
    first:dep:1.0:
    another:dep:2.0:
        transitive: false  # true (at runtime) by default
        scope: runtime-only # or: compile-only, all
        path: "<path to local project or jar>"
''';

const scmSyntaxHelp = '''
Use the following syntax to declare scm (source control management):

  scm:
    connection: "<source control connection>"
    developer-connection: "<source control dev connection>"
    url: "<repository URL>"
''';

const developerSyntaxHelp = '''
Use the following syntax to declare 'developers':

  developers:
    - name: John Doe
      email: john@doe.com
      organization: ACME
      organization-url: https://acme.example.org
''';

List<ExtensionTaskConfig> _extensionTasks(Map<String, Object?> map) {
  final tasks = map['tasks'];
  if (tasks is Map<String, Object?>) {
    return tasks.entries.map(_extensionTask).toList(growable: false);
  } else {
    throw DartleException(
        message: "expecting a List of tasks for value 'tasks', "
            "but got '$tasks'.");
  }
}

const taskSyntaxHelp = '''
Tasks should be declared as follows:

tasks:
  my-task:
    class-name: my.java.ClassName           (mandatory)
    description: description of the task    (optional)
    phase: build                            (optional)
  other-task:
    class-name: my.java.OtherClass
''';

ExtensionTaskConfig _extensionTask(MapEntry<String, Object?> task) {
  final spec = task.value;
  if (spec is Map<String, Object?>) {
    return (
      name: task.key,
      description: _stringValue(spec, 'description', '', type: 'Task').value,
      phase: _taskPhase(spec['phase']),
      className: _optionalStringValue(spec, 'class-name', type: 'Task')
          .orThrow(() => DartleException(
              message: "declaration of task '${task.key}' is missing mandatory "
                  "'class-name'.\n$taskSyntaxHelp")),
      methodName: 'run',
      constructors: _taskConstructors(spec['config-constructors']),
    );
  } else {
    throw DartleException(
        message: 'bad task declaration, '
            "expected String or Map value, got '$task'.\n"
            "$taskSyntaxHelp");
  }
}

TaskPhase _taskPhase(Object? phase) {
  if (phase == null) return TaskPhase.build;
  if (phase is Map) {
    if (phase.length != 1) {
      throw DartleException(
          message: 'invalid task phase declaration, not single entry Map.');
    }
    final name = phase.keys.first.toString();
    final index = phase.values.first;
    if (index is int) {
      if (index == -1) {
        // default value: probably wants a built-in phase
        final builtInPhase =
            TaskPhase.builtInPhases.where((p) => p.name == name).firstOrNull;
        if (builtInPhase != null) return builtInPhase;
      }
      return TaskPhase.custom(index, name);
    }
    throw DartleException(message: "task phase '$name' index is not a number.");
  }
  throw DartleException(message: 'invalid task phase declaration, not a Map.');
}

List<JavaConstructor> _taskConstructors(Object? constructors) {
  if (constructors == null) {
    failBuild(reason: 'jb manifest missing constructors');
  }
  if (constructors is! Iterable) {
    failBuild(
        reason:
            'jb manifest has invalid constructors declaration: $constructors');
  }
  return constructors.map((entry) {
    if (entry is Map) {
      return entry.map((key, value) => _constructorEntry(key, value));
    } else {
      failBuild(reason: 'jb manifest has invalid constructor item: $entry');
    }
  }).toList(growable: false);
}

MapEntry<String, ConfigType> _constructorEntry(Object? key, Object? value) {
  if (key is String && value is String) {
    return MapEntry(key, ConfigType.from(value));
  }
  failBuild(
      reason: 'jb manifest has invalid constructor entry: $key -> $value');
}
