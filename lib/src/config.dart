import 'dart:io';

import 'package:dartle/dartle.dart';
import 'package:dartle/dartle_cache.dart' show ChangeKind;
import 'package:logging/logging.dart' as log;
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import 'config_import.dart';
import 'file_tree.dart';
import 'path_dependency.dart';
import 'properties.dart';
import 'sub_project.dart';
import 'utils.dart';

final logger = log.Logger('jbuild');

const jbuildCache = '.jbuild-cache';

const jbApi = 'com.athaydes.jbuild:jbuild-api';

/// Files and directories used by jb.
class JBuildFiles {
  final File jbuildJar;

  File get configFile => File('jbuild.yaml');

  File get dependenciesFile => File(p.join(jbuildCache, 'dependencies.txt'));

  File get javaSrcFileTreeFile =>
      File(p.join(jbuildCache, 'java-src-file-tree.txt'));

  Directory get jbExtensionProjectDir => Directory('jb-extension');

  File get processorDependenciesFile =>
      File(p.join(jbuildCache, 'processor-dependencies.txt'));
  final processorLibsDir = p.join(jbuildCache, 'processor-dependencies');

  JBuildFiles(this.jbuildJar);
}

/// Parse the YAML/JSON jbuild file.
///
/// Applies defaults and resolves properties and imports.
Future<JBuildConfiguration> loadConfig(File configFile) async {
  logger.fine(() {
    final path = p.isAbsolute(configFile.path)
        ? configFile.path
        : p.join(Directory.current.path, configFile.path);
    return 'Reading config file: $path';
  });
  return await loadConfigString(await configFile.readAsString());
}

/// Parse the YAML/JSON jb configuration.
///
/// Applies defaults and resolves properties and imports.
Future<JBuildConfiguration> loadConfigString(String config) async {
  final json = loadYaml(config);
  if (json is Map) {
    final resolvedMap = resolvePropertiesFromMap(json);
    final imports = resolvedMap.map.remove('imports');
    return await JBuildConfiguration.fromMap(
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
Future<JBuildExtensionModel> loadJbExtensionModel(
    String config, Uri yamlUri) async {
  final json = loadYaml(config, sourceUrl: yamlUri);
  if (json is Map) {
    final resolvedMap = resolvePropertiesFromMap(json);
    return JBuildExtensionModel.fromMap(
        resolvedMap.map, resolvedMap.properties);
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
class JBuildExtensionModel {
  final List<ExtensionTask> extensionTasks;

  const JBuildExtensionModel(this.extensionTasks);

  static JBuildExtensionModel fromMap(Map<String, Object?> map,
      [Properties properties = const {}]) {
    final extensionTasks = _extensionTasks(map);
    return JBuildExtensionModel(extensionTasks);
  }
}

/// jb configuration model.
class JBuildConfiguration {
  final String? group;
  final String? module;
  final String? version;
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
  final Set<String> exclusions;
  final Map<String, DependencySpec> processorDependencies;
  final Set<String> processorDependenciesExclusions;
  final String compileLibsDir;
  final bool _defaultCompileLibsDir;
  final String runtimeLibsDir;
  final bool _defaultRuntimeLibsDir;
  final String testReportsDir;
  final bool _defaultTestReportsDir;
  final Properties properties;

  const JBuildConfiguration({
    this.group,
    this.module,
    this.version,
    this.mainClass,
    this.extensionProject,
    bool defaultSourceDirs = false,
    bool defaultOutput = false,
    bool defaultResourceDirs = false,
    bool defaultCompileLibsDir = false,
    bool defaultRuntimeLibsDir = false,
    bool defaultTestReportsDir = false,
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
    required this.exclusions,
    required this.processorDependencies,
    required this.processorDependenciesExclusions,
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

  /// Create a [JBuildConfiguration] from a map.
  /// This method does not do any processing or validation of values, it simply
  /// reads values from the Map and includes defaults where needed.
  ///
  /// The optional [Properties] argument is stored within the returned
  /// [JBuildConfiguration] but is not used to resolve properties values
  /// (it only gets used when the returned configuration is merged with another).
  /// That's expected to already have been done before calling this method.
  static JBuildConfiguration fromMap(Map<String, Object?> map,
      [Properties properties = const {}]) {
    final sourceDirs =
        _stringIterableValue(map, 'source-dirs', const {'src/main/java'});
    final output = _compileOutputValue(map, 'output-dir', 'output-jar');
    final resourceDirs = _stringIterableValue(
        map, 'resource-dirs', const {'src/main/resources'});
    final javacArgs = _stringIterableValue(map, 'javac-args', const []);
    final runJavaArgs = _stringIterableValue(map, 'run-java-args', const []);
    final testJavaArgs = _stringIterableValue(map, 'test-java-args', const []);
    final javacEnv = _stringMapValue(map, 'javac-env', const {});
    final runJavaEnv = _stringMapValue(map, 'run-java-env', const {});
    final testJavaEnv = _stringMapValue(map, 'test-java-env', const {});
    final dependencies = _dependencies(map, 'dependencies', const {});
    final repositories = _stringIterableValue(map, 'repositories', const {});
    final exclusions =
        _stringIterableValue(map, 'exclusion-patterns', const {});
    final processorDependencies =
        _dependencies(map, 'processor-dependencies', const {});
    final processorDependenciesExclusions = _stringIterableValue(
        map, 'processor-dependencies-exclusions', const {});
    final compileLibsDir =
        _stringValue(map, 'compile-libs-dir', 'build/compile-libs');
    final runtimeLibsDir =
        _stringValue(map, 'runtime-libs-dir', 'build/runtime-libs');
    final testReportsDir =
        _stringValue(map, 'test-reports-dir', 'build/test-reports');

    return JBuildConfiguration(
      group: _optionalStringValue(map, 'group'),
      module: _optionalStringValue(map, 'module'),
      version: _optionalStringValue(map, 'version'),
      mainClass: _optionalStringValue(map, 'main-class'),
      extensionProject: _optionalStringValue(map, 'extension-project'),
      sourceDirs: sourceDirs.toSet(),
      defaultSourceDirs: sourceDirs.isDefault,
      output: output ?? _defaultOutputValue(),
      defaultOutput: output == null,
      resourceDirs: resourceDirs.toSet(),
      defaultResourceDirs: resourceDirs.isDefault,
      javacArgs: javacArgs.toList(),
      runJavaArgs: runJavaArgs.toList(),
      testJavaArgs: testJavaArgs.toList(),
      javacEnv: javacEnv.value,
      runJavaEnv: runJavaEnv.value,
      testJavaEnv: testJavaEnv.value,
      dependencies: dependencies.value,
      repositories: repositories.toSet(),
      exclusions: exclusions.toSet(),
      processorDependencies: processorDependencies.value,
      processorDependenciesExclusions: processorDependenciesExclusions.toSet(),
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
  JBuildConfiguration merge(JBuildConfiguration other) {
    final props = properties.union(other.properties);

    return JBuildConfiguration(
      group: resolveOptionalString(other.group ?? group, props),
      module: resolveOptionalString(other.module ?? module, props),
      version: resolveOptionalString(other.version ?? version, props),
      mainClass: resolveOptionalString(other.mainClass ?? mainClass, props),
      extensionProject: resolveOptionalString(
          other.extensionProject ?? extensionProject, props),
      sourceDirs: other._defaultSourceDirs
          ? sourceDirs.merge(const {}, props)
          : sourceDirs.merge(other.sourceDirs, props),
      defaultSourceDirs: _defaultSourceDirs && other._defaultSourceDirs,
      output: (other._defaultOutput ? output : other.output)
          .resolveProperties(props),
      defaultOutput: _defaultOutput && other._defaultOutput,
      resourceDirs: other._defaultResourceDirs
          ? resourceDirs.merge(const {}, props)
          : resourceDirs.merge(other.resourceDirs, props),
      defaultResourceDirs: _defaultResourceDirs && other._defaultResourceDirs,
      javacArgs: javacArgs.merge(other.javacArgs, props),
      runJavaArgs: runJavaArgs.merge(other.runJavaArgs, props),
      testJavaArgs: testJavaArgs.merge(other.testJavaArgs, props),
      javacEnv: javacEnv.merge(other.javacEnv, props),
      runJavaEnv: runJavaEnv.merge(other.runJavaEnv, props),
      testJavaEnv: testJavaEnv.merge(other.testJavaEnv, props),
      repositories: repositories.merge(other.repositories, props),
      dependencies: dependencies.merge(other.dependencies, props),
      exclusions: exclusions.merge(other.exclusions, props),
      processorDependencies:
          processorDependencies.merge(other.processorDependencies, props),
      processorDependenciesExclusions: processorDependenciesExclusions.merge(
          other.processorDependenciesExclusions, props),
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
    var result = const <String>[];
    if (logger.isLoggable(Level.FINE)) {
      result = const ['-V'];
    }
    if (repositories.isNotEmpty) {
      final args = List.filled(result.length + 2 * repositories.length, '');
      var index = 0;
      for (final arg in result) {
        args[index++] = arg;
      }
      for (final repo in repositories) {
        args[index++] = '-r';
        args[index++] = repo;
      }
      result = args;
    }
    return result;
  }

  /// Get the compile task arguments from this configuration.
  Future<List<String>> compileArgs(
      String processorLibsDir, TransitiveChanges? changes) async {
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
        (await Directory(processorLibsDir).toClasspath()).map(result.add);
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
    for (final exclude in exclusions) {
      result.add('--exclusion');
      result.add(exclude);
    }
    result.addAll(depsToInstall);
    return result;
  }

  /// Get the install arguments for the installRuntime task from this configuration.
  List<String> installArgsForRuntime() {
    return _installArgs(dependencies, exclusions, runtimeLibsDir);
  }

  /// Get the install arguments for the installProcessor task from this configuration.
  List<String> installArgsForProcessor(String destinationDir) {
    return _installArgs(
        processorDependencies, processorDependenciesExclusions, destinationDir);
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

  @override
  String toString() {
    return 'JBuildConfiguration{group: $group, '
        'module: $module, version: $version, mainClass: $mainClass, '
        'extensionProject: $extensionProject, sourceDirs: $sourceDirs, '
        'output: $output, resourceDirs: $resourceDirs, javacArgs: $javacArgs, '
        'runJavaArgs: $runJavaArgs, testJavaArgs: $testJavaArgs, '
        'javacEnv: $javacEnv, runJavaEnv: $runJavaEnv, '
        'testJavaEnv: $testJavaEnv, repositories: $repositories, '
        'dependencies: $dependencies, exclusions: $exclusions, '
        'processorDependencies: $processorDependencies, '
        'processorDependenciesExclusions: $processorDependenciesExclusions, '
        'compileLibsDir: $compileLibsDir, runtimeLibsDir: $runtimeLibsDir, '
        'testReportsDir: $testReportsDir, properties: $properties}';
  }
}

/// Grouping of all local dependencies, which can be local
/// [JarDependency] or [SubProject]s.
class LocalDependencies {
  final List<JarDependency> jars;
  final List<SubProject> subProjects;

  const LocalDependencies(this.jars, this.subProjects);

  bool get isEmpty => jars.isEmpty && subProjects.isEmpty;

  LocalDependenciesConfig toConfig() => LocalDependenciesConfig(jars,
      subProjects.map((e) => e.toSubProjectConfig()).toList(growable: false));
}

/// Sendable subset of [LocalDependencies].
class LocalDependenciesConfig {
  final List<JarDependency> jars;
  final List<SubProjectConfig> subProjects;

  const LocalDependenciesConfig(this.jars, this.subProjects);

  bool get isEmpty => jars.isEmpty && subProjects.isEmpty;
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
  String toString() => 'CompileOutput{_tag: $_tag, _value: $_value}';
}

/// Scope of a dependency.
enum DependencyScope {
  all,
  compileOnly,
  runtimeOnly;

  /// Convert a String to a [DependencyScope].
  static DependencyScope fromName(String name) {
    switch (name) {
      case 'runtime-only':
        return runtimeOnly;
      case 'compile-only':
        return compileOnly;
      case 'all':
        return all;
      default:
        throw DartleException(
            message: "Invalid scope: '$name'. "
                "Valid names are: runtime-only, compile-only, all");
    }
  }

  bool includedInCompilation() {
    return this != DependencyScope.runtimeOnly;
  }

  bool includedAtRuntime() {
    return this != DependencyScope.compileOnly;
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
    if (map.keys.any(const {'transitive', 'scope', 'path'}.contains.not)) {
      throw DartleException(
          message: 'invalid dependency definition, '
              'only "transitive", "path" and "scope" fields can be set: $map');
    }
    return DependencySpec(
        transitive: _boolValue(map, 'transitive', true),
        scope: _scopeValue(map, 'scope', DependencyScope.all),
        path:
            _optionalStringValue(map, 'path').removeFromEnd(const {'/', '\\'}));
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
}

bool _boolValue(Map<String, Object?> map, String key, bool defaultValue) {
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
  throw DartleException(
      message: "expecting a boolean value for '$key', but got '$value'.");
}

_Value<String> _stringValue(
    Map<String, Object?> map, String key, String defaultValue) {
  final value = map[key];
  String result;
  bool isDefault = false;
  if (value == null) {
    result = defaultValue;
    isDefault = true;
  } else if (value is String) {
    result = value;
  } else {
    throw DartleException(
        message: "expecting a String value for '$key', but got '$value'.");
  }
  return _Value(isDefault, result);
}

String? _optionalStringValue(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value == null) return null;
  if (value is String) {
    return value;
  }
  throw DartleException(
      message: "expecting a String value for '$key', but got '$value'.");
}

DependencyScope _scopeValue(
    Map<String, Object?> map, String key, DependencyScope defaultValue) {
  final value = map[key];
  if (value == null) return defaultValue;
  if (value is String) {
    return DependencyScope.fromName(value);
  }
  throw DartleException(
      message: "expecting a String value for '$key', "
          "but got '$value'.");
}

_Value<Iterable<String>> _stringIterableValue(
    Map<String, Object?> map, String key, Iterable<String> defaultValue) {
  final value = map[key];
  bool isDefault = false;
  Iterable<String> result;
  if (value == null) {
    isDefault = true;
    result = defaultValue;
  } else if (value is Iterable) {
    result = value.map((e) {
      if (e == null || e is Iterable || e is Map) {
        throw DartleException(
            message: "expecting a list of String values for '$key', "
                "but got element '$e'.");
      }
      return e.toString();
    });
  } else if (value is String) {
    result = {value};
  } else {
    throw DartleException(
        message: "expecting a list of String values for '$key', "
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
        scope: runtimeOnly # or compileOnly or all
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
      description: _stringValue(spec, 'description', '').value,
      phase: _taskPhase(spec['phase']),
      inputs: _stringIterableValue(spec, 'inputs', const {}).value.toSet(),
      outputs: _stringIterableValue(spec, 'outputs', const {}).value.toSet(),
      dependsOn:
          _stringIterableValue(spec, 'depends-on', const {}).value.toSet(),
      dependents:
          _stringIterableValue(spec, 'dependents', const {}).value.toSet(),
      className: _optionalStringValue(spec, 'class-name')
          .orThrow("declaration of task '${task.key}' is missing mandatory "
              "'class-name'.\n$taskSyntaxHelp"),
      methodName: _stringValue(spec, 'method-name', 'run').value,
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
