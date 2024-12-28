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
    List<String> args) async {
  List<String> allArgs;
  if (hasGroovyDependency(config)) {
    logger.fine('Project has Groovy dependencies. Using Groovy compiler.');
    final groovyJar = await findGroovyJar(config);
    allArgs = ['-g', groovyJar, ...args];
  } else {
    logger.finer('No Groovy dependencies found. Using javac compiler.');
    allArgs = args;
  }
  return jbuildCompileCommand(
      jbFiles, config, workingDir, publication, changes, allArgs);
}
