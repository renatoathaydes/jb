import 'dart:io';

import 'package:dartle/dartle.dart';
import 'package:jb/jb.dart';
import 'package:logging/logging.dart';

void main(List<String> arguments) async {
  final stopWatch = Stopwatch()..start();
  final jbuildJar = await createIfNeededAndGetJBuildJarFile();
  var loggingEnabled = false;
  Options? dartleOptions;
  try {
    final jbOptions = JBuildCliOptions.parseArgs(arguments);
    dartleOptions = parseOptions(jbOptions.dartleArgs);
    activateLogging(dartleOptions.logLevel,
        colorfulLog: dartleOptions.colorfulLog, logName: 'jbuild');
    loggingEnabled = true;
    final printBuildSuccess =
        await runJBuild(jbOptions, dartleOptions, stopWatch, jbuildJar);
    if (printBuildSuccess) {
      logger.info(ColoredLogMessage(
          'Build succeeded in ${_elapsedTime(stopWatch)}!', LogColor.green));
    }
  } catch (e, st) {
    _logAndExit(loggingEnabled, dartleOptions?.logLevel, e, st);
  }
}

Never _logAndExit(
    bool loggingEnabled, Level? logLevel, Object exception, StackTrace? st) {
  if (loggingEnabled) {
    if (exception is DartleException) {
      logger.severe(exception.message);
      if (logLevel == Level.FINE) {
        if (exception is MultipleExceptions) {
          for (final entry in exception.exceptionsAndStackTraces) {
            logger.severe('==========>', entry.exception, entry.stackTrace);
          }
        } else {
          logger.severe(st);
        }
      }
    } else {
      logger.severe('unexpected error', exception, st);
    }
  } else {
    if (exception is DartleException) {
      print(exception.message);
    } else {
      print('unexpected error: $exception');
      print(st);
    }
  }
  exit(exitCode);
}

String _elapsedTime(Stopwatch stopwatch) {
  final millis = stopwatch.elapsedMilliseconds;
  if (millis > 1000) {
    final secs = (millis * 1e-3).toStringAsPrecision(4);
    return '$secs seconds';
  } else {
    return '$millis ms';
  }
}
