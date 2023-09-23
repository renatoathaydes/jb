import 'dart:io';

import 'helpers.dart';

// TODO update the jb-api version to be that of the JBuild jar used.
String _jbuildYaml(String groupId, String artifactId) => '''
group: $groupId
module: $artifactId
version: '0.0.0'

source-dirs: [ src ]
resource-dirs: [ resources ]

dependencies:
  - com.athaydes.jb:jb-api:0.1.0:
    scope: compile-only
''';

String _mainJava(String package) => '''
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

List<FileCreator> getJbExtensionFileCreators(File jbuildFile,
    {required String groupId,
    required String artifactId,
    required String package,
    required bool createTestModule}) {
  return [
    FileCreator(jbuildFile,
        () => jbuildFile.writeAsString(_jbuildYaml(groupId, artifactId))),
    createJavaFile(package, 'ExampleTask', 'src', _mainJava(package)),
  ];
}
