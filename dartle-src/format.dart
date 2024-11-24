import 'dart:io' show Process;

import 'package:dartle/dartle.dart' show failBuild, exec;

Future<void> formatDart(String path) async {
  final formatExitCode = await exec(Process.start('dart', ['format', path]));
  if (formatExitCode != 0) {
    failBuild(reason: 'Could not format: $path');
  }
}
