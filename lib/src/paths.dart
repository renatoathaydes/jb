import 'dart:io';

import 'package:path/path.dart' as path;

import 'config.dart';

final _jbuildHome = Platform.environment['JBUILD_CLI_HOME'];

String jbuildCliHome() {
  final result = _jbuildHome;
  if (result == null) {
    final varName = Platform.isWindows ? 'APPDATA' : 'HOME';
    final userHome = Platform.environment[varName];
    if (userHome == null) {
      throw Exception('Cannot find JBUILD_CLI_HOME or '
          '$varName environment variables');
    }
    return path.join(userHome, '.jbuild-cli');
  }
  return result;
}

String jbuildJarPath() {
  return path.join(jbuildCliHome(), 'jbuild.jar');
}

File dependenciesFile(JBuildFiles files) {
  return File(path.join(files.tempDir.path, 'dependencies'));
}
