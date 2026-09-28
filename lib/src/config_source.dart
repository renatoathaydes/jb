import 'dart:async';
import 'dart:io';

import 'package:dartle/dartle.dart' show DartleException;
import 'package:jb/jb.dart';

sealed class ConfigSource {
  FutureOr<JbConfigWithImports> load();
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
  Future<JbConfigWithImports> load() async {
    return await loadConfig(await selectFile());
  }
}

final class InstanceConfigSource implements ConfigSource {
  final JbConfigWithImports _ciw;

  const InstanceConfigSource(this._ciw);

  @override
  JbConfigWithImports load() {
    return _ciw;
  }
}
