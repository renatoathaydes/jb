import 'dart:io';
import 'dart:math';

import 'package:dartle/dartle.dart';
import 'package:path/path.dart' as p;
import 'package:test/expect.dart';

final jbuildExecutable = p.join(Directory.current.path, 'build', 'bin',
    Platform.isWindows ? 'jb.exe' : 'jb');

Future<Directory> createTempFiles(Map<String, String> files) async {
  final random = Random();
  final rootDir = Directory(
      p.join(Directory.systemTemp.path, random.nextDouble().toString()));
  await rootDir.create();
  for (final entry in files.entries) {
    await _createFile(rootDir, entry.key, entry.value);
  }
  return rootDir;
}

Future<void> _createFile(Directory rootDir, String path, String text) async {
  final file = File(p.join(rootDir.path, path));
  await file.parent.create(recursive: true);
  await file.writeAsString(text, flush: true);
}

Future<void> assertDirectoryContents(Directory rootDir, List<String> paths,
    {String reason = '', bool checkLength = true}) async {
  final dirContents =
      await rootDir.list(recursive: true).map((f) => f.path).toList();
  expect(
      dirContents,
      allOf(
        containsAll(paths.map((entity) => p.join(rootDir.path, entity))),
        hasLength(checkLength ? paths.length : dirContents.length),
      ),
      reason: reason);
}

String classpath(Iterable<String> entries) {
  final separator = Platform.isWindows ? ';' : ':';
  return entries.join(separator);
}

void expectSuccess(ProcessResult result) {
  expect(result.exitCode, equals(0),
      reason: 'exit code was $exitCode.\n'
          '  => stdout:\n${result.stdout.join('\n')}\n'
          '  => stderr:\n${result.stderr.join('\n')}');
}

Future<ProcessResult> runJb(Directory workingDir,
    [List<String> args = const []]) {
  return runProcess(jbuildExecutable, workingDir, args);
}

Future<ProcessResult> runJava(Directory workingDir,
    [List<String> args = const []]) {
  return runProcess('java', workingDir, args);
}

Future<ProcessResult> runProcess(String name, Directory workingDir,
    [List<String> args = const []]) async {
  final stdout = <String>[];
  final stderr = <String>[];
  final exitCode = await exec(
      Process.start(name, args, workingDirectory: workingDir.path),
      onStdoutLine: stdout.add,
      onStderrLine: stderr.add);
  return ProcessResult(0, exitCode, stdout, stderr);
}
