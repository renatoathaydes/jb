import 'dart:io';

import 'package:conveniently/conveniently.dart';
import 'package:dartle/dartle.dart';
import 'package:dartle/dartle_cache.dart' show ChangeKind;
import 'package:logging/logging.dart' as log;
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import 'ansi.dart';
import 'config_import.dart';
import 'file_tree.dart';
import 'licenses.g.dart';
import 'maven_metadata.dart';
import 'path_dependency.dart';
import 'properties.dart';
import 'utils.dart';

final logger = log.Logger('jb');

const yamlJbFile = 'jbuild.yaml';
const jsonJbFile = 'jbuild.json';

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
    return await JbConfiguration.fromMap(
            resolvedMap.map, resolvedMap.properties)
        .applyImports(imports);
  } else {
    throw DartleException(
        message: 'Expecting jb configuration to be a Map, '
            'but it is ${json?.runtimeType}');
  }
}

/// Parse the YAML/JSON jb extension model.
///
/// Applies defaults and resolves properties and imports.
Future<JbExtensionModel> loadJbExtensionModel(
    String config, Uri yamlUri) async {
  final json = loadYaml(config, sourceUrl: yamlUri);
  if (json is Map) {
    final resolvedMap = resolvePropertiesFromMap(json);
    return JbExtensionModel.fromMap(resolvedMap.map, resolvedMap.properties);
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

extension on _Value<Iterable<String>> {
  Set<String> toSet() => value.toSet();

  List<String> toList() => value.toList(growable: false);
}

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

  ExtensionTask({
    required this.name,
    required this.description,
    required this.phase,
    required this.inputs,
    required this.outputs,
    required this.dependsOn,
    required this.className,
    required this.methodName,
    required this.dependents,
  });
}

/// jb extension model.
class JbExtensionModel {
  final List<ExtensionTask> extensionTasks;

  const JbExtensionModel(this.extensionTasks);

  static JbExtensionModel fromMap(Map<String, Object?> map,
      [Properties properties = const {}]) {
    final extensionTasks = _extensionTasks(map);
    return JbExtensionModel(extensionTasks);
  }
}

/// jb configuration model.
class JbConfiguration {
  final String? group;
  final String? module;
  final String? name;
  final String? version;
  final String? description;
  final String? url;
  final List<License> licenses;
  final List<Developer> developers;
  final SourceControlManagement? scm;
  final String? mainClass;
  final String? extensionProject;
  final Set<String> sourceDirs;
  final bool _defaultSourceDirs;
  final CompileOutput output;
  final bool _defaultOutput;
  final Set<String> resourceDirs;
  final bool _defaultResourceDirs;
  final List<String> javacArgs;
  final List<String> runJavaArgs;
  final List<String> testJavaArgs;
  final Map<String, String> javacEnv;
  final Map<String, String> runJavaEnv;
  final Map<String, String> testJavaEnv;
  final Set<String> repositories;
  final Map<String, DependencySpec> dependencies;
  final Set<String> dependencyExclusionPatterns;
  final Map<String, DependencySpec> processorDependencies;
  final Set<String> processorDependencyExclusionPatterns;
  final String compileLibsDir;
  final bool _defaultCompileLibsDir;
  final String runtimeLibsDir;
  final bool _defaultRuntimeLibsDir;
  final String testReportsDir;
  final bool _defaultTestReportsDir;
  final Properties properties;

  const JbConfiguration({
    this.group,
    this.module,
    this.name,
    this.version,
    this.description,
    this.url,
    this.scm,
    this.mainClass,
    this.extensionProject,
    bool defaultSourceDirs = false,
    bool defaultOutput = false,
    bool defaultResourceDirs = false,
    bool defaultCompileLibsDir = false,
    bool defaultRuntimeLibsDir = false,
    bool defaultTestReportsDir = false,
    required this.licenses,
    required this.developers,
    required this.sourceDirs,
    required this.output,
    required this.resourceDirs,
    required this.javacArgs,
    required this.runJavaArgs,
    required this.testJavaArgs,
    required this.javacEnv,
    required this.runJavaEnv,
    required this.testJavaEnv,
    required this.repositories,
    required this.dependencies,
    required this.dependencyExclusionPatterns,
    required this.processorDependencies,
    required this.processorDependencyExclusionPatterns,
    required this.compileLibsDir,
    required this.runtimeLibsDir,
    required this.testReportsDir,
    this.properties = const {},
  })  : _defaultSourceDirs = defaultSourceDirs,
        _defaultOutput = defaultOutput,
        _defaultResourceDirs = defaultResourceDirs,
        _defaultCompileLibsDir = defaultCompileLibsDir,
        _defaultRuntimeLibsDir = defaultRuntimeLibsDir,
        _defaultTestReportsDir = defaultTestReportsDir;

  /// Create a [JbConfiguration] from a map.
  /// This method does not do any processing or validation of values, it simply
  /// reads values from the Map and includes defaults where needed.
  ///
  /// The optional [Properties] argument is stored within the returned
  /// [JbConfiguration] but is not used to resolve properties values
  /// (it only gets used when the returned configuration is merged with another).
  /// That's expected to already have been done before calling this method.
  static JbConfiguration fromMap(Map<String, Object?> map,
      [Properties properties = const {}]) {
    _validateConfigKeys(map);
    final sourceDirs = _stringIterableValue(map, 'source-dirs', const {'src'});
    final output = _compileOutputValue(map, 'output-dir', 'output-jar');
    final resourceDirs =
        _stringIterableValue(map, 'resource-dirs', const {'resources'});
    final javacArgs = _stringIterableValue(map, 'javac-args', const []);
    final licenses = _stringIterableValue(map, 'licenses', const []);
    final runJavaArgs = _stringIterableValue(map, 'run-java-args', const []);
    final testJavaArgs = _stringIterableValue(map, 'test-java-args', const []);
    final javacEnv = _stringMapValue(map, 'javac-env', const {});
    final runJavaEnv = _stringMapValue(map, 'run-java-env', const {});
    final testJavaEnv = _stringMapValue(map, 'test-java-env', const {});
    final dependencies = _dependencies(map, 'dependencies', const {});
    final scm = _scm(map);
    final developers = _developers(map);
    final repositories = _stringIterableValue(map, 'repositories', const {});
    final exclusions =
        _stringIterableValue(map, 'dependency-exclusion-patterns', const {});
    final processorDependencies =
        _dependencies(map, 'processor-dependencies', const {});
    final processorDependenciesExclusions = _stringIterableValue(
        map, 'processor-dependency-exclusion-patterns', const {});
    final compileLibsDir =
        _stringValue(map, 'compile-libs-dir', 'build/compile-libs');
    final runtimeLibsDir =
        _stringValue(map, 'runtime-libs-dir', 'build/runtime-libs');
    final testReportsDir =
        _stringValue(map, 'test-reports-dir', 'build/test-reports');

    return JbConfiguration(
      group: _optionalStringValue(map, 'group'),
      module: _optionalStringValue(map, 'module'),
      name: _optionalStringValue(map, 'name'),
      version: _optionalStringValue(map, 'version', allowNumber: true),
      description: _optionalStringValue(map, 'description'),
      url: _optionalStringValue(map, 'url'),
      scm: scm,
      developers: developers,
      mainClass: _optionalStringValue(map, 'main-class'),
      extensionProject: _optionalStringValue(map, 'extension-project'),
      sourceDirs: sourceDirs.toSet(),
      defaultSourceDirs: sourceDirs.isDefault,
      output: output ?? _defaultOutputValue(),
      defaultOutput: output == null,
      resourceDirs: resourceDirs.toSet(),
      defaultResourceDirs: resourceDirs.isDefault,
      licenses: licenses.value
          .map((id) => allLicenses[id].orThrow(() => _invalidLicense(id)))
          .toList(),
      javacArgs: javacArgs.toList(),
      runJavaArgs: runJavaArgs.toList(),
      testJavaArgs: testJavaArgs.toList(),
      javacEnv: javacEnv.value,
      runJavaEnv: runJavaEnv.value,
      testJavaEnv: testJavaEnv.value,
      dependencies: dependencies.value,
      repositories: repositories.toSet(),
      dependencyExclusionPatterns: exclusions.toSet(),
      processorDependencies: processorDependencies.value,
      processorDependencyExclusionPatterns:
          processorDependenciesExclusions.toSet(),
      compileLibsDir: compileLibsDir.value,
      defaultCompileLibsDir: compileLibsDir.isDefault,
      runtimeLibsDir: runtimeLibsDir.value,
      defaultRuntimeLibsDir: runtimeLibsDir.isDefault,
      testReportsDir: testReportsDir.value,
      defaultTestReportsDir: testReportsDir.isDefault,
      properties: properties,
    );
  }

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
      scm: scm.merge(other.scm, props),
      developers: developers.merge(other.developers, props),
      mainClass: resolveOptionalString(other.mainClass ?? mainClass, props),
      extensionProject: resolveOptionalString(
          other.extensionProject ?? extensionProject, props),
      sourceDirs: _mergeWithDefault(sourceDirs, _defaultSourceDirs,
          other.sourceDirs, other._defaultSourceDirs, props),
      defaultSourceDirs: _defaultSourceDirs && other._defaultSourceDirs,
      output: (other._defaultOutput ? output : other.output)
          .resolveProperties(props),
      defaultOutput: _defaultOutput && other._defaultOutput,
      resourceDirs: _mergeWithDefault(resourceDirs, _defaultResourceDirs,
          other.resourceDirs, other._defaultResourceDirs, props),
      defaultResourceDirs: _defaultResourceDirs && other._defaultResourceDirs,
      licenses: licenses
          .map((lic) => lic.licenseId)
          .toSet() // for uniqueness on merging
          .merge(other.licenses.map((lic) => lic.licenseId), props)
          .map((id) => allLicenses[id].orThrow(() => _invalidLicense(id)))
          .toList(),
      javacArgs: javacArgs.merge(other.javacArgs, props),
      runJavaArgs: runJavaArgs.merge(other.runJavaArgs, props),
      testJavaArgs: testJavaArgs.merge(other.testJavaArgs, props),
      javacEnv: javacEnv.merge(other.javacEnv, props),
      runJavaEnv: runJavaEnv.merge(other.runJavaEnv, props),
      testJavaEnv: testJavaEnv.merge(other.testJavaEnv, props),
      repositories: repositories.merge(other.repositories, props),
      dependencies: dependencies.merge(other.dependencies, props),
      dependencyExclusionPatterns: dependencyExclusionPatterns.merge(
          other.dependencyExclusionPatterns, props),
      processorDependencies:
          processorDependencies.merge(other.processorDependencies, props),
      processorDependencyExclusionPatterns: processorDependencyExclusionPatterns
          .merge(other.processorDependencyExclusionPatterns, props),
      compileLibsDir: resolveString(
          other._defaultCompileLibsDir ? compileLibsDir : other.compileLibsDir,
          props),
      defaultCompileLibsDir:
          _defaultCompileLibsDir && other._defaultCompileLibsDir,
      runtimeLibsDir: resolveString(
          other._defaultRuntimeLibsDir ? runtimeLibsDir : other.runtimeLibsDir,
          props),
      defaultRuntimeLibsDir:
          _defaultRuntimeLibsDir && other._defaultRuntimeLibsDir,
      testReportsDir: resolveString(
          other._defaultTestReportsDir ? testReportsDir : other.testReportsDir,
          props),
      defaultTestReportsDir:
          _defaultTestReportsDir && other._defaultTestReportsDir,
      properties: props,
    );
  }

  /// Get the list of JBuild global arguments (pre-args)
  /// from this configuration.
  List<String> preArgs() {
    final result = <String>['-w', Directory.current.path, '-q'];
    if (logger.isLoggable(Level.FINE)) {
      result.add('-V');
    }
    for (final repo in repositories) {
      result.add('-r');
      result.add(repo);
    }
    return result;
  }

  /// Get the compile task arguments from this configuration.
  Future<List<String>> compileArgs(String processorLibsDir,
      [TransitiveChanges? changes]) async {
    final result = <String>[];
    result.addAll(['-cp', compileLibsDir]);
    output.when(
        dir: (d) => result.addAll(['-d', d]),
        jar: (j) => result.addAll(['-j', j]));
    for (final r in resourceDirs) {
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
    args.add('-cp');
    args.add(output.when(dir: (d) => d, jar: (j) => j));

    return incremental;
  }

  /// Get the install arguments for the compile task from this configuration.
  List<String> installArgsForCompilation() {
    final depsToInstall = dependencies.entries
        .where((e) =>
            e.value.scope.includedInCompilation() && e.value.path == null)
        .map((e) => e.key)
        .toList(growable: false);

    if (depsToInstall.isEmpty) return const [];

    final result = ['-s', 'compile', '-m', '-d', compileLibsDir];
    for (final exclude in dependencyExclusionPatterns) {
      result.add('--exclusion');
      result.add(exclude);
    }
    result.addAll(depsToInstall);
    return result;
  }

  /// Get the install arguments for the installRuntime task from this configuration.
  List<String> installArgsForRuntime() {
    return _installArgs(
        dependencies, dependencyExclusionPatterns, runtimeLibsDir);
  }

  /// Get the install arguments for the installProcessor task from this configuration.
  List<String> installArgsForProcessor(String destinationDir) {
    return _installArgs(processorDependencies,
        processorDependencyExclusionPatterns, destinationDir);
  }

  static List<String> _installArgs(Map<String, DependencySpec> deps,
      Set<String> exclusions, String destinationDir) {
    if (deps.isEmpty) return const [];

    final depsToInstall = deps.entries
        .where((e) => e.value.scope.includedAtRuntime() && e.value.path == null)
        .map((e) => e.key)
        .toList(growable: false);

    if (depsToInstall.isEmpty) return const [];

    final result = ['-s', 'runtime', '-m', '-d', destinationDir];
    for (final exclude in exclusions) {
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

    String multilineList(Iterable<String> lines) {
      if (lines.isEmpty) return ' []';
      return '\n${lines.map((line) => '  - $line').join('\n')}';
    }

    String depsToYaml(Iterable<MapEntry<String, DependencySpec>> deps) {
      return multilineList(deps.map(
          (dep) => '${quote(dep.key)}:\n${dep.value.toYaml(color, '    ')}'));
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
${color('# Maven artifactId', commentColor)}
module: ${quote(module)}
${color('# Maven version', commentColor)}
version: ${quote(version)}
${color('# Project name', commentColor)}
name: ${quote(name)}
${color('# Description for this project', commentColor)}
description: ${quote(description)}
${color('# URL of this project', commentColor)}
url: ${quote(url)}
${color('# Licenses this project uses', commentColor)}
licenses: [${licenses.map((lic) => quote(lic.licenseId)).join(', ')}]
${color('# Developers who have contributed to this project', commentColor)}
developers:${developersToYaml(developers)}
${color('# Source control management', commentColor)}
scm:${scmToYaml(scm)}
${color('# List of source directories', commentColor)}
source-dirs: [${sourceDirs.map(quote).join(', ')}]
${color('# List of resource directories (assets)', commentColor)}
resource-dirs: [${resourceDirs.map(quote).join(', ')}]
${color('# Output directory (class files)', commentColor)}
output-dir: ${quote(output.when(dir: (d) => d, jar: (j) => null))}
${color('# Output jar (may be used instead of output-dir)', commentColor)}
output-jar: ${quote(output.when(dir: (d) => null, jar: (j) => j))}
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
dependencies:${depsToYaml(dependencies.entries)}
${color('# Dependency exclusions (regular expressions)', commentColor)}
dependency-exclusion-patterns:${multilineList(dependencyExclusionPatterns.map(quote))}
${color('# Annotation processor Maven dependencies', commentColor)}
processor-dependencies:${depsToYaml(processorDependencies.entries)}
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

  @override
  String toString() {
    return 'JBuildConfiguration{group: $group, '
        'module: $module, name: $name, version: $version, '
        'licenses: $licenses, mainClass: $mainClass, '
        'extensionProject: $extensionProject, sourceDirs: $sourceDirs, '
        'output: $output, resourceDirs: $resourceDirs, javacArgs: $javacArgs, '
        'runJavaArgs: $runJavaArgs, testJavaArgs: $testJavaArgs, '
        'javacEnv: $javacEnv, runJavaEnv: $runJavaEnv, '
        'testJavaEnv: $testJavaEnv, repositories: $repositories, '
        'dependencies: $dependencies, exclusions: $dependencyExclusionPatterns, '
        'processorDependencies: $processorDependencies, '
        'processorDependenciesExclusions: $processorDependencyExclusionPatterns, '
        'compileLibsDir: $compileLibsDir, runtimeLibsDir: $runtimeLibsDir, '
        'testReportsDir: $testReportsDir, properties: $properties}';
  }
}

void _validateConfigKeys(Map<String, Object?> map) {
  const validKeys = {
    'group',
    'module',
    'name',
    'version',
    'description',
    'url',
    'main-class',
    'extension-project',
    'source-dirs',
    'output-dir',
    'output-jar',
    'resource-dirs',
    'javac-args',
    'licenses',
    'developers',
    'scm',
    'run-java-args',
    'test-java-args',
    'javac-env',
    'run-java-env',
    'test-java-env',
    'dependencies',
    'repositories',
    'dependency-exclusion-patterns',
    'processor-dependencies',
    'processor-dependency-exclusion-patterns',
    'compile-libs-dir',
    'runtime-libs-dir',
    'test-reports-dir',
  };
  final keys = map.keys.toSet();
  keys.removeAll(validKeys);
  if (keys.isNotEmpty) {
    throw DartleException(
        message:
            'Invalid jbuild configuration: unrecognized field${keys.length == 1 ? '' : 's'}: '
            '${keys.map((e) => '"$e"').join(', ')}');
  }
}

Set<String> _mergeWithDefault(
    Set<String> values,
    bool defaultValues,
    Set<String> otherValues,
    bool defaultOtherValues,
    Map<String, Object?> props) {
  if (defaultValues) return otherValues.merge(const {}, props);
  if (defaultOtherValues) return values.merge(const {}, props);
  return values.merge(otherValues, props);
}

Exception _invalidLicense(String id) {
  return DartleException(
      message: 'License is not recognized: "$id". '
          'See https://spdx.org/licenses/ for valid license identifiers.');
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

  CompileOutput resolveProperties(Properties properties) {
    return CompileOutput._(resolveString(_value, properties), _tag);
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

/// Scope of a dependency.
enum DependencyScope {
  /// dependency is required both at compile-time and runtime.
  all,

  /// dependency is required at compile-time, but not runtime.
  compileOnly,

  /// dependency is required at runtime, but not compile-time.
  runtimeOnly;

  /// Convert a String to a [DependencyScope].
  static DependencyScope fromName(String name) {
    return switch (name) {
      'runtime-only' => runtimeOnly,
      'compile-only' => compileOnly,
      'all' => all,
      _ => throw DartleException(
          message: "Invalid scope: '$name'. "
              "Valid names are: runtime-only, compile-only, all")
    };
  }

  bool includedInCompilation() {
    return this != DependencyScope.runtimeOnly;
  }

  bool includedAtRuntime() {
    return this != DependencyScope.compileOnly;
  }

  String toYaml(AnsiColor color) {
    return color(
        switch (this) {
          runtimeOnly => '"runtime-only"',
          compileOnly => '"compile-only"',
          all => '"all"',
        },
        strColor);
  }
}

/// Specification of a dependency.
class DependencySpec {
  final bool transitive;
  final DependencyScope scope;
  final String? path;

  static const DependencySpec defaultSpec =
      DependencySpec(transitive: true, scope: DependencyScope.all);

  const DependencySpec({
    required this.transitive,
    required this.scope,
    this.path,
  });

  static DependencySpec fromMap(Map<String, Object?> map) {
    if (map.keys.any(const {'transitive', 'scope', 'path'}.contains.not$)) {
      throw DartleException(
          message: 'invalid dependency definition, '
              'only "transitive", "path" and "scope" fields can be set: $map');
    }
    return DependencySpec(
        transitive: _boolValue(map, 'transitive', true, type: 'Dependency'),
        scope: _scopeValue(map, 'scope', DependencyScope.all),
        path: _optionalStringValue(map, 'path', type: 'Dependency')
            .removeFromEnd(const {'/', '\\'}));
  }

  Future<PathDependency>? toPathDependency() {
    final thisPath = path;
    if (thisPath == null) return null;
    return FileSystemEntity.isFile(thisPath).then((isFile) => isFile
        ? PathDependency.jar(this, thisPath)
        : PathDependency.jbuildProject(this, thisPath));
  }

  @override
  String toString() =>
      'DependencySpec{transitive: $transitive, scope: $scope, path: $path}';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DependencySpec &&
          runtimeType == other.runtimeType &&
          transitive == other.transitive &&
          scope == other.scope &&
          path == other.path;

  @override
  int get hashCode => transitive.hashCode ^ scope.hashCode ^ path.hashCode;

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

SourceControlManagement _scmFromMap(Map<String, Object?> map) {
  if (map.keys
      .any(const {'connection', 'developer-connection', 'url'}.contains.not$)) {
    throw DartleException(
        message: 'invalid "scm" definition, '
            'only "connection", "developer-connection" and "url" '
            'fields can be set: $map');
  }
  return SourceControlManagement(
      connection: _mandatoryValue(map, 'connection', 'Scm'),
      developerConnection: _mandatoryValue(map, 'developer-connection', 'Scm'),
      url: _mandatoryValue(map, 'url', 'Scm'));
}

Developer _developerFromMap(Map<String, Object?> map) {
  if (map.keys.any(const {'name', 'email', 'organization', 'organization-url'}
      .contains
      .not$)) {
    throw DartleException(
        message: 'invalid "developer" definition, '
            'only "name", "email", "organization" and "organization-url" '
            'fields can be set: $map');
  }
  return Developer(
    name: _mandatoryValue(map, 'name', 'Developer'),
    email: _mandatoryValue(map, 'email', 'Developer'),
    organization: _mandatoryValue(map, 'organization', 'Developer'),
    organizationUrl: _mandatoryValue(map, 'organization-url', 'Developer'),
  );
}

String _mandatoryValue(Map<String, Object?> map, String key, String type) {
  return map[key]
      .vmap((name) => _stringValue(map, key, null, type: type).value);
}

bool _boolValue(Map<String, Object?> map, String key, bool defaultValue,
    {String? type}) {
  final value = map[key];
  if (value == null) return defaultValue;
  if (value is bool) {
    return value;
  }
  if (value is String) {
    if (const {'true', 'True', 'yes', 'Yes'}.contains(value)) {
      return true;
    }
    if (const {'false', 'False', 'no', 'No'}.contains(value)) {
      return false;
    }
  }
  final prefix = type == null ? '' : 'on $type: ';
  throw DartleException(
      message:
          "${prefix}expecting a boolean value for '$key', but got '$value'.");
}

_Value<String> _stringValue(
    Map<String, Object?> map, String key, String? defaultValue,
    {String? type}) {
  final value = map[key];
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
  final value = map[key];
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

DependencyScope _scopeValue(
    Map<String, Object?> map, String key, DependencyScope defaultValue) {
  final value = map[key];
  if (value == null) return defaultValue;
  if (value is String) {
    return DependencyScope.fromName(value);
  }
  throw DartleException(
      message: "on Dependency: expecting a String value for '$key', "
          "but got '$value'.");
}

_Value<Iterable<String>> _stringIterableValue(
    Map<String, Object?> map, String key, Iterable<String> defaultValue,
    {String? type}) {
  final value = map[key];
  bool isDefault = false;
  Iterable<String> result;
  if (value == null) {
    isDefault = true;
    result = defaultValue;
  } else if (value is Iterable) {
    result = value.map((e) {
      if (e == null || e is Iterable || e is Map) {
        final prefix = type == null ? '' : 'on $type: ';
        throw DartleException(
            message: "${prefix}expecting a list of String values for '$key', "
                "but got element '$e'.");
      }
      return e.toString();
    });
  } else if (value is String) {
    result = {value};
  } else {
    final prefix = type == null ? '' : 'on $type: ';
    throw DartleException(
        message: "${prefix}expecting a list of String values for '$key', "
            "but got '$value'.");
  }
  return _Value(isDefault, result);
}

_Value<Map<String, String>> _stringMapValue(
    Map<String, Object?> map, String key, Map<String, String> defaultValue) {
  final value = map[key];
  bool isDefault = false;
  Map<String, String> result;
  if (value == null) {
    result = defaultValue;
    isDefault = true;
  } else if (value is Map) {
    result = value.map((key, value) {
      if (value == null || value is Iterable || value is Map) {
        throw DartleException(
            message: "expecting a Map with String values for '$key', "
                "but got $key => '$value'.");
      }
      return MapEntry(key.toString(), value.toString());
    });
  } else {
    throw DartleException(
        message: "expecting a Map with String values for '$key', "
            "but got '$value'.");
  }
  return _Value(isDefault, result);
}

CompileOutput? _compileOutputValue(
    Map<String, Object?> map, String dirKey, String jarKey) {
  final dir = map[dirKey];
  final jar = map[jarKey];
  if (dir == null && jar == null) {
    return null;
  }
  if (dir != null) {
    if (dir is String) {
      return CompileOutput.dir(dir);
    }
    throw DartleException(
        message: "expecting a String value for '$dirKey', "
            "but got '$dir'.");
  }
  if (jar is String) {
    return CompileOutput.jar(jar);
  }
  throw DartleException(
      message: "expecting a String value for '$jarKey', "
          "but got '$jar'.");
}

const dependenciesSyntaxHelp = '''
Use the following syntax to declare dependencies:

  dependencies:
    - first:dep:1.0
    - another:dep:2.0:
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

_Value<Map<String, DependencySpec>> _dependencies(Map<String, Object?> map,
    String key, Map<String, DependencySpec> defaultValue) {
  final value = map[key];
  Map<String, DependencySpec> result;
  bool isDefault = false;
  if (value == null) {
    result = defaultValue;
    isDefault = true;
  } else if (value is List) {
    final map = <String, DependencySpec>{};
    for (final entry in value) {
      if (entry is String) {
        map[entry] = DependencySpec.defaultSpec;
      } else if (entry is Map<String, Object?>) {
        _addMapDependencyTo(map, entry);
      } else {
        throw DartleException(
            message: 'bad dependency declaration, '
                "expected String or Map value, got '$entry'.\n"
                "$dependenciesSyntaxHelp");
      }
    }
    result = map;
  } else {
    throw DartleException(
        message: "'$key' should be a List.\n"
            "$dependenciesSyntaxHelp");
  }
  return _Value(isDefault, result);
}

void _addMapDependencyTo(
    Map<String, DependencySpec> map, Map<String, Object?> entry) {
  if (entry.length != 1) {
    throw DartleException(
        message: "bad dependency declaration: '$entry'.\n"
            '$dependenciesSyntaxHelp');
  }
  final dep = entry.entries.first;
  map[dep.key] = _dependencySpec(dep.value);
}

DependencySpec _dependencySpec(Object? value) {
  if (value == null) {
    return DependencySpec.defaultSpec;
  }
  if (value is Map<String, Object?>) {
    return DependencySpec.fromMap(value);
  }
  throw DartleException(
      message: "bad dependency attributes declaration: '$value'.\n"
          "$dependenciesSyntaxHelp");
}

CompileOutput _defaultOutputValue() {
  return CompileOutput.jar(
      p.join('build', '${p.basename(Directory.current.path)}.jar'));
}

SourceControlManagement? _scm(Map<String, Object?> map) {
  final value = map['scm'];
  if (value == null) return null;
  if (value is Map<String, Object?>) {
    return _scmFromMap(value);
  }
  throw DartleException(
      message: "bad scm declaration: '$value'.\n"
          "$scmSyntaxHelp");
}

List<Developer> _developers(Map<String, Object?> map) {
  final value = map['developers'];
  if (value == null) return const [];
  if (value is List<Object?>) {
    return value.map((item) {
      if (item is Map<String, Object?>) {
        return _developerFromMap(item);
      }
      throw DartleException(
          message: "bad developer item declaration: '$item'.\n"
              "$developerSyntaxHelp");
    }).toList(growable: false);
  }
  throw DartleException(
      message: "bad developers declaration: '$value'.\n"
          "$developerSyntaxHelp");
}

List<ExtensionTask> _extensionTasks(Map<String, Object?> map) {
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
    inputs: [file1.txt, *.java]             (optional)
    outputs [output-dir/*.class, other.txt] (optional)
  other-task:
    class-name: my.java.OtherClass
''';

ExtensionTask _extensionTask(MapEntry<String, Object?> task) {
  final spec = task.value;
  if (spec is Map<String, Object?>) {
    return ExtensionTask(
      name: task.key,
      description: _stringValue(spec, 'description', '', type: 'Task').value,
      phase: _taskPhase(spec['phase']),
      inputs: _stringIterableValue(spec, 'inputs', const {}, type: 'Task')
          .value
          .toSet(),
      outputs: _stringIterableValue(spec, 'outputs', const {}, type: 'Task')
          .value
          .toSet(),
      dependsOn:
          _stringIterableValue(spec, 'depends-on', const {}, type: 'Task')
              .value
              .toSet(),
      dependents:
          _stringIterableValue(spec, 'dependents', const {}, type: 'Task')
              .value
              .toSet(),
      className: _optionalStringValue(spec, 'class-name', type: 'Task')
          .orThrow(() => DartleException(
              message: "declaration of task '${task.key}' is missing mandatory "
                  "'class-name'.\n$taskSyntaxHelp")),
      methodName: _stringValue(spec, 'method-name', 'run', type: 'Task').value,
    );
  } else {
    throw DartleException(
        message: 'bad task declaration, '
            "expected String or Map value, got '$task'.\n"
            "$taskSyntaxHelp");
  }
}

final _defaultPhaseIndex = TaskPhase.build.index + 10;

const _phaseHelpMessage = '''
To declare an existing phase or a custom phase that runs after the 'build' phase:
  phase: phase-name
Use the following syntax to declare custom phases:
  phase:
    # phase name:  phase index
    my-phase-name: 700
''';

TaskPhase _taskPhase(Object? phase) {
  if (phase == null) return TaskPhase.build;
  if (phase is String) {
    final builtIn = TaskPhase.builtInPhases.where((p) => p.name == phase);
    if (builtIn.isNotEmpty) return builtIn.first;
    return TaskPhase.custom(_defaultPhaseIndex, phase);
  }
  if (phase is Map) {
    if (phase.length != 1) {
      throw DartleException(
          message: 'invalid custom phase declaration.\n$_phaseHelpMessage');
    }

    final name = phase.keys.first.toString();
    final index = phase.values.first;
    if (index is int) {
      return TaskPhase.custom(index, name);
    }
    throw DartleException(
        message: "phase '$name' has an invalid index.\n$_phaseHelpMessage");
  }
  throw DartleException(
      message: 'invalid custom phase declaration.\n$_phaseHelpMessage');
}
