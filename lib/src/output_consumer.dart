import 'package:logging/logging.dart';

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

  JbOutputConsumer(this.pid);

  void consume(Level Function(String) getLevel, String line);

  @override
  void call(String line) {
    consume(_levelFor, line);
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
