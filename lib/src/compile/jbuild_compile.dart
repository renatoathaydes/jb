import 'dart:io';

import 'package:conveniently/conveniently.dart';
import 'package:dartle/dartle_cache.dart';

import '../config.dart';
import '../file_tree.dart';
import '../jb_files.dart';
import '../jvm_executor.dart';
import '../tasks.dart';
import '../utils.dart';

Future<JavaCommand> jbuildCompileCommand(
    JbFiles jbFiles,
    JbConfiguration config,
    String workingDir,
    bool publication,
    TransitiveChanges? changes,
    List<String> args) async {
  final commandArgs = [
    ...await config.compileArgs(jbFiles.processorLibsDir, changes),
    ...args,
  ];

  return RunJBuild(compileTaskName, [
    ...config.preArgs(workingDir),
    'compile',
    if (publication) ...const ['-sj', '-dj'],
    // the Java compiler runtime args are sent when starting the JVM
    ...commandArgs.notJavaRuntimeArgs(),
  ]);
}

extension _JbConfig on JbConfiguration {
  /// Get the compile task arguments from this configuration.
  Future<List<String>> compileArgs(String processorLibsDir,
      [TransitiveChanges? changes]) async {
    final result = <String>[];
    if (compileLibsDir.isNotEmpty) {
      result.addAll(['-cp', compileLibsDir.asDirPath()]);
    }
    outputDir?.vmap((d) => result.addAll(['-d', d.asDirPath()]));
    outputJar?.vmap((jar) => result.addAll(['-j', jar]));
    for (final r in resourceDirs.toSet()) {
      result.addAll(['-r', r.asDirPath()]);
    }
    final main = mainClass;
    if (main != null && main.isNotEmpty) {
      result.addAll(['-m', main]);
    }
    final manifestFile = manifest;
    if (manifestFile != null && manifestFile.isNotEmpty) {
      result.addAll(['-mf', manifestFile]);
    }
    if (dependencies.keys.any((d) => d.startsWith(jbApi))) {
      result.add('--jb-extension');
    }
    if (changes == null || !_addIncrementalCompileArgs(result, changes)) {
      result.addAll(sourceDirs);
    }
    if (javacArgs.isNotEmpty || processorDependencies.isNotEmpty) {
      result.add('--');
      result.addAll(javacArgs);
      if (processorDependencies.isNotEmpty) {
        result.add('-processorpath');
        (await Directory(processorLibsDir).toClasspath())?.vmap(result.add);
      }
    }
    return result;
  }

  /// Add the incremental compilation args if applicable.
  ///
  /// Return true if added, false otherwise.
  bool _addIncrementalCompileArgs(
      List<String> args, TransitiveChanges changes) {
    var incremental = false;
    for (final change in changes.fileChanges) {
      if (change.entity is! File) continue;
      incremental = true;
      if (change.kind == ChangeKind.deleted) {
        final path = change.entity.path;
        if (path.endsWith('.java')) {
          for (final classFile in changes.fileTree
              .classFilesOf(sourceDirs, change.entity.path)) {
            args.add('--deleted');
            args.add(classFile);
          }
        } else {
          args.add('--deleted');
          args.add(change.entity.path);
        }
      } else {
        args.add('--added');
        args.add(change.entity.path);
      }
    }

    // previous compilation output must be part of the classpath
    (outputDir ?? outputJar ?? '').ifNonBlank((cp) {
      args.add('-cp');
      args.add(cp);
    });

    return incremental;
  }
}
