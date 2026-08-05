import 'dart:async';
import 'dart:io';

import 'package:conveniently/conveniently.dart';

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

  List<StreamSubscription<FileSystemEvent>>? _subscriptions;

  _CancellableAction? _nextBounce;
  final List<FileSystemEvent> _eventQueue = [];

  /// Ensures that only one action can enter _bounce() at a time.
  Future<void>? _bounceMutex;

  FileSystemWatcher(
    this.directories, {
    required this.onChange,
    this.onError,
    this.bouncePeriod = const Duration(milliseconds: 500),
  });

  void start() {
    if (_subscriptions != null) {
      throw StateError('FileSystemWatcher is already started');
    }
    _subscriptions = directories
        .map(
          (dir) => dir.watch().listen(
            _onEvent,
            onError: onError,
            cancelOnError: true,
          ),
        )
        .toList();
  }

  void stop() {
    final subscriptions = _subscriptions;
    if (subscriptions == null) return;
    for (final subscription in subscriptions) {
      subscription.cancel();
    }
    _subscriptions = null;
  }

  void _onEvent(FileSystemEvent event) {
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
      final result = onChange(_drainEventQueue());
      _nextBounce = null;
      await result;
    } finally {
      completer.complete();
    }
  }

  List<FileSystemEvent> _drainEventQueue() {
    final events = [..._eventQueue];
    _eventQueue.clear();
    return events;
  }
}
