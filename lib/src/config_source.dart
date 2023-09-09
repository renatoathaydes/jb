import 'dart:async';
import 'dart:io';

import 'config.dart';

abstract class ConfigSource {
  FutureOr<JbConfiguration> load();
}

class FileConfigSource implements ConfigSource {
  final String configFile;

  const FileConfigSource(this.configFile);

  @override
  Future<JbConfiguration> load() {
    return loadConfig(File(configFile));
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
