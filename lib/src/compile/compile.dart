import '../config.dart';
import '../file_tree.dart';
import '../jb_files.dart';
import '../jvm_executor.dart';
import 'groovy.dart';
import 'jbuild_compile.dart';

Future<JavaCommand> compileCommand(
    JbFiles jbFiles,
    JbConfiguration config,
    String workingDir,
    bool publication,
    TransitiveChanges? changes,
    List<String> args) {
  if (hasGroovyDependency(config)) {
    return groovyCommand(config, workingDir, args);
  }
  return jbuildCompileCommand(
      jbFiles, config, workingDir, publication, changes, args);
}
