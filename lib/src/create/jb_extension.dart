import 'dart:io';

import 'helpers.dart';

String _jbuildYaml(String groupId, String artifactId) => '''
group: $groupId
module: $artifactId
version: '0.0.0'

source-dirs: [ src ]
resource-dirs: [ resources ]

dependencies:
  - com.athaydes.jb:jb-api:0.1.0
''';

String _mainJava(String package) => '''
package $package;

import java.util.Set;
import jb.api.JbTask;
import jb.api.TaskContext;

public final class ExampleTask implements JbTask {

    @Override
    public String getName() {
      return "example";
    }
    
    @Override
    public String getDescription() {
      return "Task description.";
    }
    
    @Override
    public String getPhase() {
      return "build";
    }
    
    @Override
    public Set<String> getInputs() {
      return Set.of("*.txt");
    }
    
    @Override
    public Set<String> getOutputs() {
      return Set.of("*.out");
    }
    
    @Override
    public void run(String[] args, TaskContext context) {
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
