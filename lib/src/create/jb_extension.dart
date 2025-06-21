import 'dart:io';

import '../help.dart';
import '../paths.dart';
import 'helpers.dart';

String _jbuildYaml(String groupId, String artifactId, jbuildVersion) =>
    '''
group: $groupId
module: $artifactId
version: '0.0.0'

source-dirs: [ src ]
resource-dirs: [ resources ]

dependencies:
  com.athaydes.jbuild:jbuild-api:$jbuildVersion:
    scope: compile-only
''';

String _mainJava(String package) =>
    '''
package $package;

import java.io.IOException;

import jbuild.api.JbTask;
import jbuild.api.JbTaskInfo;

@JbTaskInfo(name = "sample-task",
            description = "Prints a message to show this extension works.")
public final class ExampleTask implements JbTask {
    @Override
    public void run(String... args) throws IOException {
        System.out.println("Extension task running: " + getClass().getName());
    }
}
''';

List<FileCreator> getJbExtensionFileCreators(
  File jbuildFile, {
  required String groupId,
  required String artifactId,
  required String package,
  required bool createTestModule,
}) {
  return [
    FileCreator(
      jbuildFile,
      () async => jbuildFile.writeAsString(
        _jbuildYaml(
          groupId,
          artifactId,
          await getJBuildVersion(File(jbuildJarPath())),
        ),
      ),
    ),
    createJavaFile(package, 'ExampleTask', 'src', _mainJava(package)),
  ];
}
