import 'dart:io';
import 'package:path/path.dart' as path;

final _jbuildHome = Platform.environment['JBUILD_CLI_HOME'];

String jbuildCliHome() {
  final result = _jbuildHome;
  if (result == null) {
    final userHome = Platform.environment['HOME'];
    if (userHome == null) {
      throw Exception('Cannot find JBUILD_CLI_HOME or '
          'HOME environment variables');
    }
    return path.join(userHome, '.jbuild-cli');
  }
  return result;
}

String jbuildJarPath() {
  return path.join(jbuildCliHome(), 'jbuild.jar');
}
