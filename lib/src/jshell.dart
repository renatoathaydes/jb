import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:dartle/dartle.dart' show DartleException;
import 'package:dartle/dartle_dart.dart' show AcceptAnyArgs;
import 'package:io/ansi.dart' show red;

import 'config.dart' show JbConfigContainer, logger;
import 'tasks.dart' show jshellTaskName;
import 'utils.dart' show DirectoryExtension;

const jshellHelp =
    '''Run jshell with this project's runtime classpath.

      This allow quick experimentation with Java code in a REPL.
      jb will watch the project sources while the REPL is running, re-compiling as
      necessary.
      Use `/reset` to hot-reload the classpath into the REPL.
      
      If the --${JshellArgs.fileOption} option is used, the contents of the file
      are evaluated by jshell. When the file changes, only the lines that have changed
      are evaluated again. Commands can also be entered directly into the shell,
      but with reduced interactive functionality.''';

final _newLine = '\n'.codeUnitAt(0);

Future<void> jshell(
  File jbuildJar,
  JbConfigContainer configContainer,
  List<String> args,
) async {
  final config = configContainer.config;
  final classpath = await Directory(config.runtimeLibsDir).toClasspath({
    configContainer.output.when(dir: Directory.new, jar: File.new),
  });
  logger.fine(() => 'jshell classpath: $classpath');

  final options = JshellArgs().parse(args);
  final file = options.option(JshellArgs.fileOption);

  Future<int> exitCodeFuture;
  if (file != null) {
    exitCodeFuture = _runFromFile(
      file,
      options.rest,
      configContainer,
      classpath,
    );
  } else {
    exitCodeFuture = (await _runJShell(
      options.rest,
      classpath,
      ProcessStartMode.inheritStdio,
    )).exitCode;
  }
  final exitCode = await exitCodeFuture;
  if (exitCode != 0) {
    throw DartleException(message: 'jshell command failed', exitCode: exitCode);
  }
}

Future<Process> _runJShell(
  List<String> args,
  String? classpath,
  ProcessStartMode mode,
) async {
  final proc = await Process.start(
    'jshell',
    [
      if (classpath != null) ...['--class-path', classpath],
      ...args,
    ],
    mode: mode,
    runInShell: true,
  );
  return proc;
}

Future<int> _runFromFile(
  String file,
  List<String> args,
  JbConfigContainer configContainer,
  String? classpath,
) async {
  logger.fine('Running jshell with file $file');
  logger.warning(
    'jshell running in non-terminal mode (i.e. limited CLI '
    'functionality) so that it can receive file updates.\n'
    'Changing the file causes the lines below the first modified line to be '
    're-evaluated.',
  );

  final proc = await _runJShell(
    ['-q', ...args],
    classpath,
    ProcessStartMode.normal,
  );
  final procDone = proc.exitCode.asStream().asBroadcastStream();
  final exitCodeFuture = procDone.first;
  final stdinSubscription = stdin.listen(proc.stdin.add);
  try {
    proc.stdout.transform(const SystemEncoding().decoder).listen(stdout.write);
    proc.stderr.transform(const SystemEncoding().decoder).listen(_writeStderr);
    await _streamFromFile(file, procDone).listen(proc.stdin.add).asFuture();
  } finally {
    logger.finer('Cancelling stdin subscription');
    await stdinSubscription.cancel();
  }
  logger.info('jshell process has exited');
  return await exitCodeFuture;
}

Stream<List<int>> _streamFromFile(String path, Stream<int> onDone) async* {
  const notDone = 99999999;
  final file = File(path);
  final toYield = <int>[];
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
      var lineCount = 0;
      var foundChange = false;
      while (prevIter.moveNext() && iter.moveNext()) {
        foundChange |= prevIter.current != iter.current;
        if (foundChange) {
          logger.finer(() => 'CHANGED LINE: ${iter.current}');
          toYield.addJavaCode(iter.current);
          lineCount++;
        }
      }
      while (iter.moveNext()) {
        logger.finer(() => 'NEW LINE: ${iter.current}');
        toYield.addJavaCode(iter.current);
        lineCount++;
      }
      if (toYield.isNotEmpty) {
        toYield.add(_newLine);
        yield toYield;
        yield [_newLine];
        logger.info(() => 'Evaluated $lineCount line(s) from file.');
        toYield.clear();
      }
      prevLines = lines;
    } else {
      logger.finer(() => 'No changes in file $path');
    }
    firstRun = false;
  }
  logger.fine(() => 'Stopped watching $path');
}

extension on List<int> {
  void addJavaCode(String line) {
    line = line.trim();
    if (!line.startsWith('//')) {
      addAll(utf8.encode(line));
    }
    if (line.endsWith(';')) {
      add(_newLine);
    }
  }
}

void _writeStderr(String text) {
  stderr.writeln(red.wrap(text));
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
