import 'dart:convert';
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

class CompilationPathFiles {
  final DartleCache cache;
  final String compilePath, runtimePath;

  CompilationPathFiles(this.cache)
    : compilePath = p.join(cache.rootDir, 'compilation-path.json'),
      runtimePath = p.join(cache.rootDir, 'runtime-path.json');

  FileCollection asFileCollection({bool runtime = false}) =>
      file(runtime ? runtimePath : compilePath);
}

sealed class CompilationPathMessage {
  final String key;

  const CompilationPathMessage(String artifactId, String libsDir)
    : key = "$artifactId:$libsDir";
}

final class JBuildModuleOutputLine extends CompilationPathMessage {
  final String line;

  const JBuildModuleOutputLine(super.artifactId, super.libsDir, this.line);
}

final class ReturnCompilationPath extends CompilationPathMessage {
  const ReturnCompilationPath(super.artifactId, super.libsDir);
}

/// Creates the actor that will consume the output of JBuild's command to
/// obtain the project's compilation path.
Actor<CompilationPathMessage, CompilationPath?> createCompilationPathActor(
  Level level,
) => Actor.create(() => _CompilePathsHandler(level));

/// Get the compilation path either from the Actor (which writes the file)
/// or directly from the file.
Future<CompilationPath> getCompilationPath(
  Sendable<CompilationPathMessage, CompilationPath?> compPathActor,
  CompilationPathFiles compPathFiles,
  String artifactId,
  String libsDir,
) async {
  final actorResponse = await compPathActor.send(
    ReturnCompilationPath(artifactId, libsDir),
  );
  if (actorResponse != null) {
    return actorResponse;
  }
  var compPathFile = File(compPathFiles.compilePath);
  if (!await compPathFile.exists()) {
    logger.fine('CompilationPath is empty');
    return const CompilationPath(modules: [], jars: []);
  }
  logger.fine(
    () =>
        'CompilationPath not available for $artifactId, '
        'reading it from cached file',
  );
  return CompilationPath.fromJson(
    jsonDecode(await compPathFile.readAsString()),
  );
}

/// Implementation of the 'createJavaCompilationPath' task.
Future<void> computeCompilationPath(
  String taskName,
  JbConfigContainer config,
  String workingDir,
  JBuildSender jBuildSender,
  Sendable<CompilationPathMessage, CompilationPath?> compPath,
  String compileLibsDir,
  CompilationPathFiles files,
) async {
  final artifactId = config.artifactId;
  final preArgs = config.config.preArgs(workingDir);
  await _computePaths(
    taskName,
    artifactId,
    preArgs,
    jBuildSender,
    compileLibsDir,
    compPath,
  ).then(_writePaths.curry(files.compilePath));
}

Future<void> computeRuntimePath(
  String taskName,
  JbConfigContainer config,
  String workingDir,
  JBuildSender jBuildSender,
  String runtimeLibsDir,
  Sendable<CompilationPathMessage, CompilationPath?> compPath,
  CompilationPathFiles files,
) async {
  final artifactId = config.artifactId;
  final preArgs = config.config.preArgs(workingDir);
  await _computePaths(
    taskName,
    artifactId,
    preArgs,
    jBuildSender,
    runtimeLibsDir,
    compPath,
  ).then(_writePaths.curry(files.runtimePath));
}

Future<CompilationPath> _computePaths(
  String taskName,
  String artifactId,
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
    ], _Sender(artifactId, compPath, libsDir)),
  );
  return (await compPath
      .send(ReturnCompilationPath(artifactId, libsDir))
      .timeout(const Duration(seconds: 5)))!;
}

Future<void> _writePaths(String classPathFile, CompilationPath paths) async {
  await File(classPathFile).writeAsString(jsonEncode(paths.toJson()));
}

/// Converts messages of type [String] to [JBuildModuleOutputLine].
class _Sender with Sendable<String, void> {
  final String _artifactId;
  final Sendable<CompilationPathMessage, void> _actor;
  final String _libsDir;

  _Sender(this._artifactId, this._actor, this._libsDir);

  @override
  Future<void> send(String message) async =>
      await _actor.send(JBuildModuleOutputLine(_artifactId, _libsDir, message));
}

class _CompilePathsState {
  /// lines being parsed
  List<String>? lines = [];

  /// final result (lines must be null after this is set)
  CompilationPath? result;

  void addLine(String line) {
    final currentLines = lines;
    if (currentLines == null) {
      throw StateError('Not expecting JBuild module output');
    }
    currentLines.add(line);
  }
}

class _CompilePathsHandler
    with Handler<CompilationPathMessage, CompilationPath?> {
  final Map<String, _CompilePathsState> _stateByKey = {};
  final Level _level;

  _CompilePathsHandler(this._level);

  @override
  void init() {
    activateLogging(_level);
  }

  @override
  CompilationPath? handle(CompilationPathMessage message) {
    return switch (message) {
      JBuildModuleOutputLine(key: var k, line: var l) => _addLine(k, l),
      ReturnCompilationPath(key: var k) => _returnCompilationPath(k),
    };
  }

  CompilationPath? _addLine(String key, String line) {
    _stateByKey.putIfAbsent(key, () => _CompilePathsState()).addLine(line);
    return null;
  }

  CompilationPath? _returnCompilationPath(String key) {
    return _stateByKey[key]?.vmap((state) {
      var result = state.result;
      if (result != null) {
        logger.fine(() => 'CompilationPath already computed for $key');
        return result;
      }
      if (state.lines == null) {
        throw StateError(
          'CompilationPath cannot be computed for $key (no JBuild output)',
        );
      }
      logger.fine(() => 'CompilationPath will be computed for $key');
      result = parseModules(state.lines!);
      logger.fine(() => 'CompilationPath was computed successfully for $key');
      state.result = result;
      state.lines = null;
      return result;
    });
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
