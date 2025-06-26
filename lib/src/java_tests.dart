import 'package:collection/collection.dart';
import 'package:dartle/dartle.dart';

import '../jb.dart';

const _junitConsolePrefix =
    'org.junit.platform:junit-platform-console-standalone:';

const _junitPlatformPrefix = 'org.junit.platform:';

const _junitApiPrefix = 'org.junit.jupiter:junit-jupiter-api:';
const _spockPrefix = 'org.spockframework:spock-core:';

const junitRunnerLibsDir = 'test-runner';

/// Testing Framework information.
typedef TestConfig = ({
  String? apiVersion,
  String? platformVersion,
  String? spockVersion,
});

/// Find Testing framework information from a jb project dependencies.
TestConfig createTestConfig(
  Iterable<MapEntry<String, DependencySpec>> dependencies,
) {
  String? junitApiVersion = dependencies.findVersion(_junitApiPrefix);
  String? spockVersion = dependencies.findVersion(_spockPrefix);
  String? junitPlatformVersion = dependencies.findVersion(_junitPlatformPrefix);

  return (
    apiVersion: junitApiVersion,
    platformVersion: junitPlatformVersion,
    spockVersion: spockVersion,
  );
}

/// Validate that the test configuration is valid for running tests.
void validateTestConfig(TestConfig config) {
  logger.fine(() => 'Validating test configuration: $config');
  if (!config.hasTestConfig()) {
    throw DartleException(
      message:
          'cannot run tests as no test libraries have been detected.\n'
          'To use JUnit, add the JUnit API as a dependency:\n'
          '    "$_junitApiPrefix<version>:"\n'
          'For Spock tests, add the spock-core dependency:\n'
          '    $_spockPrefix<version>:',
    );
  }
}

/// Get the dependency coordinates for the JUnit ConsoleLauncher.
///
/// Attempts to find the most appropriate version based on the project deps.
///
/// Returns `null` if cannot find a dependency on JUnit or Spock.
String? findTestRunnerLib(ResolvedDependencies resolvedDeps) {
  final deps = resolvedDeps.dependencies;
  final platformLib = deps
      .where((dep) => dep.artifact.startsWith(_junitPlatformPrefix))
      .firstOrNull;
  if (platformLib == null) {
    // we should use the latest version if we know the project
    // depends on the JUnit API or Spock
    if (deps.none(
      (dep) =>
          dep.artifact.startsWith(_junitApiPrefix) ||
          dep.artifact.startsWith(_spockPrefix),
    )) {
      return null;
    }
  }
  // empty version implies "latest"
  final version = platformLib?.artifact.findVersion(_junitPlatformPrefix) ?? '';
  return '$_junitConsolePrefix$version:jar';
}

/// Dependency coordinates for the Spock Test Runner.
String spockRunnerLib(TestConfig testConfig) {
  final version = testConfig.spockVersion ?? '';
  return '$_spockPrefix$version:jar';
}

extension on Iterable<MapEntry<String, DependencySpec>> {
  String? findVersion(String prefix) {
    for (final entry in this) {
      final version = entry.key.findVersion(prefix);
      if (version != null) {
        return version;
      }
    }
    return null;
  }
}

extension _VersionFinder on String {
  String? findVersion(String prefix) {
    if (startsWith(prefix)) {
      final suffix = substring(prefix.length);
      final colonIndex = suffix.lastIndexOf(':');
      if (colonIndex > 0 && colonIndex < suffix.length) {
        return suffix.substring(colonIndex + 1);
      }
      return suffix;
    }
    return null;
  }
}

extension TestConfigExtension on TestConfig {
  bool hasTestConfig() {
    return apiVersion != null || spockVersion != null;
  }
}
