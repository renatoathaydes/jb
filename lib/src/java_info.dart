import 'dart:io';

import 'package:conveniently/conveniently.dart';
import 'package:dartle/dartle_dart.dart';
import 'package:jb/jb.dart';
import 'package:jb/src/utils.dart'
    show classpathSeparator, BinaryStreamExtension;
import 'package:path/path.dart' as p;

/// Information about a Java installation, as read from `$JAVA_HOME/release`.
class JavaInfo {
  /// The value of `JAVA_VERSION`, e.g. `"21.0.3"`.
  final String version;

  /// The detected JAVA_HOME (the directory containing the `release` file).
  final String javaHome;

  JavaInfo({required this.version, required this.javaHome});

  /// Major version as an int (e.g. `21` for `"21.0.3"`, `8` for `"1.8.0_412"`).
  late final int? majorVersion = () {
    final parts = version.split('.');
    if (parts.isEmpty) return null;
    final first = int.tryParse(parts[0]);
    // Legacy "1.8.x" style: the real major is the second component.
    if (first == 1 && parts.length >= 2) {
      return int.tryParse(parts[1]);
    }
    return first;
  }();

  @override
  String toString() => 'JavaInfo(version: $version, javaHome: $javaHome)';
}

/// Detects the Java version of the `java` executable on `PATH` (falling back
/// to the `JAVA_HOME` environment variable) without launching a JVM.
///
/// Returns `null` if no `java` binary can be located, or if its `release`
/// file is missing or doesn't contain a `JAVA_VERSION` entry.
Future<JavaInfo?> detectJavaInfo() async {
  final javaHome = await _findJavaHome();
  if (javaHome == null) return null;

  final releaseFile = File(p.join(javaHome, 'release'));
  if (!await releaseFile.exists()) return null;

  final javaVersion = await _findJavaVersionInReleaseFile(
    releaseFile.openRead().linesUtf8Encoding(),
  );

  if (javaVersion == null || javaVersion.isEmpty) return null;

  return JavaInfo(version: javaVersion, javaHome: javaHome);
}

/// Locates JAVA_HOME by:
///   1. Using the `JAVA_HOME` environment variable if available.
///   2. Finding `java` on `PATH` and walking up from `<home>/bin/java`.
Future<String?> _findJavaHome() async {
  final stopWatch = Stopwatch()..start();
  final envHome = Platform.environment['JAVA_HOME'];
  if (envHome != null && envHome.isNotEmpty) return envHome;

  logger.fine(
    () =>
        'JAVA_HOME is not set, trying to find java in PATH. '
        'Set the JAVA_HOME environment variable to avoid indeterminism.',
  );

  // no JAVA_HOME set, try to find it the hard way in PATH.
  final javaPath = await _findOnPath('java');
  if (javaPath != null) {
    try {
      // Resolve symlinks (e.g. /usr/bin/java -> /etc/alternatives/java -> ...).
      final real = await File(javaPath).resolveSymbolicLinks();
      // `<home>/bin/java`  ->  `<home>`
      final result = File(real).parent.parent.path;
      logger.log(
        profile,
        () => 'Found Java home from PATH in ${elapsedTime(stopWatch)}',
      );
      return result;
    } on FileSystemException {
      // the `java` command is not in an expected location, give up!
    }
  }
  return null;
}

/// Searches `PATH` (and `PATHEXT` on Windows) for [executable].
Future<String?> _findOnPath(String executable) async {
  final pathEnv = Platform.environment['PATH'];
  if (pathEnv == null || pathEnv.isEmpty) return null;

  final dirs = pathEnv.split(classpathSeparator);
  final extensions = _executableExtensions();

  for (final dir in dirs) {
    if (dir.isEmpty) continue;
    for (final ext in extensions) {
      final candidate = File(p.join(dir, '$executable$ext'));
      if (await candidate.exists()) return candidate.path;
    }
  }
  return null;
}

List<String> _executableExtensions() {
  if (!Platform.isWindows) return const [''];
  final extensions = Platform.environment['PATHEXT'].vmapOr(
    (pext) => pext.split(';'),
    () => const ['.EXE', '.BAT', '.CMD', '.COM'],
  );
  if (extensions.contains('')) {
    return extensions;
  }
  // Include '' so an explicitly-named `java.exe` on PATH still resolves.
  return ['', ...extensions];
}

/// Parses a JDK `release` file: a series of `KEY="value"` lines.
/// Find the Java Version and return it, or `null` if not present.
Future<String?> _findJavaVersionInReleaseFile(Stream<String> lines) async {
  await for (final line in lines) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) continue;

    final eq = trimmed.indexOf('=');
    if (eq <= 0) continue;

    final key = trimmed.substring(0, eq).trim();
    if (key != 'JAVA_VERSION') continue;

    var value = trimmed.substring(eq + 1).trim();

    // Strip surrounding double quotes, if present.
    if (value.length >= 2 && value.startsWith('"') && value.endsWith('"')) {
      value = value.substring(1, value.length - 1);
    }
    return value;
  }
  return null;
}
