import 'dart:io';

import 'package:dartle/dartle.dart';
import 'package:path/path.dart' as p;

import 'compilation_path.g.dart';
import 'compile/compile.dart';
import 'compute_compilation_path.dart' as cp;
import 'config.dart';
import 'exec.dart';
import 'jb_actors.dart';
import 'tasks.dart' show runTaskName;
import 'utils.dart';

Future<void> javaRun(
  File jbuildJar,
  JbConfigContainer configContainer,
  List<String> taskArgs,
  JbActors actors,
  cp.CompilationPathFiles compPathFiles,
) async {
  final classArgs = [...taskArgs];
  final config = configContainer.config;
  var mainClass = config.mainClass ?? '';
  if (mainClass.isEmpty) {
    const mainClassArg = '--main-class=';
    final mainClassArgIndex = classArgs.indexWhere(
      (arg) => arg.startsWith(mainClassArg),
    );
    if (mainClassArgIndex >= 0) {
      mainClass = classArgs
          .removeAt(mainClassArgIndex)
          .substring(mainClassArg.length);
    }
  }
  if (mainClass.isEmpty) {
    throw DartleException(
      message:
          'cannot run Java application as '
          'no main-class has been configured or provided.\n'
          'To configure one, add "main-class: your.Main" to your jb config file.',
    );
  }
  final compilationPath = await cp.getCompilationPath(
    actors.compPath,
    configContainer.artifactId,
    config.runtimeLibsDir,
    compPathFiles.runtimePath,
  );

  final (output, isJar) = configContainer.output.when(
    dir: (d) => (d.asDirPath(), false),
    jar: (j) => (j, true),
  );

  final jvmArgs = <String>[];

  final isModule = await addCompilationPathsTo(
    jvmArgs,
    config,
    compilationPath,
    forJava: true,
    output: output,
  );

  String? moduleName;

  // add the module to the module-path
  if (isModule) {
    if (!isJar) {
      throw DartleException(
        message:
            'Cannot run Java module unless module output is a jar. '
            'Use output-jar instead of output-dir!',
      );
    }
    moduleName = await getJavaModuleName(compilationPath, output);

    // we need to specify which module to run...
    jvmArgs.addAll(['-m', moduleName]);
  }

  final exitCode = await execJava(runTaskName, [
    ...config.runJavaArgs,
    ...jvmArgs,
    (moduleName == null) ? mainClass : "$moduleName/$mainClass",
    ...classArgs,
  ], env: config.runJavaEnv);

  if (exitCode != 0) {
    throw DartleException(message: 'java command failed', exitCode: exitCode);
  }
}

Future<String> getJavaModuleName(
  CompilationPath compPath,
  String output,
) async {
  logger.fine('Will find Java module name before running it');
  final moduleFileName = p.basename(output);
  final module = compPath.modules
      .where((m) => p.basename(m.path) == moduleFileName)
      .firstOrNull;
  if (module == null) {
    throw DartleException(
      message:
          'Cannot find Java module $output '
          'in known modules: ${compPath.modules.map((m) => m.path)}',
    );
  }
  logger.finer(() => 'Java module name is: ${module.name}');
  return module.name;
}
