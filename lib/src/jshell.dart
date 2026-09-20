import 'dart:async';
import 'dart:io';

import 'package:dartle/dartle.dart' show DartleException, Options, runBasic;
import 'package:dartle/dartle_cache.dart' show DartleCache;

import '../jb.dart' as jb;
import 'fs_watcher.dart';
import 'utils.dart' show DirectoryExtension, StringExtension;

const jshellHelp = '''Run jshell with this project's runtime classpath.

      This allows quick experimentation with Java code in a REPL.
      jb will watch the project sources while the REPL is running, re-compiling as
      necessary.
      Use `/reset` to hot-reload the classpath into the REPL.
      
      Arguments are passed to jshell.''';

Future<void> jshell(
  jb.JbDartleTasks runner,
  Options options,
  jb.JbConfigContainer configContainer,
  List<String> args,
  DartleCache cache,
) async {
  final config = configContainer.config;
  final classpath = await Directory(config.runtimeLibsDir.asOsPath())
      .toClasspath(
        extraEntries: {
          configContainer.output.when(dir: Directory.new, jar: File.new),
        },
        includeSelf: true,
      );
  jb.logger.fine(() => 'jshell classpath: $classpath');

  final watcher = FileSystemWatcher(
    config.sourceDirs
        .followedBy(config.resourceDirs)
        .map(Directory.new)
        .toList(),
    onChange: (_) => _recompile(runner, options, cache),
    loggerName: 'jshell',
  );

  await watcher.start();

  try {
    var exitCode = await _runJShell(
      args,
      classpath,
      ProcessStartMode.inheritStdio,
    ).then((proc) => proc.exitCode);
    if (exitCode != 0) {
      throw DartleException(
        message: 'jshell command failed',
        exitCode: exitCode,
      );
    }
  } finally {
    watcher.stop();
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

Future<void> _recompile(
  jb.JbDartleTasks runner,
  Options options,
  DartleCache cache,
) async {
  try {
    await runBasic(
      runner.tasks,
      runner.defaultTasks,
      options.copy(tasksInvocation: const ['installRuntimeDependencies']),
      cache,
    );
    jb.logger.info(
      'Recompiled successfully, run /reset to reload the classpath.',
    );
  } on DartleException catch (e) {
    jb.logger.severe(() => 'Failed to recompile: ${e.message}');
  }
}
