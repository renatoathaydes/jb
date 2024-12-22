import 'dart:io';
import 'dart:math';

import 'package:dartle/dartle.dart';
import 'package:jb/src/utils.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

final jbuildExecutable = p.join(Directory.current.path, 'build', 'bin',
    Platform.isWindows ? 'jb.exe' : 'jb');

void projectGroup(String projectDir, String name, Function() definition) {
  final outputDirs = dirs([
    p.join(projectDir, '.jb-cache'),
    p.join(projectDir, 'out'),
    p.join(projectDir, 'build'),
    p.join(projectDir, 'compile-libs'),
    p.join(projectDir, 'runtime-libs'),
  ], includeHidden: true);

  setUp(() async {
    await deleteAll(outputDirs);
  });

  tearDownAll(() async {
    await deleteAll(outputDirs);
  });

  group(name, definition);
}

Future<Directory> createTempFiles(Map<String, String> files) async {
  final random = Random();
  final rootDir = Directory(
      p.join(Directory.systemTemp.path, random.nextDouble().toString()));
  await rootDir.create();
  await createFiles(rootDir, files);
  return rootDir;
}

Future<void> createFiles(Directory rootDir, Map<String, String> files) async {
  for (final entry in files.entries) {
    await _createFile(rootDir, entry.key, entry.value);
  }
}

Future<void> _createFile(Directory rootDir, String path, String text) async {
  final file = File(p.join(rootDir.path, path));
  await file.parent.create(recursive: true);
  await file.writeAsString(text, flush: true);
}

Future<void> assertDirectoryContents(Directory rootDir, List<String> paths,
    {String reason = '', bool checkLength = true}) async {
  expect(await rootDir.exists(), isTrue,
      reason: 'Directory does not exist: ${rootDir.path}');
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
  return entries.join(classpathSeparator);
}

void expectSuccess(ProcessResult result, {int expectedExitCode = 0}) {
  expect(result.exitCode, equals(expectedExitCode),
      reason: 'exit code was ${result.exitCode}.\n'
          '  => stdout:\n${result.stdout.join('\n')}\n'
          '  => stderr:\n${result.stderr.join('\n')}');
}

Future<ProcessResult> runJb(Directory workingDir,
    [List<String> args = const []]) {
  return runProcess(jbuildExecutable, workingDir, args);
}

Future<Process> startJb(Directory workingDir, [List<String> args = const []]) {
  return Process.start(jbuildExecutable, args,
      workingDirectory: workingDir.path);
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

List<T> lastItems<T>(int count, List<T> list) {
  assert(list.length >= count);
  return list.sublist(list.length - count);
}
