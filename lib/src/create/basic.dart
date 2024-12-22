import 'dart:io';

import 'package:conveniently/conveniently.dart';
import 'package:dartle/dartle.dart';
import 'package:path/path.dart' as p;

import '../config.dart';
import '../exec.dart';
import '../output_consumer.dart';
import '../paths.dart';
import 'helpers.dart';

const _testArtifactId = 'tests';

String _jbuildYaml(String groupId, String artifactId, String? mainClass,
        String dependencies) =>
    '''
group: $groupId
module: $artifactId
version: '0.0.0'

# default is src
source-dirs: [ src ]

# default is resources
resource-dirs: [ resources ]

${artifactId == _testArtifactId ? ''
            '# do not create a redundant jar for tests\n'
            'output-dir: build/classes\n' : '''
# The following options use the default values and could be omitted
compile-libs-dir: build/compile-libs
runtime-libs-dir: build/runtime-libs
test-reports-dir: build/test-reports

# Specify a jar to package this project into.
# Use `output-dir` instead to keep class files unpacked.
# default is `build/<project-dir>.jar`.
output-jar: build/$artifactId.jar${mainClass == null ? '' : '''\n
# To be able to use the 'run' task without arguments, specify the main-class to run.
# You can also run any class by invoking `jb run :--main-class=some.other.Class`.
main-class: $mainClass'''}
'''}
# dependencies can be Maven artifacts or other jb projects
dependencies:
$dependencies''';

String _mainJava(String package) => '''
package $package;

final class Main {
    static String greeting() {
        return "Hello world!";
    }
    public static void main(String[] args) {
        System.out.println(greeting());
    }
}
''';

String _mainTestJava(String package) => '''
package $package;

import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

final class MainTest {
  @Test
  void greetingTest() {
      assertThat(Main.greeting()).isEqualTo("Hello world!");
  }
}
''';

List<FileCreator> getBasicFileCreators(File jbuildFile,
    {required String groupId,
    required String artifactId,
    required String package,
    required bool createTestModule}) {
  const mainClass = 'Main';

  return [
    FileCreator(
        jbuildFile,
        () => jbuildFile.writeAsString(_jbuildYaml(
            groupId,
            artifactId,
            '$package.$mainClass',
            '    # Examples:\n'
                '    #   org.slf4j:slf4j-api:2.0.16:\n'
                '    #   com.google.guava:guava:33.4.0-jre:\n'
                '    #     transitive: false\n'
                '    #     scope: all\n'
                '    {}\n'))),
    createJavaFile(package, mainClass, 'src', _mainJava(package)),
    if (createTestModule) ..._createTestModule(groupId, package),
  ];
}

List<FileCreator> _createTestModule(String groupId, String package) {
  final javaTestCreator = createJavaFile(
      package, 'MainTest', p.join('test', 'src'), _mainTestJava(package));
  final buildFile = File(p.join('test', yamlJbFile));
  final buildFileCreator = FileCreator(
      buildFile,
      () async => buildFile.writeAsString(_jbuildYaml(
          groupId, _testArtifactId, null, await _computeTestDependencies())));
  return [javaTestCreator, buildFileCreator];
}

const junitJupiterApi = 'org.junit.jupiter:junit-jupiter-api';
const assertjCore = 'org.assertj:assertj-core';

Future<String> _computeTestDependencies() async {
  logger.fine(
      () => 'Fetching latest versions of $junitJupiterApi and $assertjCore');
  final versionsParser = _VersionsParser();
  final exitCode = await execJBuild('create-test-project',
      File(jbuildJarPath()), ['-q'], 'versions', [junitJupiterApi, assertjCore],
      onStdout: versionsParser);
  if (exitCode != 0) {
    failBuild(reason: 'jbuild versions command failed', exitCode: exitCode);
  }
  logger
      .fine(() => 'Latest versions obtained: ${versionsParser.latestVersions}');
  final latestJUnitVersion = versionsParser.latestVersions[junitJupiterApi]
      .orThrow(() => failBuild(reason: 'Cannot find JUnit API latest version'));
  final latestAssertjVersion = versionsParser.latestVersions[assertjCore]
      .orThrow(() => failBuild(reason: 'Cannot find Assertj latest version'));
  return '''\
  $junitJupiterApi:$latestJUnitVersion:
  $assertjCore:$latestAssertjVersion:
  core-module:
    path: ../
''';
}

class _VersionsParser with ProcessOutputConsumer {
  String? _currentArtifact;
  final Map<String, String> latestVersions = {};

  @override
  void call(String line) {
    if (line.startsWith('Versions of ') && line.endsWith(':')) {
      _currentArtifact = line.substring('Versions of '.length, line.length - 1);
    }
    final currentArtifact = _currentArtifact ?? '';
    if (currentArtifact.isEmpty) return;
    if (line.startsWith('  * Latest: ')) {
      final latestVersion = line.substring('  * Latest: '.length).trim();
      latestVersions[currentArtifact] = latestVersion;
      _currentArtifact = null;
    }
  }

  @override
  set pid(int pid) {
    // ignore
  }
}
