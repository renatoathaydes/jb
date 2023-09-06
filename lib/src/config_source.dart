import 'dart:async';
import 'dart:io';

import 'config.dart';

abstract class ConfigSource {
  FutureOr<JBuildConfiguration> load();
}

class FileConfigSource implements ConfigSource {
  final String configFile;

  const FileConfigSource(this.configFile);

  @override
  Future<JBuildConfiguration> load() {
    return loadConfig(File(configFile));
  }
}

final class InstanceConfigSource implements ConfigSource {
  final JBuildConfiguration configuration;

  const InstanceConfigSource(this.configuration);

  @override
  JBuildConfiguration load() {
    return configuration;
  }
}
