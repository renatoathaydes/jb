import 'package:dartle/dartle.dart';

import '../jb.dart';

const _junitConsolePrefix =
    'org.junit.platform:junit-platform-console-standalone:';

const _junitApiPrefix = 'org.junit.jupiter:junit-jupiter-api:';
const _spockPrefix = 'org.spockframework:spock-core:';

const junitRunnerLibsDir = 'test-runner';

/// Testing Framework information.
typedef TestConfig = ({
  String? apiVersion,
  String? consoleVersion,
  String? spockVersion,
});

/// Find Testing framework information from a jb project dependencies.
TestConfig createTestConfig(
    Iterable<MapEntry<String, DependencySpec>> dependencies) {
  String? junitApiVersion = dependencies
      .where((e) => e.value.scope.includedInCompilation())
      .findVersion(_junitApiPrefix);

  String? spockVersion = dependencies
      .where((e) => e.value.scope.includedInCompilation())
      .findVersion(_spockPrefix);

  String? junitConsoleVersion = dependencies
      .where((e) => e.value.scope.includedAtRuntime())
      .findVersion(_junitConsolePrefix);

  return (
    apiVersion: junitApiVersion,
    consoleVersion: junitConsoleVersion,
    spockVersion: spockVersion,
  );
}

/// Validate that the test configuration is valid for running tests.
void validateTestConfig(TestConfig config) {
  logger.fine(() => 'Validating test configuration: $config');
  if (config.apiVersion == null && config.spockVersion == null) {
    throw DartleException(
        message: 'cannot run tests as no test libraries have been detected.\n'
            'To use JUnit, add the JUnit API as a dependency:\n'
            '    "$_junitApiPrefix<version>:"\n'
            'For Spock tests, add the spock-core dependency:\n'
            '    $_spockPrefix<version>:');
  }
}

/// Dependency coordinates for the JUnit ConsoleLauncher.
String junitConsoleLib() {
  return '$_junitConsolePrefix:jar';
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
