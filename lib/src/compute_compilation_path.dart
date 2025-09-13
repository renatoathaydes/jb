import 'dart:convert';
import 'dart:io';

import 'package:actors/actors.dart';
import 'package:jb/src/compilation_path.g.dart';
import 'package:path/path.dart' as p;

import 'config.dart';
import 'jvm_executor.dart';
import 'utils.dart';

Future<void> computeCompilationPath(
  String taskName,
  JbConfiguration config,
  String workingDir,
  JBuildSender jBuildSender,
  String libsDir,
  File output,
) async {
  final jars = await Directory(libsDir)
      .list()
      .where((f) => p.extension(f.path) == '.jar')
      .map((f) => f.path)
      .toList();

  final outputConsumer = Actor.create(
    wrapHandlerWithCurrentDir(() => _FileOutput()),
  );
  CompilationPath compilationPath;
  try {
    await jBuildSender.send(
      RunJBuild(taskName, [
        ...config.preArgs(workingDir),
        'module',
        ...jars,
      ], _Sender(await outputConsumer.toSendable())),
    );
    compilationPath = (await outputConsumer.send(_sendContentsBack))!;
  } finally {
    await outputConsumer.close();
  }
  await output.writeAsString(jsonEncode(compilationPath.toJson()));
}

/// Converts messages of type [String] to [Object].
class _Sender with Sendable<String, void> {
  final Sendable<Object, void> _actor;

  _Sender(this._actor);

  @override
  Future<void> send(String message) async => await _actor.send(message);
}

const _sendContentsBack = #sendContentsBack;

class _FileOutput with Handler<Object, CompilationPath?> {
  final List<String> _lines = [];

  @override
  CompilationPath? handle(Object message) {
    if (message == _sendContentsBack) {
      return parseModules(_lines);
    }
    _lines.add(message as String);
    return null;
  }
}

final _simpleJar = RegExp('Jar (.*) is not a module.\$');

final _automaticModule = RegExp(
  'Jar (.*) is an automatic module: ([a-zA-Z0-9_.]+)\$',
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
      jars.add(_parse(iterator, _jar.curry(path), expectedLine: 'JavaVersion'));
      continue;
    }
    match = _automaticModule.matchAsPrefix(line);
    if (match != null) {
      final path = match.group(1)!;
      final moduleName = match.group(2)!;
      modules.add(
        _parse(
          iterator,
          _autoModule.curry(moduleName, path),
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
  final javaVersion = _parse(iterator, _identity, expectedLine: 'JavaVersion');
  final name = _parse(iterator, _identity, expectedLine: 'Name');
  final version = _parse(iterator, _identity, expectedLine: 'Version');
  final flags = _parse(iterator, _identity, expectedLine: 'Flags');
  final requires = _parseRequires(iterator);

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
  final requires = _parse(iterator, _identity, expectedLine: 'Requires');
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
      _identity,
      expectedLine: 'Module',
      indentation: '    ',
      // we already moved above to check if this is a Module
      moveNext: false,
    );
    final version = _parse(
      iterator,
      _identity,
      expectedLine: 'Version',
      indentation: '      ',
    );
    final flags = _parse(
      iterator,
      _identity,
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

// TODO move to conveniently lib
String _identity(String s) => s;

// TODO move to conveniently lib
extension<A, B, R> on R Function(A, B) {
  R Function(B) curry(A a) {
    return (b) => this(a, b);
  }
}

// TODO move to conveniently lib
extension<A, B, C, R> on R Function(A, B, C) {
  R Function(C) curry(A a, B b) {
    return (c) => this(a, b, c);
  }
}
