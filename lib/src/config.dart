import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:dartle/dartle.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:jbuild_cli/src/utils.dart';
import 'package:logging/logging.dart' as log;
import 'package:yaml/yaml.dart';

part 'config.freezed.dart';

final logger = log.Logger('jbuild');

@freezed
class CompileConfiguration with _$CompileConfiguration {
  const CompileConfiguration._();

  const factory CompileConfiguration({
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

  static CompileConfiguration fromMap(Map<String, Object?> map) {
    return CompileConfiguration(
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

  const factory DependencySpec({
    required bool transitive,
    required DependencyScope scope,
  }) = _DependencySpec;

  static DependencySpec fromMap(Map<String, Object?> map) {
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
      message: "expecting a boolean value for '$key', "
          "but got '$value'");
}

String _stringValue(Map<String, Object?> map, String key, String defaultValue) {
  final value = map[key];
  if (value == null) return defaultValue;
  if (value is String) {
    return value;
  }
  throw DartleException(
      message: "expecting a String value for '$key', "
          "but got '$value'");
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
              "but got '$value'");
    });
  }
  throw DartleException(
      message: "expecting a String value for '$key', "
          "but got '$value'");
}

Iterable<String> _stringIterableValue(
    Map<String, Object?> map, String key, Iterable<String> defaultValue) {
  final value = map[key];
  if (value == null) return defaultValue;
  if (value is YamlList) {
    // value is not even an Iterable!!!
    return value.map((e) {
      if (e == null || e is Iterable || e is Map) {
        throw DartleException(
            message: "expecting a list of String values for '$key', "
                "but got item which has type ${e?.runtimeType}: '$e'");
      }
      return e.toString();
    });
  }
  throw DartleException(
      message: "expecting a list of String values for '$key', "
          "but got '$value' which has type ${value.runtimeType}");
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
            "but got '$dir'");
  }
  if (jar is String) {
    return CompileOutput.jar(jar);
  }
  throw DartleException(
      message: "expecting a String value for '$jarKey', "
          "but got '$jar'");
}

Map<String, DependencySpec> _dependencies(Map<String, Object?> map, String key,
    Map<String, DependencySpec> defaultValue) {
  final value = map[key];
  if (value == null) return defaultValue;
  if (value is Map) {
    final deps = asJsonMap(value);
    return deps.map((key, value) => MapEntry(
        key, DependencySpec.fromMap(_mapValue(value, 'dependencies->value'))));
  }
  throw DartleException(
      message: "expecting a Map value for '$key', "
          "but got '$value'");
}

Map<String, Object?> _mapValue(dynamic value, String key) {
  if (value == null) {
    return const {};
  }
  if (value is Map) {
    return asJsonMap(value);
  }
  throw DartleException(
      message: "expecting a Map value for '$key', "
          "but got '$value'");
}

CompileOutput _defaultOutputValue() {
  return CompileOutput.jar('${path.basename(Directory.current.path)}.jar');
}
