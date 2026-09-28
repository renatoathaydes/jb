import 'dart:io';

import 'package:dartle/dartle.dart' show DartleException;

import 'config.dart';

class JbConfigWithImports {
  /// The root config file, usually `jbuild.yaml`.
  final String? configFile;

  /// The jb configuration data.
  final JbConfiguration config;

  /// Imported files starting from the root config's imports, then recursively
  /// computing all imported files.
  final Set<String> imports;

  const JbConfigWithImports(
    this.configFile,
    this.config, [
    this.imports = const {},
  ]);
}

extension ImportsJBuildConfigurationExtension on JbConfiguration {
  Future<JbConfigWithImports> applyImports(
    Object? imports,
    String? configFile,
  ) async {
    var result = JbConfigWithImports(configFile, this);
    if (imports == null) return result;
    if (imports is String) {
      result = await _resolveImport(result, File(imports));
    } else if (imports is Iterable) {
      for (final value in imports) {
        if (value is String) {
          result = await _resolveImport(result, File(value));
        } else {
          throw DartleException(
            message:
                'Value for `imports` item must  be a String, '
                'but it is ${value?.runtimeType}',
          );
        }
      }
    } else {
      throw DartleException(
        message:
            'Value for `imports` must  be a String or List of Strings, '
            'but it is ${imports.runtimeType}',
      );
    }
    return result;
  }
}

Future<JbConfigWithImports> _resolveImport(
  JbConfigWithImports cwi,
  File importedConfigFile,
) async {
  logger.fine(() => 'Reading imported config file: ${importedConfigFile.path}');
  final imported = await loadConfigString(
    await importedConfigFile.readAsString(),
  );
  return JbConfigWithImports(
    cwi.configFile,
    imported.config.merge(cwi.config),
    {...cwi.imports, importedConfigFile.path, ...imported.imports},
  );
}
