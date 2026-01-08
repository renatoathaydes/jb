import 'dart:io';

import 'package:collection/collection.dart';
import 'package:dartle/dartle.dart';
import 'package:path/path.dart' as p;

import '../jb.dart';

const _junitConsolePrefix =
    'org.junit.platform:junit-platform-console-standalone:';

const _junitPlatformPrefix = 'org.junit.platform:';

const _junitApiPrefix = 'org.junit.jupiter:junit-jupiter-api:';
const _spockPrefix = 'org.spockframework:spock-core:';
const junitRunnerJarNamePrefix = 'junit-platform-console-standalone-';
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
  return '$_junitConsolePrefix$version';
}

/// Dependency coordinates for the Spock Test Runner.
String spockRunnerLib(TestConfig testConfig) {
  final version = testConfig.spockVersion ?? '';
  return '$_spockPrefix$version:jar';
}

/// Find out the JUnit Launcher subcommand to use.
///
/// Since version 1.10, they warn that `execute` must be used, so
/// we try to find out which version we're using and if that's 1.10
/// or above, `execute` is returned, otherwise `null`.
Future<String?> junitTestSubcommand(String junitLauncherDir) async {
  await for (final file in Directory(junitLauncherDir).list()) {
    if (!file.path.endsWith('.jar')) {
      continue;
    }
    final name = p.basenameWithoutExtension(file.path);
    if (name.startsWith(junitRunnerJarNamePrefix)) {
      final versionParts = name
          .substring(junitRunnerJarNamePrefix.length)
          .split(r'.')
          .take(2)
          .map(int.tryParse)
          .toList(growable: false);
      logger.fine(() => 'JUnit Launcher version: $versionParts');
      if (versionParts.length == 2) {
        final major = versionParts[0] ?? 0;
        final minor = versionParts[1] ?? 0;
        // JUnit since version 1.10 expects use to use a sub-command 'execute'.
        if (major > 1 || (major == 1 && minor >= 10)) {
          return 'execute';
        }
      }
    }
  }
  return null;
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
