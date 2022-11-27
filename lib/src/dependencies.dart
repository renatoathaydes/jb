import 'dart:io';

import 'package:dartle/dartle.dart';
import 'package:dartle/dartle_cache.dart';
import 'package:io/ansi.dart' as ansi;

import 'config.dart';
import 'exec.dart';
import 'tasks.dart' show depsTaskName;

Future<int> printDependencies(File jbuildJar, JBuildConfiguration config,
    DartleCache cache, bool noColor, List<String> args) async {
  final deps = config.dependencies.entries
      .where((dep) => dep.value.path == null)
      .map((dep) => dep.key);

  if (deps.isEmpty) {
    logger.info(
        const PlainMessage('This project does not have any dependencies!'));
    return 0;
  }

  logger.info(const AnsiMessage([
    AnsiMessagePart.code(ansi.styleItalic),
    AnsiMessagePart.code(ansi.styleBold),
    AnsiMessagePart.text('This project has the following dependencies:')
  ]));

  return await execJBuild(depsTaskName, jbuildJar, config.preArgs(), 'deps',
      ['-t', '-s', 'compile', ...deps],
      onStdout: _DepsPrinter());
}

class _DepsPrinter implements ProcessOutputConsumer {
  int pid = -1;

  @override
  void call(String line) {
    if (line.startsWith('Dependencies of ')) {
      _logDirectDependency(line);
    } else if (line.startsWith('  - scope')) {
      _logScopeLine(line);
    } else if (line.isDependency()) {
      _logDependency(line);
    } else if (line.endsWith('is required with more than one version:')) {
      _logDependencyWarning(line);
    } else {
      logger.info(PlainMessage(line));
    }
  }

  void _logDirectDependency(String line) {
    logger.info(ColoredLogMessage(
        '* ${line.substring('Dependencies of '.length)}', LogColor.magenta));
  }

  void _logScopeLine(String line) {
    logger.info(ColoredLogMessage(line, LogColor.blue));
  }

  void _logDependencyWarning(String line) {
    logger.info(ColoredLogMessage(line, LogColor.yellow));
  }

  void _logDependency(String line) {
    if (line.endsWith('(-)')) {
      logger.info(ColoredLogMessage(line, LogColor.gray));
    } else {
      logger.info(PlainMessage(line));
    }
  }
}

final _depPattern = RegExp(r'^\s+\*\s');

extension _DepString on String {
  bool isDependency() {
    return _depPattern.hasMatch(this);
  }
}
