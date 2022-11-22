import 'dart:io';

import 'package:path/path.dart' as path;

final _jbuildHome = Platform.environment['JB_HOME'];

/// Find the `jb` home directory.
///
/// On Windows, this is `%APPDATA%\\.jb`.
/// On other OS, `$HOME/.jb`.
///
/// To override that, set the `JB_HOME` env var.
String jbuildCliHome() {
  final result = _jbuildHome;
  if (result == null) {
    final varName = Platform.isWindows ? 'APPDATA' : 'HOME';
    final userHome = Platform.environment[varName];
    if (userHome == null) {
      throw Exception('Cannot find JB_HOME or '
          '$varName environment variables');
    }
    return path.join(userHome, '.jb');
  }
  return result;
}

/// The `jbuild.jar` path. This jar is created, if necessary, from the
/// embedded jar in `jb`, but may be updated.
String jbuildJarPath() {
  return path.join(jbuildCliHome(), 'jbuild.jar');
}
