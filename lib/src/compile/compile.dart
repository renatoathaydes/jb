import 'dart:io';

import 'package:path/path.dart' as p;

import '../compilation_path.g.dart';
import '../config.dart';
import '../file_tree.dart';
import '../jb_files.dart';
import '../jvm_executor.dart';
import '../utils.dart';
import 'groovy.dart';
import 'jbuild_compile.dart';

Future<JavaCommand> compileCommand(
  JbFiles jbFiles,
  JbConfiguration config,
  CompilationPath compPath,
  bool isGroovyEnabled,
  String workingDir,
  bool publication,
  TransitiveChanges? changes,
  List<String> args,
) async {
  List<String> allArgs;
  if (isGroovyEnabled) {
    logger.fine(
      'Project has Groovy or Spock dependencies. Using Groovy compiler.',
    );
    final groovyJar = await findGroovyJar(config);
    allArgs = ['-g', groovyJar, ...args];
  } else {
    logger.finer('No Groovy dependencies found. Using javac compiler.');
    allArgs = [...args];
  }

  // to support local dependencies that do not produce a jar,
  // we always add the libs dir itself to the classpath
  allArgs.addAll(['-cp', config.compileLibsDir]);

  if (compPath.jars.isNotEmpty) {
    allArgs.addAll([
      '-cp',
      compPath.jars.map((j) => j.path).join(classpathSeparator),
    ]);
  }

  if (compPath.modules.isNotEmpty) {
    final isModule = await config.isModule;
    allArgs.addAll([
      isModule ? '-mp' : '-cp',
      compPath.modules.map((m) => m.path).join(classpathSeparator),
    ]);
  }

  return jbuildCompileCommand(
    jbFiles,
    config,
    workingDir,
    publication,
    changes,
    allArgs,
    isGroovyEnabled,
  );
}

extension on JbConfiguration {
  Future<bool> get isModule async {
    for (var dir in sourceDirs) {
      if (await File(p.join(dir, 'module-info.java')).exists()) {
        return true;
      }
    }
    return false;
  }
}
