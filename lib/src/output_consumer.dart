import 'package:logging/logging.dart';

import 'config.dart' show logger;

/// Consumer of another process' output.
mixin ProcessOutputConsumer {
  /// The PID of the process.
  ///
  /// This is called immediately as the process starts.
  set pid(int pid);

  /// Receive a line of the process output.
  void call(String line);
}

abstract class JbOutputConsumer implements ProcessOutputConsumer {
  int pid = 0;

  Object createMessage(Level level, String line);

  @override
  void call(String line) {
    final level = _levelFor(line);
    logger.log(level, createMessage(level, line));
  }

  Level _levelFor(String line) {
    if (line.startsWith('ERROR:') || line.startsWith('JBuild failed ')) {
      return Level.SEVERE;
    }
    if (line.startsWith('WARN:')) {
      return Level.WARNING;
    }
    return Level.INFO;
  }
}
