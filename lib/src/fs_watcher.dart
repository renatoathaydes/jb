import 'dart:async';
import 'dart:io';

import 'package:conveniently/conveniently.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

import 'config.dart';

class _CancellableAction {
  bool isCancelled = false;
  void Function() action;

  _CancellableAction(this.action);

  void call() {
    if (isCancelled) return;
    action();
  }
}

final class FileSystemWatcher {
  final List<Directory> directories;
  final FutureOr<void> Function(List<FileSystemEvent> events) onChange;
  final Function? onError;
  final Duration bouncePeriod;
  final String loggerName;

  /// created on start, set to null on stop
  _FileLogger? _log;

  bool _running = false;

  final Map<String, StreamSubscription<FileSystemEvent>> _subscriptions = {};

  _CancellableAction? _nextBounce;
  final List<FileSystemEvent> _eventQueue = [];

  /// Ensures that only one action can enter _bounce() at a time.
  Future<void>? _bounceMutex;

  FileSystemWatcher(
    this.directories, {
    required this.onChange,
    this.onError,
    this.bouncePeriod = const Duration(milliseconds: 500),
    this.loggerName = 'fs_watcher',
  });

  Future<void> start() async {
    if (_running) {
      logger.warning('FileSystemWatcher is already started');
      return;
    }
    _running = true;

    _log = logger.level <= Level.FINE
        ? _FileLogger(
            '$loggerName-${DateTime.now().toIso8601String()}.log',
            logger.level,
          )
        : null;

    logger.info(
      () =>
          'Starting FileSystemWatcher, watching ${directories.map((d) => p.absolute(d.path)).join(', ')}',
    );
    _subscriptions.addAll(
      Map.fromEntries(
        await Stream.fromIterable(directories).asyncExpand(_watch).toList(),
      ),
    );
  }

  void stop() {
    if (!_running) return;
    logger.info('Stopping FileSystemWatcher');
    _running = false;
    for (final entry in _subscriptions.entries) {
      _cancel(entry.key, entry.value);
    }
    _log?.close();
    _log = null;
    _subscriptions.clear();
  }

  Stream<MapEntry<String, StreamSubscription<FileSystemEvent>>> _watch(
    Directory directory,
  ) async* {
    final dirs = [directory];
    while (dirs.isNotEmpty) {
      final dir = dirs.removeLast();
      _log?.fine(() => 'Watching directory: ${dir.path}');
      yield MapEntry(
        dir.path,
        dir
            .watch(recursive: false)
            .listen(_onEvent, onError: onError, cancelOnError: true),
      );
      await for (final next in dir.list()) {
        if (next is Directory) dirs.add(next);
      }
    }
  }

  void _cancel(String path, StreamSubscription<FileSystemEvent> subscription) {
    _log?.finer(() => 'Cancelling subscription for $path');
    subscription.cancel();
  }

  void _forget(String path) {
    final sub = _subscriptions.remove(path);
    if (sub != null) _cancel(path, sub);
  }

  void _onEvent(FileSystemEvent event) {
    _log?.finer(() => 'Received event: $event');
    _eventQueue.add(event);
    _nextBounce?.isCancelled = true;
    _CancellableAction(_bounce).vmap((future) {
      _nextBounce = future;
      Future.delayed(bouncePeriod, future.call);
    });
  }

  void _bounce() async {
    await _bounceMutex;
    final completer = Completer<void>();
    _bounceMutex = completer.future;
    try {
      final events = _drainEventQueue();
      if (events.isEmpty) {
        _log?.finer(() => 'No events to process');
        _nextBounce = null;
      } else {
        _log?.fine(() => 'Processing ${events.length} events');
        for (final event in events) {
          // for some reason, Dart documents that isDirectory is always false
          // for the delete event! So, always try to forget deleted directories
          // as that will not have any effect if the file is not being watched.
          if (event.isDirectory && event.type == FileSystemEvent.create) {
            final newEntries = await _watch(Directory(event.path)).toList();
            _subscriptions.addAll(Map.fromEntries(newEntries));
          } else if (event.type == FileSystemEvent.delete) {
            _forget(event.path);
          }
        }
        final result = onChange(events);
        _nextBounce = null;
        await result;
      }
    } finally {
      completer.complete();
      await _log?.flush();
    }
  }

  List<FileSystemEvent> _drainEventQueue() {
    final events = [..._eventQueue];
    _eventQueue.clear();
    return events;
  }
}

class _FileLogger(final String file, final Level level) {
  final IOSink _sink = File(file).openWrite(mode: FileMode.append);

  Future<void> close() async {
    await flush();
    await _sink.close();
  }

  Future<void> flush() => _sink.flush();

  void fine(String Function() msg) {
    if (level.value <= Level.FINE.value) {
      _log(msg());
    }
  }

  void finer(String Function() msg) {
    if (level.value <= Level.FINER.value) {
      _log(msg());
    }
  }

  void _log(String message) {
    _sink.writeln('${DateTime.now().toIso8601String()} - $message');
  }
}
