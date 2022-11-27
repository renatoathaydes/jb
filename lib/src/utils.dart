import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dartle/dartle.dart';
import 'package:path/path.dart' as p;

import 'jbuild_jar.g.dart';
import 'properties.dart';
import 'paths.dart';
import 'config.dart';

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

extension AnyExtension<T> on T? {
  T orThrow(String error) {
    if (this == null) throw DartleException(message: error);
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

extension ListExtension on List<String> {
  List<String> merge(List<String> other, Properties props) => followedBy(other)
      .map((e) => resolveString(e, props))
      .toList(growable: false);

  bool _javaRuntimeArg(String arg) => arg.startsWith('-J-');

  Iterable<String> javaRuntimeArgs() =>
      where(_javaRuntimeArg).map((e) => e.substring(2));

  Iterable<String> notJavaRuntimeArgs() => where(_javaRuntimeArg.not);
}

extension SetExtension on Set<String> {
  Set<String> merge(Set<String> other, Properties props) =>
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
