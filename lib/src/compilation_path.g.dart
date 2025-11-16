import 'package:collection/collection.dart';
import 'dart:convert';
import 'package:schemake/schemake.dart';

/// Java compilation path.

final class CompilationPath {
  /// Java modules to be included the --module-path.
  final List<Module> modules;

  /// Java jars to be included in the --class-path.
  final List<Jar> jars;
  const CompilationPath({required this.modules, required this.jars});
  @override
  String toString() =>
      'CompilationPath{'
      'modules: $modules, '
      'jars: $jars'
      '}';
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CompilationPath &&
          runtimeType == other.runtimeType &&
          const ListEquality<Module>().equals(modules, other.modules) &&
          const ListEquality<Jar>().equals(jars, other.jars);
  @override
  int get hashCode =>
      const ListEquality<Module>().hash(modules) ^
      const ListEquality<Jar>().hash(jars);
  CompilationPath copyWith({List<Module>? modules, List<Jar>? jars}) {
    return CompilationPath(
      modules: modules ?? [...this.modules],
      jars: jars ?? [...this.jars],
    );
  }

  static CompilationPath fromJson(Object? value) =>
      const _CompilationPathJsonReviver().convert(switch (value) {
        String() => jsonDecode(value),
        List<int>() => jsonDecode(utf8.decode(value)),
        _ => value,
      });
  Map<String, Object?> toJson() => {'modules': modules, 'jars': jars};
}

/// Java Module information.

final class Module {
  final String javaVersion;
  final String path;
  final String name;
  final bool automatic;
  final String version;
  final String flags;
  final List<Requirement> requires;
  const Module({
    required this.javaVersion,
    required this.path,
    required this.name,
    required this.automatic,
    required this.version,
    required this.flags,
    required this.requires,
  });
  @override
  String toString() =>
      'Module{'
      'javaVersion: "$javaVersion", '
      'path: "$path", '
      'name: "$name", '
      'automatic: $automatic, '
      'version: "$version", '
      'flags: "$flags", '
      'requires: $requires'
      '}';
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Module &&
          runtimeType == other.runtimeType &&
          javaVersion == other.javaVersion &&
          path == other.path &&
          name == other.name &&
          automatic == other.automatic &&
          version == other.version &&
          flags == other.flags &&
          const ListEquality<Requirement>().equals(requires, other.requires);
  @override
  int get hashCode =>
      javaVersion.hashCode ^
      path.hashCode ^
      name.hashCode ^
      automatic.hashCode ^
      version.hashCode ^
      flags.hashCode ^
      const ListEquality<Requirement>().hash(requires);
  Module copyWith({
    String? javaVersion,
    String? path,
    String? name,
    bool? automatic,
    String? version,
    String? flags,
    List<Requirement>? requires,
  }) {
    return Module(
      javaVersion: javaVersion ?? this.javaVersion,
      path: path ?? this.path,
      name: name ?? this.name,
      automatic: automatic ?? this.automatic,
      version: version ?? this.version,
      flags: flags ?? this.flags,
      requires: requires ?? [...this.requires],
    );
  }

  static Module fromJson(Object? value) =>
      const _ModuleJsonReviver().convert(switch (value) {
        String() => jsonDecode(value),
        List<int>() => jsonDecode(utf8.decode(value)),
        _ => value,
      });
  Map<String, Object?> toJson() => {
    'javaVersion': javaVersion,
    'path': path,
    'name': name,
    'automatic': automatic,
    'version': version,
    'flags': flags,
    'requires': requires,
  };
}

/// Java Module information.

final class Jar {
  final String javaVersion;
  final String path;
  const Jar({required this.javaVersion, required this.path});
  @override
  String toString() =>
      'Jar{'
      'javaVersion: "$javaVersion", '
      'path: "$path"'
      '}';
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Jar &&
          runtimeType == other.runtimeType &&
          javaVersion == other.javaVersion &&
          path == other.path;
  @override
  int get hashCode => javaVersion.hashCode ^ path.hashCode;
  Jar copyWith({String? javaVersion, String? path}) {
    return Jar(
      javaVersion: javaVersion ?? this.javaVersion,
      path: path ?? this.path,
    );
  }

  static Jar fromJson(Object? value) =>
      const _JarJsonReviver().convert(switch (value) {
        String() => jsonDecode(value),
        List<int>() => jsonDecode(utf8.decode(value)),
        _ => value,
      });
  Map<String, Object?> toJson() => {'javaVersion': javaVersion, 'path': path};
}

class _CompilationPathJsonReviver extends ObjectsBase<CompilationPath> {
  const _CompilationPathJsonReviver()
    : super(
        "CompilationPath",
        unknownPropertiesStrategy: UnknownPropertiesStrategy.forbid,
      );

  @override
  CompilationPath convert(Object? value) {
    if (value is! Map) throw TypeException(CompilationPath, value);
    final keys = value.keys.map((key) {
      if (key is! String) {
        throw TypeException(String, key, "object key is not a String");
      }
      return key;
    }).toSet();
    checkRequiredProperties(keys);
    const knownProperties = {'modules', 'jars'};
    final unknownKey = keys
        .where((k) => !knownProperties.contains(k))
        .firstOrNull;
    if (unknownKey != null) {
      throw UnknownPropertyException([unknownKey], CompilationPath);
    }
    return CompilationPath(
      modules: convertProperty(
        const Arrays<Module, _ModuleJsonReviver>(_ModuleJsonReviver()),
        'modules',
        value,
      ),
      jars: convertProperty(
        const Arrays<Jar, _JarJsonReviver>(_JarJsonReviver()),
        'jars',
        value,
      ),
    );
  }

  @override
  Converter<Object?, Object?>? getPropertyConverter(String property) {
    switch (property) {
      case 'modules':
        return const Arrays<Module, _ModuleJsonReviver>(_ModuleJsonReviver());
      case 'jars':
        return const Arrays<Jar, _JarJsonReviver>(_JarJsonReviver());
      default:
        return null;
    }
  }

  @override
  Iterable<String> getRequiredProperties() {
    return const {'modules', 'jars'};
  }

  @override
  String toString() => 'CompilationPath';
}

/// A Java module requirement.

final class Requirement {
  final String module;
  final String version;
  final String flags;
  const Requirement({
    required this.module,
    required this.version,
    required this.flags,
  });
  @override
  String toString() =>
      'Requirement{'
      'module: "$module", '
      'version: "$version", '
      'flags: "$flags"'
      '}';
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Requirement &&
          runtimeType == other.runtimeType &&
          module == other.module &&
          version == other.version &&
          flags == other.flags;
  @override
  int get hashCode => module.hashCode ^ version.hashCode ^ flags.hashCode;
  Requirement copyWith({String? module, String? version, String? flags}) {
    return Requirement(
      module: module ?? this.module,
      version: version ?? this.version,
      flags: flags ?? this.flags,
    );
  }

  static Requirement fromJson(Object? value) =>
      const _RequirementJsonReviver().convert(switch (value) {
        String() => jsonDecode(value),
        List<int>() => jsonDecode(utf8.decode(value)),
        _ => value,
      });
  Map<String, Object?> toJson() => {
    'module': module,
    'version': version,
    'flags': flags,
  };
}

class _ModuleJsonReviver extends ObjectsBase<Module> {
  const _ModuleJsonReviver()
    : super(
        "Module",
        unknownPropertiesStrategy: UnknownPropertiesStrategy.forbid,
      );

  @override
  Module convert(Object? value) {
    if (value is! Map) throw TypeException(Module, value);
    final keys = value.keys.map((key) {
      if (key is! String) {
        throw TypeException(String, key, "object key is not a String");
      }
      return key;
    }).toSet();
    checkRequiredProperties(keys);
    const knownProperties = {
      'javaVersion',
      'path',
      'name',
      'automatic',
      'version',
      'flags',
      'requires',
    };
    final unknownKey = keys
        .where((k) => !knownProperties.contains(k))
        .firstOrNull;
    if (unknownKey != null) {
      throw UnknownPropertyException([unknownKey], Module);
    }
    return Module(
      javaVersion: convertProperty(const Strings(), 'javaVersion', value),
      path: convertProperty(const Strings(), 'path', value),
      name: convertProperty(const Strings(), 'name', value),
      automatic: convertProperty(const Bools(), 'automatic', value),
      version: convertProperty(const Strings(), 'version', value),
      flags: convertProperty(const Strings(), 'flags', value),
      requires: convertProperty(
        const Arrays<Requirement, _RequirementJsonReviver>(
          _RequirementJsonReviver(),
        ),
        'requires',
        value,
      ),
    );
  }

  @override
  Converter<Object?, Object?>? getPropertyConverter(String property) {
    switch (property) {
      case 'javaVersion':
        return const Strings();
      case 'path':
        return const Strings();
      case 'name':
        return const Strings();
      case 'automatic':
        return const Bools();
      case 'version':
        return const Strings();
      case 'flags':
        return const Strings();
      case 'requires':
        return const Arrays<Requirement, _RequirementJsonReviver>(
          _RequirementJsonReviver(),
        );
      default:
        return null;
    }
  }

  @override
  Iterable<String> getRequiredProperties() {
    return const {
      'javaVersion',
      'path',
      'name',
      'automatic',
      'version',
      'flags',
      'requires',
    };
  }

  @override
  String toString() => 'Module';
}

class _JarJsonReviver extends ObjectsBase<Jar> {
  const _JarJsonReviver()
    : super("Jar", unknownPropertiesStrategy: UnknownPropertiesStrategy.forbid);

  @override
  Jar convert(Object? value) {
    if (value is! Map) throw TypeException(Jar, value);
    final keys = value.keys.map((key) {
      if (key is! String) {
        throw TypeException(String, key, "object key is not a String");
      }
      return key;
    }).toSet();
    checkRequiredProperties(keys);
    const knownProperties = {'javaVersion', 'path'};
    final unknownKey = keys
        .where((k) => !knownProperties.contains(k))
        .firstOrNull;
    if (unknownKey != null) {
      throw UnknownPropertyException([unknownKey], Jar);
    }
    return Jar(
      javaVersion: convertProperty(const Strings(), 'javaVersion', value),
      path: convertProperty(const Strings(), 'path', value),
    );
  }

  @override
  Converter<Object?, Object?>? getPropertyConverter(String property) {
    switch (property) {
      case 'javaVersion':
        return const Strings();
      case 'path':
        return const Strings();
      default:
        return null;
    }
  }

  @override
  Iterable<String> getRequiredProperties() {
    return const {'javaVersion', 'path'};
  }

  @override
  String toString() => 'Jar';
}

class _RequirementJsonReviver extends ObjectsBase<Requirement> {
  const _RequirementJsonReviver()
    : super(
        "Requirement",
        unknownPropertiesStrategy: UnknownPropertiesStrategy.forbid,
      );

  @override
  Requirement convert(Object? value) {
    if (value is! Map) throw TypeException(Requirement, value);
    final keys = value.keys.map((key) {
      if (key is! String) {
        throw TypeException(String, key, "object key is not a String");
      }
      return key;
    }).toSet();
    checkRequiredProperties(keys);
    const knownProperties = {'module', 'version', 'flags'};
    final unknownKey = keys
        .where((k) => !knownProperties.contains(k))
        .firstOrNull;
    if (unknownKey != null) {
      throw UnknownPropertyException([unknownKey], Requirement);
    }
    return Requirement(
      module: convertProperty(const Strings(), 'module', value),
      version: convertProperty(const Strings(), 'version', value),
      flags: convertProperty(const Strings(), 'flags', value),
    );
  }

  @override
  Converter<Object?, Object?>? getPropertyConverter(String property) {
    switch (property) {
      case 'module':
        return const Strings();
      case 'version':
        return const Strings();
      case 'flags':
        return const Strings();
      default:
        return null;
    }
  }

  @override
  Iterable<String> getRequiredProperties() {
    return const {'module', 'version', 'flags'};
  }

  @override
  String toString() => 'Requirement';
}
