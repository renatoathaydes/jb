import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:dartle/dartle.dart'
    show DartleException, ColoredLogMessage, LogColor;
import 'package:dartle/dartle_dart.dart' show AcceptAnyArgs;
import 'package:path/path.dart' as p;

import 'config.dart' show JbConfigContainer, logger;
import 'tasks.dart' show jshellTaskName;
import 'utils.dart' show classpathSeparator, StringExtension;

const jshellHelp =
    '''Run jshell with this project's runtime classpath.

      This allow quick experimentation with Java code in a REPL.
      jb will watch the project sources while the REPL is running, re-compiling as
      necessary.
      Use `/reset` to hot-reload the classpath into the REPL.
      
      If the --${JshellArgs.fileOption} option is used, the contents of the file
      are passed to jshell. When the file changes, only the lines that have changed
      are sent again.''';

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

  final options = JshellArgs().parse(args);
  final file = options.option(JshellArgs.fileOption);

  if (file != null) {
    await _runFromFile(file, options, configContainer);
  } else {
    await _runShell(options.rest, classpath);
  }
}

Future<void> _runShell(List<String> args, String classpath) async {
  final exitCode = await _run('jshell', ['--class-path', classpath, ...args]);
  if (exitCode != 0) {
    throw DartleException(message: 'jshell command failed', exitCode: exitCode);
  }
}

Future<void> _runFromFile(
  String file,
  ArgResults options,
  JbConfigContainer configContainer,
) async {
  logger.fine('Running jshell with file $file');

  final proc = await Process.start('jshell', options.rest, runInShell: true);
  proc.stdout.transform(utf8.decoder).listen(print);
  proc.stderr.transform(utf8.decoder).listen(_printRed);
  final procDone = proc.exitCode.asStream().asBroadcastStream();
  await _streamFromFile(file, procDone).pipe(proc.stdin);
}

Stream<List<int>> _streamFromFile(String path, Stream<int> onDone) async* {
  const notDone = 99999999;
  final file = File(path);
  var firstRun = true;
  var prevLines = const <String>[];
  var prevStat = await file.stat();
  while (notDone ==
      (await onDone
          .timeout(
            const Duration(milliseconds: 500),
            onTimeout: (s) => s.add(notDone),
          )
          .first)) {
    final currentStat = await file.stat();
    if (firstRun || (prevStat.modified != currentStat.modified)) {
      logger.fine(() => 'Detected possible change in file $path');
      prevStat = currentStat;
      final lines = await file.readAsLines();
      final prevIter = prevLines.iterator;
      final iter = lines.iterator;
      var foundChange = false;
      while (prevIter.moveNext() && iter.moveNext()) {
        foundChange |= prevIter.current != iter.current;
        if (foundChange) {
          logger.finer(() => 'CHANGED LINE: ${iter.current}');
          yield utf8.encode(iter.current);
          yield ['\n'.codeUnitAt(0)];
        }
      }
      while (iter.moveNext()) {
        logger.finer(() => 'NEW LINE: ${iter.current}');
        yield utf8.encode(iter.current);
        yield ['\n'.codeUnitAt(0)];
      }
      prevLines = lines;
    } else {
      logger.finer(() => 'No changes in file $path');
    }
    firstRun = false;
  }
  logger.fine(() => 'Stopped watching $path');
}

/// Run a process inheriting stdin, stdout and stderr.
Future<int> _run(String process, List<String> args) async {
  final proc = await Process.start(
    process,
    args,
    mode: ProcessStartMode.inheritStdio,
    runInShell: true,
  );
  return proc.exitCode;
}

void _printRed(String line) {
  logger.info(ColoredLogMessage(line, LogColor.red));
}

class JshellArgs extends AcceptAnyArgs {
  static const fileOption = 'file';

  const JshellArgs();

  ArgResults parse(List<String> args) {
    final parser = ArgParser()
      ..addOption(fileOption, abbr: 'f', help: 'run jshell script file');

    return parser.parse(args);
  }

  @override
  bool validate(List<String> args) {
    try {
      return parse(args).rest.isEmpty;
    } on FormatException catch (e) {
      logger.warning('Invalid arguments for $jshellTaskName: ${e.message}');
      return false;
    }
  }

  @override
  String helpMessage() =>
      'Acceptable options:\n'
      '        * --$fileOption\n'
      '          -f <file>: file to send to jshell. File changes are re-sent.';
}
