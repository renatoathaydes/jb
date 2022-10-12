import 'dart:async';
import 'dart:convert';
import 'dart:io';

// FIXME temporary implementation that assumes no parallel tasks...
//       should stop relying on Directory.current to allow parallelization.
// import 'package:file/chroot.dart';
// import 'package:file/file.dart' as fs;
// import 'package:file/local.dart';
import 'package:jbuild_cli/jbuild_cli.dart';
import 'package:path/path.dart' as p;
import 'package:synchronized/synchronized.dart' as sync;

import 'jbuild_jar.g.dart';
import 'paths.dart';

Future<File> createIfNeededAndGetJBuildJarFile() async {
  final file = File(jbuildJarPath());
  if (!await file.exists()) {
    print('Creating JBuild jar');
    await _createJBuildJar(file);
  }
  return file;
}

final _lock = sync.Lock(reentrant: true);

FutureOr<R> withCurrentDir<R>(String dir, FutureOr<R> Function() action) {
  return _lock.synchronized(() async {
    final previousCurrentDir = Directory.current;
    Directory.current = _dir(dir);
    try {
      return await action();
    } finally {
      Directory.current = previousCurrentDir;
    }
  });
}

Directory _dir(String path) => Directory(path);

// File _file(String path) => File(path);
//
// String _zoneCurrentDir(String dir) {
//   Zone? zone = Zone.current;
//   while (zone != null) {
//     String? cd = zone[#currentDir];
//     if (cd != null) {
//       return p.join(cd, dir);
//     }
//     zone = zone.parent;
//   }
//   return p.canonicalize(dir);
// }
//
// FutureOr<R> withCurrentDir<R>(String dir, FutureOr<R> Function() action) {
//   final parentZone = Zone.current;
//   final currentDir = _zoneCurrentDir(dir);
//   return runZoned(() {
//     return IOOverrides.runZoned(action,
//         createDirectory: (p) => parentZone.runUnary(_dir, p),
//         createFile: (p) => parentZone.runUnary(_file, p),
//         getCurrentDirectory: () => _dir(currentDir),
//         setCurrentDirectory: (_) =>
//         throw StateError('Not allowed to change current Directory'));
//   }, zoneValues: {#currentDir: currentDir});
// }

Future<void> _createJBuildJar(File jar) async {
  await jar.parent.create(recursive: true);
  await jar.writeAsBytes(base64Decode(jbuildJarB64));
}

Map<String, Object?> asJsonMap(Map map) {
  return map.map((dynamic key, dynamic value) {
    return MapEntry(key is String ? key : '$key', value);
  });
}

extension AnyExtension<T> on T? {
  T orThrow(error) {
    if (this == null) throw error;
    return this!;
  }
}

extension FunctionExtension<T> on bool Function(T) {
  bool Function(T) get not => (v) => !this(v);
}

extension NullIterable<T> on Iterable<T?> {
  Iterable<T> whereNonNull() sync* {
    for (final item in this) {
      if (item != null) yield item;
    }
  }
}

extension AsyncIterable<T> on Iterable<FutureOr<T>> {
  Stream<T> toStream() async* {
    for (final item in this) {
      yield await item;
    }
  }
}

extension MapEntryIterable<K, V> on Iterable<MapEntry<K, V>> {
  Map<K, V> toMap() {
    return {for (final entry in this) entry.key: entry.value};
  }
}

extension DirectoryExtension on Directory {
  Future<void> copyContentsInto(String destinationDir) async {
    if (!await exists()) return;
    await for (final child in list(recursive: true)) {
      if (child is Directory) {
        await Directory(
                p.join(destinationDir, p.relative(child.path, from: path)))
            .create();
      } else if (child is File) {
        await child
            .copy(p.join(destinationDir, p.relative(child.path, from: path)));
      }
    }
  }
}
