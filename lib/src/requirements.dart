import 'dart:io';

import 'package:dartle/dartle.dart';
import 'package:io/ansi.dart' as ansi;
import 'package:jb/jb.dart';

import 'output_consumer.dart';

Future<int> logRequirements(
    File jbuildJar, JBuildConfiguration config, List<String> args) async {
  return await execJBuild(
      'requirements', jbuildJar, config.preArgs(), 'requirements', args,
      onStdout: _RequirementsPrinter());
}

class _RequirementsPrinter implements ProcessOutputConsumer {
  int pid = -1;

  @override
  void call(String line) {
    if (line.startsWith('Required')) {
      _logHeader(line);
    } else if (line.startsWith("ERROR:")) {
      _logError(line);
    } else if (line.startsWith('  -')) {
      _logType(line);
    } else {
      logger.info(PlainMessage(line));
    }
  }

  void _logHeader(String line) {
    logger.info(ColoredLogMessage(line, LogColor.magenta));
  }

  void _logError(String line) {
    logger.info(ColoredLogMessage(line, LogColor.red));
  }

  void _logType(String line) {
    final parensIndex = line.indexOf('(');
    if (parensIndex > 0) {
      final endParensIndex = line.lastIndexOf(')');
      final type = line.substring(0, parensIndex);
      final sourceFile = line.substring(parensIndex, endParensIndex + 1);
      logger.info(AnsiMessage([
        const AnsiMessagePart.code(ansi.styleBold),
        AnsiMessagePart.text(type),
        const AnsiMessagePart.code(ansi.resetBold),
        const AnsiMessagePart.code(ansi.lightGray),
        AnsiMessagePart.text(sourceFile),
        const AnsiMessagePart.text(':')
      ]));
    } else {
      logger.info(PlainMessage(line));
    }
  }
}
