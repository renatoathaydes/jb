import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:actors/actors.dart';
import 'package:dartle/dartle.dart' show failBuild, profile;
import 'package:logging/logging.dart' as log;

import '../config.dart';

typedef DepsCache = Sendable<DepsCacheMessage, ResolvedDependencies>;

Actor<DepsCacheMessage, ResolvedDependencies> createDepsActor() =>
    Actor.create(_DepsCacheHandler.new);

sealed class DepsCacheMessage {
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

  @override
  FutureOr<ResolvedDependencies> handle(DepsCacheMessage message) {
    switch (message) {
      case AddDeps(file: var file, deps: var deps):
        cache(file, deps);
        return deps;
      case GetDeps(file: var file):
        return parseIfAbsent(file);
    }
  }

  void cache(String file, ResolvedDependencies deps) {
    logger.fine(() => 'Caching resolved dependencies stored in $file');
    _cache[file] = Future.value(deps);
  }

  Future<ResolvedDependencies> parseIfAbsent(String file) {
    final cachedValue = _cache[file];
    if (cachedValue != null) {
      logger.finer(() => 'Dependencies Cache hit: $file');
      return cachedValue;
    }
    logger.finer(() => 'Dependencies Cache miss: $file');
    final future = _parse(File(file));
    _cache[file] = future;
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
        'in ${stopwatch.elapsedMilliseconds} ms',
  );
  return result;
}
