import 'package:collection/collection.dart';
import 'package:jb/jb.dart';
import 'package:test/test.dart';

Matcher equalsConfig(JbConfiguration expected) => _ConfigMatcher(expected);

class _ConfigMatcher extends Matcher {
  final JbConfiguration expected;

  const _ConfigMatcher(this.expected);

  @override
  Description describe(Description description) {
    return description.add('configuration should equal');
  }

  @override
  bool matches(item, Map matchState) {
    if (identical(expected, item)) return true;
    if (item is! JbConfiguration) {
      matchState[#reason] = 'wrong type: ${item.runtimeType}';
      return false;
    }
    if (expected.group != item.group) {
      matchState[#reason] =
          'group should be "${expected.group}" but is "${item.group}"';
      return false;
    }
    if (expected.module != item.module) {
      matchState[#reason] =
          'module should be "${expected.module}" but is "${item.module}"';
      return false;
    }
    if (expected.version != item.version) {
      matchState[#reason] =
          'version should be "${expected.version}" but is "${item.version}"';
      return false;
    }
    if (!const SetEquality().equals(expected.sourceDirs, item.sourceDirs)) {
      matchState[#reason] =
          'sourceDirs should be "${expected.sourceDirs}" but is "${item.sourceDirs}"';
      return false;
    }
    if (expected.output != item.output) {
      matchState[#reason] =
          'group should be "${expected.output}" but is "${item.output}"';
      return false;
    }
    if (!const SetEquality().equals(expected.resourceDirs, item.resourceDirs)) {
      matchState[#reason] =
          'resourceDirs should be "${expected.resourceDirs}" but is "${item.resourceDirs}"';
      return false;
    }
    if (expected.mainClass != item.mainClass) {
      matchState[#reason] =
          'mainClass should be "${expected.mainClass}" but is "${item.mainClass}"';
      return false;
    }
    if (!const ListEquality().equals(expected.javacArgs, item.javacArgs)) {
      matchState[#reason] =
          'javacArgs should be "${expected.javacArgs}" but is "${item.javacArgs}"';
      return false;
    }
    if (!const ListEquality().equals(expected.runJavaArgs, item.runJavaArgs)) {
      matchState[#reason] =
          'runJavaArgs should be "${expected.runJavaArgs}" but is "${item.runJavaArgs}"';
      return false;
    }
    if (!const ListEquality()
        .equals(expected.testJavaArgs, item.testJavaArgs)) {
      matchState[#reason] =
          'testJavaArgs should be "${expected.testJavaArgs}" but is "${item.testJavaArgs}"';
      return false;
    }
    if (!const MapEquality().equals(expected.javacEnv, item.javacEnv)) {
      matchState[#reason] =
          'javacEnv should be "${expected.javacEnv}" but is "${item.javacEnv}"';
      return false;
    }
    if (!const MapEquality().equals(expected.runJavaEnv, item.runJavaEnv)) {
      matchState[#reason] =
          'runJavaEnv should be "${expected.runJavaEnv}" but is "${item.runJavaEnv}"';
      return false;
    }
    if (!const MapEquality().equals(expected.testJavaEnv, item.testJavaEnv)) {
      matchState[#reason] =
          'testJavaEnv should be "${expected.testJavaEnv}" but is "${item.testJavaEnv}"';
      return false;
    }
    if (!const SetEquality().equals(expected.repositories, item.repositories)) {
      matchState[#reason] =
          'repositories should be "${expected.repositories}" but is "${item.repositories}"';
      return false;
    }
    if (!const MapEquality().equals(expected.dependencies, item.dependencies)) {
      matchState[#reason] =
          'dependencies should be "${expected.dependencies}" but is "${item.dependencies}"';
      return false;
    }
    if (!const SetEquality().equals(expected.exclusions, item.exclusions)) {
      matchState[#reason] =
          'exclusions should be "${expected.exclusions}" but is "${item.exclusions}"';
      return false;
    }
    if (expected.compileLibsDir != item.compileLibsDir) {
      matchState[#reason] =
          'compileLibsDir should be "${expected.compileLibsDir}" but is "${item.compileLibsDir}"';
      return false;
    }
    if (expected.runtimeLibsDir != item.runtimeLibsDir) {
      matchState[#reason] =
          'runtimeLibsDir should be "${expected.runtimeLibsDir}" but is "${item.runtimeLibsDir}"';
      return false;
    }
    if (expected.testReportsDir != item.testReportsDir) {
      matchState[#reason] =
          'testReportsDir should be "${expected.testReportsDir}" but is "${item.testReportsDir}"';
      return false;
    }
    if (!const MapEquality(values: DeepCollectionEquality.unordered())
        .equals(expected.properties, item.properties)) {
      matchState[#reason] =
          'properties should be "${expected.properties}" but is "${item.properties}"';
      return false;
    }
    return true;
  }

  @override
  Description describeMismatch(dynamic item, Description mismatchDescription,
      Map matchState, bool verbose) {
    if (matchState[#reason] != null) {
      mismatchDescription.add('${matchState[#reason]}');
    }
    return mismatchDescription;
  }
}
