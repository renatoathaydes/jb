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
  final allArgs = <String>[];
  if (isGroovyEnabled) {
    logger.fine(
      'Project has Groovy or Spock dependencies. Using Groovy compiler.',
    );
    final groovyJar = await findGroovyJar(config);
    allArgs.addAll(['-g', groovyJar]);
  } else {
    logger.finer('No Groovy dependencies found. Using javac compiler.');
  }

  await addCompilationPathsTo(allArgs, config, compPath, forJava: false);
  allArgs.addAll(args);

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

/// Adds classpath and modulepath options to the args.
///
/// Returns whether this config represents a module.
Future<bool> addCompilationPathsTo(
  List<String> args,
  JbConfiguration config,
  CompilationPath compPath, {
  required bool forJava,
}) async {
  // to support local dependencies that do not produce a jar,
  // we always add the libs dir itself to the classpath
  // TODO if !forJava, JBuild expands that jars in the dir,
  // which means it includes modules in it
  args.addAll(['-cp', config.compileLibsDir]);

  if (compPath.jars.isNotEmpty) {
    args.addAll([
      '-cp',
      compPath.jars.map((j) => j.path).join(classpathSeparator),
    ]);
  }

  final isModule = await config.isModule;
  if (compPath.modules.isNotEmpty) {
    args.addAll([
      isModule ? (forJava ? '-p' : '-mp') : '-cp',
      compPath.modules.map((m) => m.path).join(classpathSeparator),
    ]);
  }

  return isModule;
}

extension on JbConfiguration {
  Future<bool> get isModule async {
    final dirs = sourceDirs.isEmpty
        ? ['src', p.join('src', 'main', 'java')]
        : sourceDirs;
    for (var dir in dirs) {
      logger.finer(
        () =>
            'Checking if module file exists in: ${p.join(Directory.current.path, dir)}',
      );
      if (await File(p.join(dir, 'module-info.java')).exists()) {
        return true;
      }
    }
    return false;
  }
}
