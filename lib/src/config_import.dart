import 'dart:io';

import 'package:dartle/dartle.dart' show DartleException;

import 'config.dart';

extension ImportsJBuildConfigurationExtension on JBuildConfiguration {
  Future<JBuildConfiguration> applyImports(imports) async {
    if (imports == null) return this;
    var result = this;
    if (imports is String) {
      result = await _resolveImport(this, File(imports));
    } else if (imports is Iterable) {
      for (final value in imports) {
        if (value is String) {
          result = await _resolveImport(this, File(value));
        } else {
          throw DartleException(
              message: 'Value for `imports` item must  be a String, '
                  'but it is ${value?.runtimeType}');
        }
      }
    } else {
      throw DartleException(
          message: 'Value for `imports` must  be a String or List of Strings, '
              'but it is ${imports?.runtimeType}');
    }
    return result;
  }
}

Future<JBuildConfiguration> _resolveImport(
    JBuildConfiguration config, File importedConfigFile) async {
  logger.fine(() => 'Reading imported config file: ${importedConfigFile.path}');
  final imported =
      await loadConfigString(await importedConfigFile.readAsString());
  return imported.merge(config);
}
