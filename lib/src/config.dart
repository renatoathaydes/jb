import 'dart:io';

import 'package:dartle/dartle.dart';
import 'package:logging/logging.dart' as log;
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

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

/// Parse the YAML/JSON jbuild fle.
JBuildConfiguration configFromJson(dynamic json) {
  if (json is Map) {
    final map = resolveConfigMap(json);
    return JBuildConfiguration.fromMap(map);
  } else {
    throw DartleException(
        message: 'Expecting jbuild configuration to be a Map, '
            'but it is ${json?.runtimeType}');
  }
}

/// jb configuration model.
class JBuildConfiguration {
  final String? group;
  final String? module;
  final String version;
  final Set<String> sourceDirs;
  final CompileOutput output;
  final Set<String> resourceDirs;
  final String mainClass;
  final List<String> javacArgs;
  final List<String> runJavaArgs;
  final List<String> testJavaArgs;
  final Map<String, String> javacEnv;
  final Map<String, String> runJavaEnv;
  final Map<String, String> testJavaEnv;
  final Set<String> repositories;
  final Map<String, DependencySpec> dependencies;
  final Set<String> exclusions;
  final String compileLibsDir;
  final String runtimeLibsDir;
  final String testReportsDir;

  const JBuildConfiguration({
    this.group,
    this.module,
    required this.version,
    required this.sourceDirs,
    required this.output,
    required this.resourceDirs,
    required this.mainClass,
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
  });

  static JBuildConfiguration fromMap(Map<String, Object?> map) {
    return JBuildConfiguration(
      group: _optionalStringValue(map, 'group'),
      module: _optionalStringValue(map, 'module'),
      version: _stringValue(map, 'version', '0.0.0'),
      sourceDirs:
          _stringIterableValue(map, 'source-dirs', const {'src/main/java'})
              .toSet(),
      output: _compileOutputValue(map, 'output-dir', 'output-jar') ??
          _defaultOutputValue(),
      resourceDirs: _stringIterableValue(
          map, 'resource-dirs', const {'src/main/resources'}).toSet(),
      mainClass: _stringValue(map, 'main-class', ''),
      javacArgs: _stringIterableValue(map, 'javac-args', const [])
          .toList(growable: false),
      runJavaArgs: _stringIterableValue(map, 'run-java-args', const [])
          .toList(growable: false),
      testJavaArgs: _stringIterableValue(map, 'test-java-args', const [])
          .toList(growable: false),
      javacEnv: _stringMapValue(map, 'javac-env', const {}),
      runJavaEnv: _stringMapValue(map, 'run-java-env', const {}),
      testJavaEnv: _stringMapValue(map, 'test-java-env', const {}),
      dependencies: _dependencies(map, 'dependencies', const {}),
      repositories: _stringIterableValue(map, 'repositories', const {}).toSet(),
      exclusions:
          _stringIterableValue(map, 'exclusion-patterns', const {}).toSet(),
      compileLibsDir:
          _stringValue(map, 'compile-libs-dir', 'build/compile-libs'),
      runtimeLibsDir:
          _stringValue(map, 'runtime-libs-dir', 'build/runtime-libs'),
      testReportsDir:
          _stringValue(map, 'test-reports-dir', 'build/test-reports'),
    );
  }

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
    if (mainClass.isNotEmpty) {
      result.addAll(['-m', mainClass]);
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

  const CompileOutput.dir(String directory)
      : _value = directory,
        _tag = _CompileOutputTag.dir;

  const CompileOutput.jar(String jar)
      : _value = jar,
        _tag = _CompileOutputTag.jar;

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

String _stringValue(Map<String, Object?> map, String key, String defaultValue) {
  final value = map[key];
  if (value == null) return defaultValue;
  if (value is String) {
    return value;
  }
  throw DartleException(
      message: "expecting a String value for '$key', but got '$value'.");
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

Iterable<String> _stringIterableValue(
    Map<String, Object?> map, String key, Iterable<String> defaultValue) {
  final value = map[key];
  if (value == null) return defaultValue;
  if (value is Iterable) {
    return value.map((e) {
      if (e == null || e is Iterable || e is Map) {
        throw DartleException(
            message: "expecting a list of String values for '$key', "
                "but got element '$e'.");
      }
      return e.toString();
    });
  }
  if (value is String) {
    return {value};
  }
  throw DartleException(
      message: "expecting a list of String values for '$key', "
          "but got '$value'.");
}

Map<String, String> _stringMapValue(
    Map<String, Object?> map, String key, Map<String, String> defaultValue) {
  final value = map[key];
  if (value == null) return defaultValue;
  if (value is Map) {
    return value.map((key, value) {
      if (value == null || value is Iterable || value is Map) {
        throw DartleException(
            message: "expecting a Map with String values for '$key', "
                "but got $key => '$value'.");
      }
      return MapEntry(key.toString(), value.toString());
    });
  }
  throw DartleException(
      message: "expecting a Map with String values for '$key', "
          "but got '$value'.");
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

Map<String, DependencySpec> _dependencies(Map<String, Object?> map, String key,
    Map<String, DependencySpec> defaultValue) {
  final value = map[key];
  if (value == null) return defaultValue;
  if (value is List) {
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
    return map;
  }
  throw DartleException(
      message: "'$key' should be a List.\n"
          "$dependenciesSyntaxHelp");
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
