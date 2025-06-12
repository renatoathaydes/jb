import 'dart:io';

import 'package:dartle/dartle.dart';
import 'package:path/path.dart' as p;

final _javaIdPattern = RegExp(r'^[a-zA-Z_$][a-zA-Z_$\d]*$');

Future<void> _noOp() async {}

FileCreator createJavaFile(
  String package,
  String name,
  String dir,
  String contents,
) {
  final javaDir = p.joinAll([dir] + package.split('.'));
  final javaFile = File(p.join(javaDir, '$name.java'));
  return FileCreator(javaFile, () async {
    await Directory(javaDir).create(recursive: true);
    await javaFile.writeAsString(contents);
  });
}

class FileCreator {
  final File file;
  final Future<void> Function() create;

  FileCreator(this.file, [this.create = _noOp]);

  Future<void> call() => create();

  Future<void> check() async {
    if (await file.exists()) {
      throw DartleException(
        message:
            'Cannot create jb project, at least '
            'one existing file would be overwritten: ${file.path}',
      );
    }
  }
}

extension PromptHelper on String? {
  String or(String defaultValue) {
    final String? self = this;
    if (self == null) {
      throw DartleException(message: 'No input available');
    }
    if (self.trim().isEmpty) {
      return defaultValue;
    }
    return self;
  }

  bool yesOrNo() {
    final String? s = this;
    return s == null ||
        s.trim().isEmpty ||
        const {'yes', 'y'}.contains(s.toLowerCase());
  }
}

extension JavaHelper on String {
  String toJavaId() {
    return replaceAll('-', '_');
  }

  String validateJavaPackage() {
    if (this == '.' || startsWith('.') || endsWith('.')) {
      throw DartleException(message: 'Invalid Java package name: $this');
    }
    for (final part in split('.')) {
      if (!_javaIdPattern.hasMatch(part)) {
        throw DartleException(
          message: 'Invalid Java package name: $this (invalid segment: $part)',
        );
      }
    }
    return this;
  }
}
