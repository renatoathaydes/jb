import 'dart:io';

import 'package:dartle/dartle.dart';
import 'package:logging/logging.dart' as log;
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import 'config_import.dart';
import 'path_dependency.dart';
import 'properties.dart';
import 'utils.dart';

final logger = log.Logger('jbuild');

/// Files and directories used by jb.
class JBuildFiles {
  final File jbuildJar;
  final File configFile = File('jbuild.yaml');
  final Directory tempDir = Directory('.jbuild-cache/tmp');

  JBuildFiles(this.jbuildJar);
}

/// Parse the YAML/JSON jbuild file.
///
/// Applies defaults and resolves properties and imports.
Future<JBuildConfiguration> loadConfig(File configFile) async {
  logger.fine(() => 'Reading config file: ${configFile.path}');
  return await loadConfigString(await configFile.readAsString());
}

/// Parse the YAML/JSON jbuild configuration.
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
        message: 'Expecting jbuild configuration to be a Map, '
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

/// jb configuration model.
class JBuildConfiguration {
  final String? group;
  final String? module;
  final String? version;
  final String? mainClass;
  final Set<String> sourceDirs;
  final bool defaultSourceDirs;
  final CompileOutput output;
  final bool defaultOutput;
  final Set<String> resourceDirs;
  final bool defaultResourceDirs;
  final List<String> javacArgs;
  final bool defaultJavacArgs;
  final List<String> runJavaArgs;
  final bool defaultRunJavaArgs;
  final List<String> testJavaArgs;
  final bool defaultTestJavaArgs;
  final Map<String, String> javacEnv;
  final bool defaultJavacEnv;
  final Map<String, String> runJavaEnv;
  final bool defaultRunJavaEnv;
  final Map<String, String> testJavaEnv;
  final bool defaultTestJavaEnv;
  final Set<String> repositories;
  final bool defaultRepositories;
  final Map<String, DependencySpec> dependencies;
  final bool defaultDependencies;
  final Set<String> exclusions;
  final bool defaultExclusions;
  final String compileLibsDir;
  final bool defaultCompileLibsDir;
  final String runtimeLibsDir;
  final bool defaultRuntimeLibsDir;
  final String testReportsDir;
  final bool defaultTestReportsDir;
  final Properties properties;

  const JBuildConfiguration({
    this.group,
    this.module,
    this.version,
    this.mainClass,
    this.defaultSourceDirs = false,
    this.defaultOutput = false,
    this.defaultResourceDirs = false,
    this.defaultJavacArgs = false,
    this.defaultRunJavaArgs = false,
    this.defaultTestJavaArgs = false,
    this.defaultJavacEnv = false,
    this.defaultRunJavaEnv = false,
    this.defaultTestJavaEnv = false,
    this.defaultRepositories = false,
    this.defaultDependencies = false,
    this.defaultExclusions = false,
    this.defaultCompileLibsDir = false,
    this.defaultRuntimeLibsDir = false,
    this.defaultTestReportsDir = false,
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
    required this.compileLibsDir,
    required this.runtimeLibsDir,
    required this.testReportsDir,
    this.properties = const {},
  });

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
      sourceDirs: sourceDirs.toSet(),
      defaultSourceDirs: sourceDirs.isDefault,
      output: output ?? _defaultOutputValue(),
      defaultOutput: output == null,
      resourceDirs: resourceDirs.toSet(),
      defaultResourceDirs: resourceDirs.isDefault,
      javacArgs: javacArgs.toList(),
      defaultJavacArgs: javacArgs.isDefault,
      runJavaArgs: runJavaArgs.toList(),
      defaultRunJavaArgs: runJavaArgs.isDefault,
      testJavaArgs: testJavaArgs.toList(),
      defaultTestJavaArgs: testJavaArgs.isDefault,
      javacEnv: javacEnv.value,
      defaultJavacEnv: javacEnv.isDefault,
      runJavaEnv: runJavaEnv.value,
      defaultRunJavaEnv: runJavaEnv.isDefault,
      testJavaEnv: testJavaEnv.value,
      defaultTestJavaEnv: testJavaEnv.isDefault,
      dependencies: dependencies.value,
      defaultDependencies: dependencies.isDefault,
      repositories: repositories.toSet(),
      defaultRepositories: repositories.isDefault,
      exclusions: exclusions.toSet(),
      defaultExclusions: exclusions.isDefault,
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
      sourceDirs: other.defaultSourceDirs
          ? sourceDirs.merge(const {}, props)
          : sourceDirs.merge(other.sourceDirs, props),
      defaultSourceDirs: defaultSourceDirs && other.defaultSourceDirs,
      output: (other.defaultOutput ? output : other.output)
          .resolveProperties(props),
      defaultOutput: defaultOutput && other.defaultOutput,
      resourceDirs: other.defaultResourceDirs
          ? resourceDirs.merge(const {}, props)
          : resourceDirs.merge(other.resourceDirs, props),
      defaultResourceDirs: defaultResourceDirs && other.defaultResourceDirs,
      javacArgs: other.defaultJavacArgs
          ? javacArgs.merge(const [], props)
          : javacArgs.merge(other.javacArgs, props),
      defaultJavacArgs: defaultJavacArgs && other.defaultJavacArgs,
      runJavaArgs: other.defaultRunJavaArgs
          ? runJavaArgs.merge(const [], props)
          : runJavaArgs.merge(other.runJavaArgs, props),
      defaultRunJavaArgs: defaultRunJavaArgs && other.defaultRunJavaArgs,
      testJavaArgs: other.defaultTestJavaArgs
          ? testJavaArgs.merge(const [], props)
          : testJavaArgs.merge(other.testJavaArgs, props),
      defaultTestJavaArgs: defaultTestJavaArgs && other.defaultTestJavaArgs,
      javacEnv: other.defaultJavacEnv
          ? javacEnv.merge(const {}, props)
          : javacEnv.merge(other.javacEnv, props),
      defaultJavacEnv: defaultJavacEnv && other.defaultJavacEnv,
      runJavaEnv: other.defaultRunJavaEnv
          ? runJavaEnv.merge(const {}, props)
          : runJavaEnv.merge(other.runJavaEnv, props),
      defaultRunJavaEnv: defaultRunJavaEnv && other.defaultRunJavaEnv,
      testJavaEnv: other.defaultTestJavaEnv
          ? testJavaEnv.merge(const {}, props)
          : testJavaEnv.merge(other.testJavaEnv, props),
      defaultTestJavaEnv: defaultTestJavaEnv && other.defaultTestJavaEnv,
      repositories: other.defaultRepositories
          ? repositories.merge(const {}, props)
          : repositories.merge(other.repositories, props),
      defaultRepositories: defaultRepositories && other.defaultRepositories,
      dependencies: other.defaultDependencies
          ? dependencies.merge(const {}, props)
          : dependencies.merge(other.dependencies, props),
      defaultDependencies: defaultDependencies && other.defaultDependencies,
      exclusions: other.defaultExclusions
          ? exclusions.merge(const {}, props)
          : exclusions.merge(other.exclusions, props),
      defaultExclusions: defaultExclusions && other.defaultExclusions,
      compileLibsDir: resolveString(
          other.defaultCompileLibsDir ? compileLibsDir : other.compileLibsDir,
          props),
      defaultCompileLibsDir:
          defaultCompileLibsDir && other.defaultCompileLibsDir,
      runtimeLibsDir: resolveString(
          other.defaultRuntimeLibsDir ? runtimeLibsDir : other.runtimeLibsDir,
          props),
      defaultRuntimeLibsDir:
          defaultRuntimeLibsDir && other.defaultRuntimeLibsDir,
      testReportsDir: resolveString(
          other.defaultTestReportsDir ? testReportsDir : other.testReportsDir,
          props),
      defaultTestReportsDir:
          defaultTestReportsDir && other.defaultTestReportsDir,
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
  List<String> compileArgs() {
    final result = <String>[];
    result.addAll(sourceDirs);
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
    if (javacArgs.isNotEmpty) {
      result.add('--');
      result.addAll(javacArgs);
    }
    return result;
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
    final depsToInstall = dependencies.entries
        .where((e) => e.value.scope.includedAtRuntime() && e.value.path == null)
        .map((e) => e.key)
        .toList(growable: false);

    if (depsToInstall.isEmpty) return const [];

    final result = ['-s', 'runtime', '-m', '-d', runtimeLibsDir];
    for (final exclude in exclusions) {
      result.add('--exclusion');
      result.add(exclude);
    }
    result.addAll(depsToInstall);
    return result;
  }
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
    return DependencyScope.values
        .firstWhere((enumValue) => enumValue.name == value, orElse: () {
      throw DartleException(
          message: "expecting one of ${DependencyScope.values} for '$key', "
              "but got '$value'.");
    });
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
  return CompileOutput.jar('build/${p.basename(Directory.current.path)}.jar');
}
