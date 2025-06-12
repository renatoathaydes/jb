import 'dart:async';
import 'dart:io';

import 'package:dartle/dartle.dart' show DartleException;

import 'config.dart';

sealed class ConfigSource {
  FutureOr<JbConfiguration> load();
}

const defaultJbConfigSource = FileConfigSource([yamlJbFile, jsonJbFile]);

final class FileConfigSource implements ConfigSource {
  final List<String> configFiles;

  const FileConfigSource(this.configFiles);

  Future<File> selectFile() async {
    for (final path in configFiles) {
      final file = File(path);
      if (await file.exists()) {
        return file;
      }
    }
    throw DartleException(
      message:
          'None of the expected jb config files exist.\n'
          'Run `jb create` to create a project, '
          'or create a config file: ${configFiles.join(' or ')}.',
    );
  }

  @override
  Future<JbConfiguration> load() async {
    return await loadConfig(await selectFile());
  }
}

final class InstanceConfigSource implements ConfigSource {
  final JbConfiguration configuration;

  const InstanceConfigSource(this.configuration);

  @override
  JbConfiguration load() {
    return configuration;
  }
}
