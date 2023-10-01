import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:conveniently/conveniently.dart';
import 'package:dartle/dartle.dart';
import 'package:path/path.dart' as p;

import 'config.dart';
import 'jbuild_jar.g.dart';
import 'paths.dart';
import 'properties.dart';

typedef Closable = FutureOr<void> Function();

final classpathSeparator = Platform.isWindows ? ';' : ':';

Future<File> createIfNeededAndGetJBuildJarFile() async {
  final file = File(jbuildJarPath()).absolute;
  if (!await file.exists()) {
    logger.info(const PlainMessage('Creating JBuild jar'));
    await _createJBuildJar(file);
  }
  return file;
}

Future<void> _createJBuildJar(File jar) async {
  await jar.parent.create(recursive: true);
  await jar.writeAsBytes(base64Decode(jbuildJarB64));
  logger.info(() => PlainMessage('JBuild jar saved at ${jar.path}'));
}

extension NullIterable<T> on Iterable<T?> {
  Iterable<T> whereNonNull() sync* {
    for (final item in this) {
      if (item != null) yield item;
    }
  }
}

extension on Stream<String> {
  Stream<String> followedBy(Iterable<String> rest) async* {
    await for (final s in this) {
      yield s;
    }
    for (final s in rest) {
      yield s;
    }
  }
}

extension PathIterable on Iterable<String> {
  Stream<File> collectFilePaths() async* {
    for (final path in this) {
      if (await FileSystemEntity.isFile(path)) yield File(path);
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

extension ListExtension on Iterable<String> {
  List<String> merge(Iterable<String> other, Properties props) =>
      followedBy(other)
          .map((e) => resolveString(e, props))
      .toList(growable: false);

  bool _javaRuntimeArg(String arg) => arg.startsWith('-J-');

  Iterable<String> javaRuntimeArgs() =>
      where(_javaRuntimeArg).map((e) => e.substring(2));

  Iterable<String> notJavaRuntimeArgs() => where(_javaRuntimeArg.not$);
}

extension SetExtension on Set<String> {
  Set<String> merge(Iterable<String> other, Properties props) =>
      followedBy(other).map((e) => resolveString(e, props)).toSet();
}

extension MapExtension<V> on Map<String, V> {
  Map<String, V> union(Map<String, V> other) =>
      Map.fromEntries(entries.followedBy(other.entries));
}

extension StringMapExtension on Map<String, String> {
  Map<String, String> merge(Map<String, String> other, Properties props) =>
      Map.fromEntries(entries.followedBy(other.entries).map((e) => MapEntry(
          resolveString(e.key, props), resolveString(e.value, props))));
}

extension DependencyMapExtension on Map<String, DependencySpec> {
  Map<String, DependencySpec> merge(
          Map<String, DependencySpec> other, Properties props) =>
      Map.fromEntries(entries.followedBy(other.entries).map((e) => MapEntry(
          resolveString(e.key, props), e.value.resolveProperties(props))));
}

extension MapEntryIterable<K, V> on Iterable<MapEntry<K, V>> {
  Map<K, V> toMap() {
    return {for (final entry in this) entry.key: entry.value};
  }
}

extension DirectoryExtension on Directory {
  Future<String?> toClasspath([Set<File> extraEntries = const {}]) async =>
      await exists()
          ? list()
              .where((f) =>
                  FileSystemEntity.isFileSync(f.path) &&
                  p.extension(f.path) == '.jar')
              .map((f) => f.path)
              .followedBy(extraEntries.map((f) => f.path))
              .join(classpathSeparator)
          : null;

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

extension NullableStringExtension on String? {
  String? removeFromEnd(Set<String> suffixes) {
    final self = this;
    if (self == null || suffixes.isEmpty) return self;
    var result = self;
    for (final suffix in suffixes) {
      if (result.endsWith(suffix)) {
        result = result.substring(0, result.length - suffix.length);
        return result;
      }
    }
    return result;
  }
}

extension BinaryStreamExtension on Stream<List<int>> {
  Future<String> text() => transform(utf8.decoder).join();

  Stream<String> lines() =>
      transform(utf8.decoder).transform(const LineSplitter());
}
