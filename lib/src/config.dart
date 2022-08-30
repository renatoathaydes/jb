import 'dart:io';

import 'package:dartle/dartle.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:jbuild_cli/src/utils.dart';
import 'package:logging/logging.dart' as log;
import 'package:path/path.dart' as path;

import 'utils.dart';

part 'config.freezed.dart';

final logger = log.Logger('jbuild');

class JBuildFiles {
  final File jbuildJar;
  final File configFile;
  final Directory tempDir = Directory('.jbuild-cache/tmp');

  JBuildFiles(this.jbuildJar, this.configFile);
}

@freezed
class JBuildConfiguration with _$JBuildConfiguration {
  const JBuildConfiguration._();

  const factory JBuildConfiguration({
    required Set<String> sourceDirs,
    required Set<String> classpath,
    required CompileOutput output,
    required Set<String> resourceDirs,
    required String mainClass,
    required List<String> javacArgs,
    required Set<String> repositories,
    required Map<String, DependencySpec> dependencies,
    required Set<String> exclusions,
  }) = _Config;

  static JBuildConfiguration fromMap(Map<String, Object?> map) {
    return JBuildConfiguration(
      sourceDirs: _stringIterableValue(map, 'source-dirs', const {}).toSet(),
      classpath: _stringIterableValue(map, 'classpath', const {}).toSet(),
      output: _compileOutputValue(map, 'output-dir', 'output-jar') ??
          _defaultOutputValue(),
      resourceDirs:
          _stringIterableValue(map, 'resource-dirs', const {}).toSet(),
      mainClass: _stringValue(map, 'main-class', ''),
      javacArgs: _stringIterableValue(map, 'javac-args', const [])
          .toList(growable: false),
      dependencies: _dependencies(map, 'dependencies', const {}),
      repositories: _stringIterableValue(map, 'repositories', const {}).toSet(),
      exclusions:
          _stringIterableValue(map, 'exclusion-patterns', const {}).toSet(),
    );
  }

  List<String> preArgs() {
    if (repositories.isNotEmpty) {
      return repositories.expand((r) => ['-r', r]).toList();
    }
    return const [];
  }

  List<String> compileArgs() {
    final result = <String>[];
    result.addAll(sourceDirs);
    for (final cp in classpath) {
      result.addAll(['-cp', cp]);
    }
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

  List<String> installForCompilationArgs() {
    final result = <String>[];
    for (final exclude in exclusions) {
      result.add('--exclusion');
      result.add(exclude);
    }
    dependencies.forEach((dependency, spec) {
      if (spec.scope != DependencyScope.runtimeOnly) {
        result.add(dependency);
      }
    });
    return result;
  }
}

@freezed
class CompileOutput with _$CompileOutput {
  const factory CompileOutput.dir(String directory) = Dir;

  const factory CompileOutput.jar(String jar) = Jar;
}

enum DependencyScope { all, compileOnly, runtimeOnly }

@freezed
class DependencySpec with _$DependencySpec {
  const DependencySpec._();

  static const DependencySpec defaultSpec =
      DependencySpec(transitive: true, scope: DependencyScope.all);

  const factory DependencySpec({
    required bool transitive,
    required DependencyScope scope,
  }) = _DependencySpec;

  static DependencySpec fromMap(Map<String, Object?> map) {
    if (map.keys.any(const {'transitive', 'scope'}.contains.not)) {
      throw DartleException(
          message: 'invalid dependency definition, '
              'only "transitive" and "scope" fields can be set: $map');
    }
    return DependencySpec(
        transitive: _boolValue(map, 'transitive', true),
        scope: _scopeValue(map, 'scope', DependencyScope.all));
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

String _stringValue(Map<String, Object?> map, String key, String defaultValue) {
  final value = map[key];
  if (value == null) return defaultValue;
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
    // value is not even an Iterable!!!
    return value.map((e) {
      if (e == null || e is Iterable || e is Map) {
        throw DartleException(
            message: "expecting a list of String values for '$key', "
                "but got '$e'.");
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
      } else if (entry is Map) {
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

void _addMapDependencyTo(Map<String, DependencySpec> map, Map entry) {
  if (entry.length != 1) {
    throw DartleException(
        message: "bad dependency declaration: '$entry'.\n"
            '$dependenciesSyntaxHelp');
  }
  final dep = entry.entries.first;
  map[dep.key as String] = _dependencySpec(dep.value);
}

DependencySpec _dependencySpec(value) {
  if (value == null) {
    return DependencySpec.defaultSpec;
  }
  if (value is Map) {
    return DependencySpec.fromMap(asJsonMap(value));
  }
  throw DartleException(
      message: "bad dependency attributes declaration: '$value'.\n"
          "$dependenciesSyntaxHelp");
}

CompileOutput _defaultOutputValue() {
  return CompileOutput.jar('${path.basename(Directory.current.path)}.jar');
}
