import 'dart:io';

import 'package:dartle/dartle.dart';
import 'package:jb/jb.dart';
import 'package:logging/logging.dart';

void main(List<String> arguments) async {
  final stopWatch = Stopwatch()..start();
  var loggingEnabled = false;
  onEverythingUpToDate = _onEverythingUpToDate;
  Options? dartleOptions;
  try {
    final jbOptions = JbCliOptions.parseArgs(arguments);
    dartleOptions = parseOptions(jbOptions.dartleArgs);
    loggingEnabled = activateLogging(
      dartleOptions.logLevel,
      colorfulLog: dartleOptions.colorfulLog,
      logName: 'jb',
    );
    final printBuildSuccess = await runJb(jbOptions, dartleOptions, stopWatch);
    if (printBuildSuccess) {
      logger.info(
        ColoredLogMessage(
          'Build succeeded in ${elapsedTime(stopWatch)}!',
          LogColor.green,
        ),
      );
    }
    // explicitly exit to avoid rogue futures keeping the process alive
    exit(0);
  } catch (e, st) {
    _logAndExit(loggingEnabled, dartleOptions?.logLevel, e, st);
  }
}

Never _logAndExit(
  bool loggingEnabled,
  Level? logLevel,
  Object exception,
  StackTrace? st,
) {
  int code;
  if (loggingEnabled) {
    if (exception is DartleException) {
      code = exception.exitCode;
      logger.severe(exception.message);
      if (logger.isLoggable(Level.FINE)) {
        if (exception is MultipleExceptions) {
          for (final entry in exception.exceptionsAndStackTraces) {
            logger.severe('==========>', entry.exception, entry.stackTrace);
          }
        } else {
          logger.severe(st);
        }
      }
    } else {
      code = 1;
      logger.severe('unexpected error', exception, st);
    }
  } else {
    if (exception is DartleException) {
      code = exception.exitCode;
      print(exception.message);
    } else {
      code = 1;
      print('unexpected error: $exception');
      print(st);
    }
  }
  exit(code);
}

void _onEverythingUpToDate() {
  logger.info(
    ColoredLogMessage(
      'Project at ${Directory.current.path} is up-to-date',
      LogColor.green,
    ),
  );
}
