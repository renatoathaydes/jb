import 'package:collection/collection.dart' as col;
import 'package:conveniently/conveniently.dart';
import 'package:dartle/dartle.dart' show failBuild;

import '../config.dart';

List<Object?> resolveTaskConstructorData(
  JbConfiguration config,
  BasicExtensionTask taskConfig,
) {
  final name = taskConfig.name;
  final taskConfigData = config.extras[name];
  if (taskConfigData is! Map<String, Object?>?) {
    failBuild(
      reason:
          "Cannot create jb extension task '$name' because the "
          "provided configuration is not an object "
          "(type is ${taskConfigData.runtimeType}): $taskConfigData",
    );
  }

  final constructorData = resolveConstructorData(
    taskConfig.name,
    taskConfigData,
    taskConfig.constructors,
    config,
  );

  logger.fine(
    () =>
        "Resolved data for constructor of extension "
        "task '$name': $constructorData",
  );

  return constructorData;
}

/// Resolve a matching constructor for a given taskConfig, resolving the data
/// that should be used to invoke it.
///
/// The list of constructors contains the available Java constructors and must
/// not be empty (Java requires at least one constructor to exist).
/// Values in taskConfig are matched against each constructor parameter by name
/// and then are type checked.
///
/// A value type checks if its type is identical to a [ConfigType] parameter
/// or in case of [ConfigType.string], if it's `null`.
/// Parameters of type [ConfigType.jbuildLogger] must have value `null`,
/// and if not provided this method injects `null` in their place.
///
/// Parameters that have a jbName are resolved against JBuild's own
/// configuration.
List<Object?> resolveConstructorData(
  String name,
  Map<String, Object?>? taskConfig,
  List<JavaConstructor> constructors,
  JbConfiguration config,
) {
  if (taskConfig == null || taskConfig.isEmpty) {
    return _jbuildNoConfigConstructorData(name, constructors, config) ??
        constructors
            .firstWhere(
              (c) => c.isEmpty,
              orElse: () {
                failBuild(
                  reason:
                      "Cannot create jb extension task '$name' because "
                      "no configuration has been provided. Add a top-level config"
                      "value with the name '$name', and then configure it using one of "
                      "the following schemas:\n${_constructorsHelp(constructors)}",
                );
              },
            )
            .vmap((_) => const []);
  }
  final keyMatch = constructors.firstWhere(
    (c) => _keysMatch(c, taskConfig),
    orElse: () {
      if (_requireNoConfiguration(constructors)) {
        failBuild(
          reason:
              "Cannot create jb extension task '$name' because "
              "configuration was provided for this task when none was "
              "expected. Please remove it from your jb configuration.",
        );
      }
      failBuild(
        reason:
            "Cannot create jb extension task '$name' because "
            "the provided configuration for this task does not match any of "
            "the acceptable schemas. Please use one of the following schemas:\n"
            "${_constructorsHelp(constructors)}",
      );
    },
  );
  return keyMatch.entries
      .map((entry) {
        final type = entry.value;
        final value = taskConfig[entry.key];
        if (value != null && !type.mayBeConfigured()) {
          failBuild(
            reason:
                "Cannot create jb extension task '$name' because "
                "its configuration is trying to provide a value for a "
                "non-configurable property '${entry.key}'! "
                "Please remove this property from configuration.",
          );
        }
        if (type == ConfigType.jbuildLogger) {
          return null;
        } else if (type == ConfigType.jbConfig) {
          return config.toJson();
        } else if (type.mayBeConfigured() && value.isOfType(type)) {
          return value;
        }
        logger.warning(
          "'Configuration of task '$name' did not type check. "
          "Value of '$value' is not of type $type!",
        );
        failBuild(
          reason:
              "Cannot create jb extension task '$name' because "
              "the provided configuration for this task does not match any of "
              "the acceptable schemas. Please use one of the following schemas:\n"
              "${_constructorsHelp(constructors)}",
        );
      })
      .toList(growable: false);
}

bool _keysMatch(JavaConstructor constructor, Map<String, Object?> taskConfig) {
  final mayBeMissingKeys = constructor.entries
      .where((e) => !e.value.mayBeConfigured())
      .map((e) => e.key)
      .toSet();
  final mandatoryConfigKeys = taskConfig.keys
      .where(mayBeMissingKeys.contains.not$)
      .toSet();
  final mandatoryParamKeys = constructor.keys
      .where(mayBeMissingKeys.contains.not$)
      .toSet();
  logger.finer(
    () =>
        'Constructor parameters: $mandatoryParamKeys, '
        'config: $mandatoryConfigKeys',
  );
  return const col.SetEquality().equals(
    mandatoryConfigKeys,
    mandatoryParamKeys,
  );
}

bool _requireNoConfiguration(List<JavaConstructor> constructors) {
  return constructors.every(
    (c) => c.isEmpty || c.values.every((e) => !e.mayBeConfigured()),
  );
}

String _constructorsHelp(List<JavaConstructor> constructors) {
  final builder = StringBuffer();
  var listedNoConfig = false;
  for (final (i, constructor) in constructors.indexed) {
    builder.writeln('  - option${i + 1}:');
    if (constructor.isEmpty ||
        constructor.values.every((t) => !t.mayBeConfigured())) {
      if (!listedNoConfig) {
        builder.writeln('    <no configuration>');
        listedNoConfig = true;
      }
    } else {
      constructor.forEach((fieldName, type) {
        if (type.mayBeConfigured()) {
          builder
            ..write('    ')
            ..write(fieldName)
            ..write(': ')
            ..writeln(type);
        }
      });
    }
  }
  return builder.toString();
}

/// Try to find a constructor that requires no configuration, considering
/// longer parameter lists first.
List<Object?>? _jbuildNoConfigConstructorData(
  String name,
  List<JavaConstructor> constructors,
  JbConfiguration config,
) {
  return constructors
      .where((c) => c.values.every((type) => !type.mayBeConfigured()))
      .sorted((a, b) => b.keys.length.compareTo(a.keys.length))
      .map(
        (c) => c.values
            .map((type) {
              return (type == ConfigType.jbConfig) ? config.toJson() : null;
            })
            .toList(growable: false),
      )
      .firstOrNull;
}

extension on Object? {
  bool isOfType(ConfigType type) {
    return switch (type) {
      ConfigType.string => this is String?,
      ConfigType.boolean => this is bool,
      ConfigType.int => this is int,
      ConfigType.float => this is double,
      ConfigType.listOfStrings || ConfigType.arrayOfStrings => vmap(
        (self) => self is Iterable && self.every((i) => i is String),
      ),
      ConfigType.jbuildLogger || ConfigType.jbConfig => false,
    };
  }
}
