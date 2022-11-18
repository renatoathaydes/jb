import 'dart:io';

import 'package:dartle/dartle.dart';
import 'package:dartle/dartle_cache.dart';

import 'config.dart';
import 'exec.dart';
import 'tasks.dart' show depsTaskName;

Future<int> printDependencies(File jbuildJar, JBuildConfiguration config,
    DartleCache cache, bool noColor, List<String> args) async {
  final deps = config.dependencies.entries
      .where((dep) => dep.value.path == null)
      .map((dep) => dep.key);

  return await execJBuild(depsTaskName, jbuildJar, config.preArgs(), 'deps',
      ['-t', '-s', 'compile', ...deps], _DepsPrinter());
}

class _DepsPrinter implements ProcessOutputConsumer {
  int pid = -1;

  @override
  void call(String line) {
    if (line.startsWith('  - scope')) {
      _logScopeLine(line);
    } else if (line.startsWith('    * ')) {
      _logDependency(line);
    } else {
      print(line);
    }
  }

  void _logScopeLine(String line) {
    logger.info(ColoredLogMessage(line, LogColor.blue));
  }

  void _logDependency(String line) {
    // TODO colorize
    print(line);
  }
}
