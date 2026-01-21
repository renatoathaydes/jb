import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:actors/actors.dart';
import 'package:dartle/dartle.dart'
    show failBuild, profile, activateLogging, elapsedTime;
import 'package:logging/logging.dart' as log;
import 'package:logging/logging.dart' show Level;
import 'package:path/path.dart' as p;

import '../config.dart' show ResolvedDependencies, logger;
import '../utils.dart';

typedef DepsCache = Sendable<DepsCacheMessage, ResolvedDependencies>;

Actor<DepsCacheMessage, ResolvedDependencies> createDepsActor(
  Level level,
  bool colorfulLog,
) => Actor.create(
  wrapHandlerWithCurrentDir(() => _DepsCacheHandler(level, colorfulLog)),
);

sealed class DepsCacheMessage {
  // This is instantiated when we create the DepsCacheMessage, but NOT when
  // an Actor de-serializes the value.
  final String workingDirectory = Directory.current.path;
  final String file;

  DepsCacheMessage(this.file);
}

class AddDeps extends DepsCacheMessage {
  final ResolvedDependencies deps;

  AddDeps(super.file, this.deps);
}

class GetDeps extends DepsCacheMessage {
  GetDeps(super.file);
}

final class _DepsCacheHandler
    with Handler<DepsCacheMessage, ResolvedDependencies> {
  final Map<String, Future<ResolvedDependencies>> _cache = {};
  final Level _level;
  final bool _colorfulLog;

  _DepsCacheHandler(this._level, this._colorfulLog);

  @override
  void init() {
    activateLogging(_level, colorfulLog: _colorfulLog);
  }

  @override
  FutureOr<ResolvedDependencies> handle(DepsCacheMessage message) {
    switch (message) {
      case AddDeps(file: var file, deps: var deps, workingDirectory: var dir):
        cache(dir, file, deps);
        return deps;
      case GetDeps(file: var file, workingDirectory: var dir):
        return parseIfAbsent(dir, file);
    }
  }

  void cache(String dir, String file, ResolvedDependencies deps) {
    final path = p.isRelative(file) ? p.join(dir, file) : file;
    logger.fine(() => 'Caching resolved dependencies stored in $path');
    _cache[path] = Future.value(deps);
  }

  Future<ResolvedDependencies> parseIfAbsent(String dir, String file) {
    final path = p.isRelative(file) ? p.join(dir, file) : file;
    final cachedValue = _cache[path];
    if (cachedValue != null) {
      logger.finer(() => 'Dependencies Cache hit: $path');
      return cachedValue;
    }
    logger.finer(() => 'Dependencies Cache miss: $path');
    final future = _parse(File(path));
    _cache[path] = future;
    return future;
  }
}

Future<ResolvedDependencies> _parse(File file) async {
  logger.fine(() => 'Parsing dependencies file: ${file.path}');
  final stopwatch = Stopwatch()..start();
  final text = await file.readAsString();
  ResolvedDependencies result;
  try {
    result = ResolvedDependencies.fromJson(jsonDecode(text));
  } catch (e) {
    if (logger.isLoggable(log.Level.FINE)) {
      rethrow;
    }
    failBuild(
      reason:
          'Cannot parse dependencies file ${file.path}. '
          'This is likely to be due to the .jb-cache being from an older version of jb. '
          'Try running again with the -z option to ignore the cache',
    );
  }
  stopwatch.stop();
  logger.log(
    profile,
    () =>
        'Parsed dependencies file from ${file.path} '
        'in ${elapsedTime(stopwatch)}.',
  );
  return result;
}
