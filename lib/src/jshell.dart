import 'dart:io';

import 'package:dartle/dartle.dart' show DartleException;
import 'package:dartle/dartle_dart.dart' show AcceptAnyArgs;
import 'package:path/path.dart' as p;

import '../jb.dart' show JbConfigContainer;
import 'utils.dart' show classpathSeparator, StringExtension;

Future<void> jshell(
  File jbuildJar,
  JbConfigContainer configContainer,
  List<String> args,
) async {
  final config = configContainer.config;

  final classpath = {
    configContainer.output.when(dir: (d) => d.asDirPath(), jar: (j) => j),
    config.runtimeLibsDir,
    p.join(config.runtimeLibsDir, '*'),
  }.join(classpathSeparator);
  final runner = ProcessRunner();
  final exitCode = await runner.run('jshell', [
    '--class-path',
    classpath,
    ...args,
  ]);

  if (exitCode != 0) {
    throw DartleException(message: 'jshell command failed', exitCode: exitCode);
  }
}

class ProcessRunner {
  /// Run a process inheriting stdin, stdout and stderr.
  Future<int> run(String process, List<String> args) async {
    final proc = await Process.start(
      process,
      args,
      mode: ProcessStartMode.inheritStdio,
    );
    return proc.exitCode;
  }
}

class JshellArgs extends AcceptAnyArgs {
  const JshellArgs();

  @override
  String helpMessage() {
    return '''Run jshell with this project's runtime classpath.

      This allow quick experimentation with Java code in a REPL.
      jb will watch the project sources while the REPL is running, re-compiling as
      necessary.
      Use `/reset` to hot-reload the classpath into the REPL.''';
  }
}
