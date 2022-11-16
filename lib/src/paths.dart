import 'dart:io';

import 'package:path/path.dart' as path;

import 'config.dart';

final _jbuildHome = Platform.environment['JBUILD_CLI_HOME'];

/// Find the `jb` home directory.
///
/// On Windows, this is `%APPDATA%\\.jbuild-cli`.
/// On other OS, `$HOME/.jbuild-cli`.
///
/// To override that, set the `JBUILD_CLI_HOME` env var.
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

/// The `jbuild.jar` path. This jar is created, if necessary, from the
/// embedded jar in `jb`, but may be updated.
String jbuildJarPath() {
  return path.join(jbuildCliHome(), 'jbuild.jar');
}

/// The dependencies file (output of `writeDependencies` task).
File dependenciesFile(JBuildFiles files) {
  return File(path.join(files.tempDir.path, 'dependencies'));
}
