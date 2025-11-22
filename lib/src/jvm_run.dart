import 'dart:io';

import 'package:actors/actors.dart';
import 'package:dartle/dartle.dart';

import 'compile/compile.dart';
import 'compute_compilation_path.dart' as cp;
import 'compute_compilation_path.dart';
import 'config.dart';
import 'exec.dart';
import 'jb_actors.dart';
import 'jvm_executor.dart';
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
  final compilationPath = await getCompilationPath(
    actors.compPath,
    compPathFiles,
    configContainer.artifactId,
    config.compileLibsDir,
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
  );

  // add the jar itself to the module-path
  if (isModule) {
    if (!isJar) {
      throw DartleException(
        message:
            'Cannot run Java module unless module output is a jar. '
            'Use output-jar instead of output-dir!',
      );
    }

    _includeInModulePath(jvmArgs, output);

    // we need to specify which module to run...
    jvmArgs.addAll(['-m', await getJavaModuleName(actors.jvmExecutor, output)]);
  } else if (isJar) {
    jvmArgs.addAll(['-jar', output]);
  } else {
    jvmArgs.addAll(['-cp', output]);
  }

  final exitCode = await execJava(runTaskName, [
    ...config.runJavaArgs,
    ...jvmArgs,
    if (!isJar) mainClass,
    ...classArgs,
  ], env: config.runJavaEnv);

  if (exitCode != 0) {
    throw DartleException(message: 'java command failed', exitCode: exitCode);
  }
}

void _includeInModulePath(List<String> jvmArgs, String jar) {
  final modulePathOptionIndex = jvmArgs.indexOf('-p');
  if (modulePathOptionIndex < 0) {
    jvmArgs.addAll(['-p', jar]);
    return;
  }
  final pathValue = jvmArgs[modulePathOptionIndex + 1];
  jvmArgs[modulePathOptionIndex + 1] = "$pathValue$classpathSeparator$jar";
}

Future<String> getJavaModuleName(
  Sendable<JavaCommand, Object?> jvmExecutor,
  String output,
) async {
  logger.fine('Will find Java module name before running it');
  final consumer = Actor.create(() => _ModuleCommandConsumer());
  await jvmExecutor.send(
    RunJBuild(runTaskName, ['module', output], await consumer.toSendable()),
  );
  final result = await consumer.send(_ModuleCommandConsumer.getNameMessage);
  if (result == null) {
    throw StateError('JBuild did not show module name for $output');
  }
  logger.fine(() => 'Java module name is: $result');
  return result;
}

class _ModuleCommandConsumer with Handler<String, String?> {
  static const _namePrefix = '  Name: ';
  static const getNameMessage = '____GET_NAME___';
  String? moduleName;
  bool isJavaModule = false;

  @override
  Future<String?> handle(String message) async {
    if (message == getNameMessage) return moduleName;
    if (moduleName != null) return null;
    if (!isJavaModule) {
      _checkIfJavaModule(message);
    } else if (message.startsWith(_namePrefix)) {
      moduleName = message.substring(_namePrefix.length);
    }
    return null;
  }

  void _checkIfJavaModule(String message) {
    if (message.startsWith('File ') &&
        message.endsWith(' contains a Java module:')) {
      isJavaModule = true;
    }
  }
}
