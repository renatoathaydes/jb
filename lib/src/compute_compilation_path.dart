import 'dart:io';

import 'package:actors/actors.dart';
import 'package:conveniently/conveniently.dart';
import 'package:dartle/dartle.dart' show activateLogging;
import 'package:dartle/dartle_cache.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

import 'compilation_path.g.dart';
import 'config.dart';
import 'jvm_executor.dart';
import 'utils.dart';

class CompilationPathFiles {
  final DartleCache cache;
  final String compileClassPath,
      compileModulePath,
      runtimeClassPath,
      runtimeModulePath;

  CompilationPathFiles(this.cache)
    : compileClassPath = p.join(cache.rootDir, 'compile-class-path.txt'),
      compileModulePath = p.join(cache.rootDir, 'compile-module-path.txt'),
      runtimeClassPath = p.join(cache.rootDir, 'runtime-class-path.txt'),
      runtimeModulePath = p.join(cache.rootDir, 'runtime-module-path.txt');

  FileCollection asFileCollection({bool runtime = false}) => runtime
      ? files([runtimeClassPath, runtimeModulePath])
      : files([compileClassPath, compileModulePath]);
}

sealed class CompilationPathMessage {
  final String libsDir;

  const CompilationPathMessage(this.libsDir);
}

final class JBuildModuleOutputLine extends CompilationPathMessage {
  final String line;

  const JBuildModuleOutputLine(super.libsDir, this.line);
}

final class ReturnCompilationPath extends CompilationPathMessage {
  const ReturnCompilationPath(super.libsDir);
}

/// Creates the actor that will consume the output of JBuild's command to
/// obtain the project's compilation path.
Actor<CompilationPathMessage, CompilationPath?> createCompilationPathActor(
  Level level,
) => Actor.create(() => _CompilePathsHandler(level));

/// Implementation of the 'createJavaCompilationPath' task.
Future<void> computeCompilationPath(
  String taskName,
  JbConfiguration config,
  String workingDir,
  JBuildSender jBuildSender,
  Sendable<CompilationPathMessage, CompilationPath?> compPath,
  String compileLibsDir,
  CompilationPathFiles files,
) async {
  final preArgs = config.preArgs(workingDir);
  await _computePaths(
    taskName,
    preArgs,
    jBuildSender,
    compileLibsDir,
    compPath,
  ).then(_writePaths.curry2(files.compileClassPath, files.compileModulePath));
}

Future<void> computeRuntimePath(
  String taskName,
  JbConfiguration config,
  String workingDir,
  JBuildSender jBuildSender,
  String runtimeLibsDir,
  Sendable<CompilationPathMessage, CompilationPath?> compPath,
  CompilationPathFiles files,
) async {
  final preArgs = config.preArgs(workingDir);
  await _computePaths(
    taskName,
    preArgs,
    jBuildSender,
    runtimeLibsDir,
    compPath,
  ).then(_writePaths.curry2(files.runtimeClassPath, files.runtimeModulePath));
}

Future<CompilationPath> _computePaths(
  String taskName,
  List<String> preArgs,
  JBuildSender jBuildSender,
  String libsDir,
  Sendable<CompilationPathMessage, CompilationPath?> compPath,
) async {
  final directory = Directory(libsDir);
  if (!await directory.exists()) {
    return const CompilationPath(modules: [], jars: []);
  }
  final jars = await directory
      .list()
      .where((f) => p.extension(f.path) == '.jar')
      .map((f) => f.path)
      .toList();

  await jBuildSender.send(
    RunJBuild(taskName, [
      ...preArgs,
      'module',
      ...jars,
    ], _Sender(compPath, libsDir)),
  );
  return (await compPath.send(ReturnCompilationPath(libsDir)))!;
}

Future<void> _writePaths(
  String classPathFile,
  String modulePathFile,
  CompilationPath paths,
) async {
  // TODO write jars and modules as JSON to the files to enable more advanced
  // features later, like checking module and required Java versions.
  await File(
    classPathFile,
  ).writeAsString(paths.jars.map((j) => j.path).join(classpathSeparator));
  await File(
    modulePathFile,
  ).writeAsString(paths.modules.map((j) => j.path).join(classpathSeparator));
}

/// Converts messages of type [String] to [JBuildModuleOutputLine].
class _Sender with Sendable<String, void> {
  final Sendable<CompilationPathMessage, void> _actor;
  final String _libsDir;

  _Sender(this._actor, this._libsDir);

  @override
  Future<void> send(String message) async =>
      await _actor.send(JBuildModuleOutputLine(_libsDir, message));
}

class _CompilePathsState {
  /// lines being parsed
  List<String>? lines = [];

  /// final result (lines must be null after this is set)
  CompilationPath? result;

  void addLine(String line) => lines!.add(line);
}

class _CompilePathsHandler
    with Handler<CompilationPathMessage, CompilationPath?> {
  final Map<String, _CompilePathsState> _stateByLibsDir = {};
  final Level _level;

  _CompilePathsHandler(this._level);

  @override
  void init() {
    activateLogging(_level);
  }

  @override
  CompilationPath? handle(CompilationPathMessage message) {
    return switch (message) {
      JBuildModuleOutputLine(libsDir: var d, line: var l) => _addLine(d, l),
      ReturnCompilationPath(libsDir: var d) => _returnCompilationPath(d),
    };
  }

  CompilationPath? _addLine(String dir, String line) {
    _stateByLibsDir.putIfAbsent(dir, () => _CompilePathsState()).addLine(line);
    return null;
  }

  CompilationPath _returnCompilationPath(String libsDir) {
    return _stateByLibsDir[libsDir].vmapOr((state) {
      var result = state.result;
      if (result != null) return result;
      result = parseModules(state.lines!);
      state.result = result;
      state.lines = null;
      return result;
    }, () => const CompilationPath(modules: [], jars: []));
  }
}

final _simpleJar = RegExp('File (.*) is not a module.\$');

final _automaticModule = RegExp(
  'File (.*) is an automatic-module: ([a-zA-Z0-9_.]+)\$',
);

// File ../libs/slf4j-simple-2.0.16.jar contains a Java module:
final _javaModule = RegExp('File (.*) contains a Java module:\$');

CompilationPath parseModules(List<String> lines) {
  final jars = <Jar>[];
  final modules = <Module>[];

  final iterator = lines.iterator;
  while (iterator.moveNext()) {
    final line = iterator.current;
    var match = _simpleJar.matchAsPrefix(line);
    if (match != null) {
      final path = match.group(1)!;
      logger.fine(() => 'Simple jar: $path');
      jars.add(_parse(iterator, _jar.curry(path), expectedLine: 'JavaVersion'));
      continue;
    }
    match = _automaticModule.matchAsPrefix(line);
    if (match != null) {
      final path = match.group(1)!;
      final moduleName = match.group(2)!;
      logger.fine(() => 'Automatic-module: $moduleName, path: $path');
      modules.add(
        _parse(
          iterator,
          _autoModule.curry2(moduleName, path),
          expectedLine: 'JavaVersion',
        ),
      );
      continue;
    }
    match = _javaModule.matchAsPrefix(line);
    if (match != null) {
      modules.add(_parseModule(match.group(1)!, iterator));
    }
  }
  return CompilationPath(modules: modules, jars: jars);
}

Jar _jar(String path, String javaVersion) =>
    Jar(javaVersion: javaVersion, path: path);

Module _autoModule(String name, String path, String javaVersion) => Module(
  javaVersion: javaVersion,
  name: name,
  path: path,
  automatic: true,
  version: '',
  flags: '',
  requires: const [],
);

T _parse<T>(
  Iterator<String> iterator,
  T Function(String line) create, {
  required String expectedLine,
  String indentation = '  ',
  bool moveNext = true,
}) {
  if (moveNext && !iterator.moveNext()) {
    throw JBuildModuleOutputParserError('Expected $expectedLine line, got EOF');
  }
  final line = iterator.current;
  final prefix = '$indentation$expectedLine:';
  if (line.startsWith(prefix)) {
    final value = line.substring(prefix.length).trim();
    return create(value);
  }
  throw JBuildModuleOutputParserError(
    'Expected $expectedLine line, got "$line"',
  );
}

Module _parseModule(String path, Iterator<String> iterator) {
  final javaVersion = _parse(iterator, identity, expectedLine: 'JavaVersion');
  final name = _parse(iterator, identity, expectedLine: 'Name');
  final version = _parse(iterator, identity, expectedLine: 'Version');
  final flags = _parse(iterator, identity, expectedLine: 'Flags');
  final requires = _parseRequires(iterator);

  logger.fine(() => 'Java module: $name, path: $path');

  return Module(
    javaVersion: javaVersion,
    path: path,
    name: name,
    automatic: false,
    version: version,
    flags: flags,
    requires: requires,
  );
}

List<Requirement> _parseRequires(Iterator<String> iterator) {
  final result = <Requirement>[];
  final requires = _parse(iterator, identity, expectedLine: 'Requires');
  if (requires.isNotEmpty) {
    throw JBuildModuleOutputParserError(
      'Requires line should have no content, but got "$requires"',
    );
  }
  while (iterator.moveNext()) {
    final line = iterator.current;
    if (!line.startsWith('    Module: ')) {
      // assume there's no more modules to parse
      break;
    }
    final name = _parse(
      iterator,
      identity,
      expectedLine: 'Module',
      indentation: '    ',
      // we already moved above to check if this is a Module
      moveNext: false,
    );
    final version = _parse(
      iterator,
      identity,
      expectedLine: 'Version',
      indentation: '      ',
    );
    final flags = _parse(
      iterator,
      identity,
      expectedLine: 'Flags',
      indentation: '      ',
    );
    result.add(Requirement(module: name, version: version, flags: flags));
  }
  return result;
}

class JBuildModuleOutputParserError extends Error {
  final String message;

  JBuildModuleOutputParserError(this.message);

  @override
  String toString() {
    return 'JBuildModuleOutputError{message: $message}';
  }
}
