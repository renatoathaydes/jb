import 'dart:io';

import 'package:conveniently/conveniently.dart';
import 'package:dartle/dartle_cache.dart' show DartleCache;
import 'package:path/path.dart' as p;

import '../compilation_path.g.dart';
import '../config.dart';
import '../file_tree.dart';
import '../jb_files.dart';
import '../jvm_executor.dart';
import '../utils.dart';
import 'groovy.dart';
import 'jbuild_compile.dart';

Future<RunJBuild> compileCommand(
  JbFiles jbFiles,
  JbConfiguration config,
  CompilationPath compPath,
  bool isGroovyEnabled,
  String workingDir,
  bool publication,
  TransitiveChanges? changes,
  List<String> args,
  DartleCache cache,
) async {
  final allArgs = <String>[];
  if (isGroovyEnabled) {
    logger.fine(
      'Project has Groovy or Spock dependencies. Using Groovy compiler.',
    );
    final groovyJar = await findGroovyJar(config);
    allArgs.addAll(['-g', groovyJar]);

    if (publication) {
      allArgs.addAll([
        '--groovydoc-tool-class-path',
        await Directory(
          p.join(cache.rootDir, groovydocLibsDir),
        ).toClasspath().then((cp) {
          if (cp == null) {
            throw StateError(
              'The groovydoc libs directory is empty: $groovydocLibsDir',
            );
          }
          return cp;
        }),
      ]);
    }
  } else {
    logger.finer('No Groovy dependencies found. Using javac compiler.');
  }

  final isModule = await _isModuleProject(config);

  // For incremental compilation of module projects, we must handle two cases:
  // 1. module-info.java changed: cannot do incremental, fall back to full
  //    module compilation so javac rebuilds the module correctly.
  // 2. module-info.java NOT changed: use classpath-only mode (no module-path)
  //    so javac treats the code as non-modular and can see all classes from
  //    the previous compilation output on the classpath. JBuild will replace
  //    the recompiled class files in the existing module jar.
  TransitiveChanges? effectiveChanges = changes;
  bool useModulePath = isModule;

  if (isModule && changes != null) {
    if (_moduleInfoChanged(changes)) {
      logger.fine(
        'module-info.java changed, falling back to full module compilation.',
      );
      effectiveChanges = null;
    } else {
      logger.fine('Incremental module compilation: using classpath mode.');
      useModulePath = false;
    }
  }

  if (config.processorDependencies.isNotEmpty &&
      !config.javacArgs.contains('-processorpath')) {
    allArgs.add('--processor-path');
    allArgs.add(p.join(jbFiles.processorLibsDir, '*'));
  }

  await addCompilationPathsTo(
    allArgs,
    config,
    compPath,
    forJava: false,
    useModulePath: useModulePath,
  );
  allArgs.addAll(args);

  return jbuildCompileCommand(
    config,
    workingDir,
    publication,
    effectiveChanges,
    allArgs,
    isGroovyEnabled: isGroovyEnabled,
  );
}

/// Adds classpath and modulepath options to the args.
///
/// Returns whether this config represents a module.
///
/// If `forJava` is `true`, options for the java command are used, otherwise
///  options for the jbuild command are used.
///
/// If `useModulePath` is provided, it overrides the automatic module detection
/// for deciding whether to use module-path or classpath.
Future<bool> addCompilationPathsTo(
  List<String> args,
  JbConfiguration config,
  CompilationPath compPath, {
  required bool forJava,
  String? output,
  bool? useModulePath,
}) async {
  // to support local dependencies that do not produce a jar,
  // we always add the libs dir itself to the classpath
  final cp = [config.compileLibsDir.asDirPath()];

  final mp = <String>[];

  if (compPath.jars.isNotEmpty) {
    cp.addAll(compPath.jars.map((j) => j.path));
  }

  final isModule = useModulePath ?? await _isModuleProject(config);

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

/// Whether this project uses the Java module system (has module-info.java).
Future<bool> _isModuleProject(JbConfiguration config) async {
  final dirs = config.sourceDirs.isEmpty
      ? ['src', p.join('src', 'main', 'java')]
      : config.sourceDirs;
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

bool _moduleInfoChanged(TransitiveChanges changes) {
  return changes.fileChanges.any(
    (c) => c.entity.path.endsWith('module-info.java'),
  );
}
