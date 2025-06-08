import 'dart:io';

import 'package:conveniently/conveniently.dart';
import 'package:dartle/dartle_cache.dart';
import 'package:path/path.dart';

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
    List<String> args,
    bool isGroovyEnabled) async {
  final commandArgs = [
    ...await config.compileArgs(
        jbFiles.processorLibsDir, changes, isGroovyEnabled),
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
      TransitiveChanges? changes, bool isGroovyEnabled) async {
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
    if (changes == null ||
        !_addIncrementalCompileArgs(result, changes, isGroovyEnabled)) {
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
      List<String> args, TransitiveChanges changes, bool isGroovyEnabled) {
    final sourceFilter = _createSourceFilter(isGroovyEnabled);
    var incremental = false;
    for (final change in changes.fileChanges) {
      if (change.entity is! File) continue;
      incremental = true;
      final path = change.entity.path;
      if (change.kind == ChangeKind.deleted) {
        if (sourceFilter(path)) {
          final srcDir =
              sourceDirs.firstWhere((d) => isWithin(d, path), orElse: () => '');
          if (srcDir.isEmpty) {
            failBuild(
                reason:
                    'Cannot find file in any of the source directories $sourceDirs: $path');
          }
          final classFiles = changes.fileTree
              .classFilesOf(relative(path, from: srcDir))
              .toList(growable: false);
          if (classFiles.isEmpty) {
            failBuild(
                reason:
                    'Cannot find any class file for deleted source file: ${relative(path, from: srcDir)}\n'
                    'File tree: ${changes.fileTree}');
          }
          for (final classFile in classFiles) {
            args.add('--deleted');
            args.add(classFile);
          }
          continue;
        }
        args.add('--deleted');
        args.add(path);
      } else {
        args.add('--added');
        args.add(path);
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

bool Function(String path) _createSourceFilter(isGroovyEnabled) {
  if (isGroovyEnabled) {
    return (path) => path.endsWith('.java');
  }
  return (path) => path.endsWith('.java') || path.endsWith('.groovy');
}
