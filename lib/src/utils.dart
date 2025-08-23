import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:conveniently/conveniently.dart';
import 'package:dartle/dartle.dart';
import 'package:jb/jb.dart';
import 'package:path/path.dart' as p;

import 'jbuild_jar.g.dart';
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
  List<String> merge(Iterable<String> other, Properties props) => followedBy(
    other,
  ).map((e) => resolveString(e, props)).toSet().toList(growable: false);

  bool _javaRuntimeArg(String arg) => arg.startsWith('-J-');

  Iterable<String> javaRuntimeArgs() =>
      where(_javaRuntimeArg).map((e) => e.substring(2));

  Iterable<String> notJavaRuntimeArgs() => where(_javaRuntimeArg.not$);
}

extension ScmExtension on SourceControlManagement? {
  SourceControlManagement? merge(
    SourceControlManagement? other,
    Properties props,
  ) {
    return switch ((this, other)) {
      (null, null) => null,
      (SourceControlManagement self, null) => self.applying(props),
      (_, SourceControlManagement that) => that.applying(props),
    };
  }

  SourceControlManagement? applying(Properties props) {
    return this?.vmap(
      (self) => SourceControlManagement(
        connection: resolveString(self.connection, props),
        developerConnection: resolveString(self.developerConnection, props),
        url: resolveString(self.url, props),
      ),
    );
  }
}

extension DevelopersExtension on List<Developer> {
  List<Developer> merge(List<Developer> others, Properties props) {
    return [
      ...map((dev) => dev.applying(props)),
      ...others.map((dev) => dev.applying(props)),
    ];
  }
}

extension _DeveloperExtension on Developer {
  Developer applying(Properties props) {
    return Developer(
      name: resolveString(name, props),
      email: resolveString(email, props),
      organization: resolveString(organization, props),
      organizationUrl: resolveString(organizationUrl, props),
    );
  }
}

extension SetExtension on Set<String> {
  Set<String> merge(Iterable<String> other, Properties props) =>
      followedBy(other).map((e) => resolveString(e, props)).toSet();
}

extension MapExtension<V> on Map<String, V> {
  Map<String, V> union(Map<String, V> other) =>
      Map.fromEntries(entries.followedBy(other.entries));

  Map<String, Map<String, Object?>> ensureValidExtensionConfig() {
    return map((k, v) {
      if (v is Map) return MapEntry(k, v as Map<String, Object?>);
      failBuild(
        reason:
            "Invalid configuration value: '$k' is not a known jb "
            "configuration property. If it is a custom task configuration, "
            "then it must be a Map.",
      );
    });
  }
}

extension StringMapExtension on Map<String, String> {
  Map<String, String> merge(Map<String, String> other, Properties props) =>
      Map.fromEntries(
        entries
            .followedBy(other.entries)
            .map(
              (e) => MapEntry(
                resolveString(e.key, props),
                resolveString(e.value, props),
              ),
            ),
      );
}

extension DependencyMapExtension on Map<String, DependencySpec?> {
  Map<String, DependencySpec?> merge(
    Map<String, DependencySpec?> other,
    Properties props,
  ) {
    if (isEmpty) {
      if (other.isEmpty) return this;
      return other.entries.resolve(props);
    }
    if (other.isEmpty) {
      return entries.resolve(props);
    }
    final result = <String, DependencySpec?>{};
    // first, we visit the entries in this Map without resolving the values,
    // just resolve keys because we may need to merge the values anyway
    // in the next step.
    for (final entry in entries) {
      final key = resolveString(entry.key, props);
      result[key] = entry.value;
    }
    // then we visit the other Map, merging the entries with the same key
    final visitedInOther = <String>{};
    for (final entry in other.entries) {
      final key = resolveString(entry.key, props);
      result[key] = result[key].merge(entry.value, props);
      visitedInOther.add(key);
    }
    // finally, we need to resolve the values of the keys which were only
    // present in this Map (not visited in the previous step)
    for (final entry in result.entries.where(
      (e) => !visitedInOther.contains(e.key),
    )) {
      result[entry.key] = entry.value?.resolveProperties(props);
    }
    return result;
  }
}

extension MapEntryIterable on Iterable<MapEntry<String, DependencySpec?>> {
  Map<String, DependencySpec?> resolve(Map<String, Object?> props) {
    return Map.fromEntries(
      map(
        (e) => MapEntry(
          resolveString(e.key, props),
          e.value?.resolveProperties(props),
        ),
      ),
    );
  }
}

extension on DependencySpec? {
  DependencySpec? merge(DependencySpec? other, Map<String, Object?> props) {
    final self = this;
    if (self == null) return other?.resolveProperties(props);
    if (other == null) return self.resolveProperties(props);
    return DependencySpec(
      transitive: self.transitive || other.transitive,
      scope: self.scope.index < other.scope.index ? self.scope : other.scope,
      path: resolveOptionalString(other.path, props),
      exclusions: self.exclusions.merge(other.exclusions, props),
    );
  }
}

extension DirectoryExtension on Directory {
  Future<String?> toClasspath([
    Set<FileSystemEntity> extraEntries = const {},
  ]) async => await exists()
      ? list()
            .where(
              (f) =>
                  FileSystemEntity.isFileSync(f.path) &&
                  p.extension(f.path) == '.jar',
            )
            .map((f) => f.path)
            .followedBy(extraEntries.map((f) => f.path))
            .join(classpathSeparator)
      : null;

  Future<void> copyContentsInto(String destinationDir) async {
    if (!await exists()) return;
    await for (final child in list(recursive: true)) {
      if (child is Directory) {
        await Directory(
          p.join(destinationDir, p.relative(child.path, from: path)),
        ).create();
      } else if (child is File) {
        await child.copy(
          p.join(destinationDir, p.relative(child.path, from: path)),
        );
      }
    }
  }
}

extension FileExtension on File {
  Future<void> withSink(Future<void> Function(IOSink) action) async {
    final handle = openWrite();
    try {
      await action(handle);
    } finally {
      await handle.flush();
      await handle.close();
    }
  }
}

extension StringExtension on String {
  String replaceExtension(String ext) => '${p.withoutExtension(this)}$ext';

  String joinClasspath(String classpath) {
    if (classpath.isEmpty) return this;
    return "$this$classpathSeparator$classpath";
  }

  String asDirPath() {
    if (Platform.isWindows && endsWith('/')) {
      return "${substring(0, length - 1)}\\";
    }
    if (endsWith(Platform.pathSeparator)) {
      return this;
    }
    return "$this${Platform.pathSeparator}";
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

  String ifBlank(String Function() orElse) {
    final value = this?.trim() ?? '';
    if (value.isEmpty) return orElse();
    return value;
  }

  T? ifNonBlank<T>(T? Function(String) then) {
    final value = this?.trim() ?? '';
    if (value.isNotEmpty) return then(value);
    return null;
  }
}

extension BinaryStreamExtension on Stream<List<int>> {
  Future<String> textUtf8() => transform(utf8.decoder).join();

  Stream<String> linesDefaultEncoding() =>
      transform(const SystemEncoding().decoder).transform(const LineSplitter());

  Stream<String> linesUtf8Encoding() =>
      transform(utf8.decoder).transform(const LineSplitter());
}
