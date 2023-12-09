import '../jb.dart';

const _junitConsolePrefix =
    'org.junit.platform:junit-platform-console-standalone:';

const _junitApiPrefix = 'org.junit.jupiter:junit-jupiter-api:';

const junitRunnerLibsDir = 'test-runner';

/// JUnit Testing Framework information.
class JUnit {
  final String apiVersion;
  final String consoleVersion;
  final bool runtimeIncludesJUnitConsole;

  const JUnit({
    required this.apiVersion,
    required this.consoleVersion,
    required this.runtimeIncludesJUnitConsole,
  });
}

/// Find JUnit information from a jb project dependencies, if available.
JUnit? findJUnitSpec(Iterable<MapEntry<String, DependencySpec>> dependencies) {
  String? junitApiVersion = dependencies
      .where((e) => e.value.scope.includedInCompilation())
      .findVersion(_junitApiPrefix);

  if (junitApiVersion == null) return null;

  String? junitConsoleVersion = dependencies
      .where((e) => e.value.scope.includedAtRuntime())
      .findVersion(_junitConsolePrefix);

  bool runtimeIncludesJUnitConsole = true;
  if (junitConsoleVersion == null) {
    junitConsoleVersion = '';
    runtimeIncludesJUnitConsole = false;
  }

  return JUnit(
    apiVersion: junitApiVersion,
    consoleVersion: junitConsoleVersion,
    runtimeIncludesJUnitConsole: runtimeIncludesJUnitConsole,
  );
}

/// Dependency coordinates for the JUnit ConsoleLauncher.
String junitConsoleLib(String version) {
  return '$_junitConsolePrefix$version:jar';
}

extension on Iterable<MapEntry<String, DependencySpec>> {
  String? findVersion(String prefix) {
    for (final entry in this) {
      if (entry.key.startsWith(prefix)) {
        final suffix = entry.key.substring(prefix.length);
        final colonIndex = suffix.indexOf(':');
        if (colonIndex > 0) {
          return suffix.substring(0, colonIndex);
        }
        return suffix;
      }
    }
    return null;
  }
}
