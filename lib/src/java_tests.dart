import '../jbuild_cli.dart';

const _junitConsolePrefix =
    'org.junit.platform:junit-platform-console-standalone:';

const _junitApiPrefix = 'org.junit.jupiter:junit-jupiter-api:';

const junitRunnerLibsDir = 'test-runner';

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

JUnit? findJUnitSpec(Map<String, DependencySpec> dependencies) {
  String? junitApiVersion = dependencies.entries
      .where((e) => e.value.scope.includedInCompilation())
      .findVersion(_junitApiPrefix);

  if (junitApiVersion == null) return null;

  String? junitConsoleVersion = dependencies.entries
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
