import 'dart:io';

import 'package:conveniently/conveniently.dart';
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
///
/// If `forJava` is `true`, options for the java command are used, otherwise
///  options for the jbuild command are used.
Future<bool> addCompilationPathsTo(
  List<String> args,
  JbConfiguration config,
  CompilationPath compPath, {
  required bool forJava,
  String? output,
}) async {
  // to support local dependencies that do not produce a jar,
  // we always add the libs dir itself to the classpath
  final cp = [config.compileLibsDir];

  final mp = <String>[];

  if (compPath.jars.isNotEmpty) {
    cp.addAll(compPath.jars.map((j) => j.path));
  }

  final isModule = await config.isModule;

  (isModule ? mp : cp).vmap((paths) {
    paths.addAll(compPath.modules.map((m) => m.path));
    if (output != null) paths.add(output);
  });

  args.addAll(['-cp', cp.join(classpathSeparator)]);

  if (mp.isNotEmpty) {
    args.addAll([if (forJava) '-p' else '-mp', mp.join(classpathSeparator)]);
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
