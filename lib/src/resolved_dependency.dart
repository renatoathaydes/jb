import 'dart:io';

import 'package:dartle/dartle.dart';
import 'package:isolate_current_directory/isolate_current_directory.dart';
import 'package:path/path.dart' as p;

import 'config.dart';
import 'jb_files.dart';
import 'path_dependency.dart';
import 'runner.dart';
import 'tasks.dart';

final class ResolvedProjectDependency {
  final ProjectDependency projectDependency;
  final String configFile;
  final JBuildConfiguration _config;

  DependencySpec get spec => projectDependency.spec;

  String get path => projectDependency.path;

  CompileOutput get output => _config.output.when(
      dir: (d) => CompileOutput.dir(_relativize(d)),
      jar: (j) => CompileOutput.jar(_relativize(j)));

  String get runtimeLibsDir => _relativize(_config.runtimeLibsDir);

  String get compileLibsDir => _relativize(_config.compileLibsDir);

  const ResolvedProjectDependency(
      this.projectDependency, this.configFile, this._config);

  String _relativize(String path) {
    return p.join(p.dirname(configFile), path);
  }
}

final class ResolvedLocalDependencies {
  final List<JarDependency> jars;
  final List<ResolvedProjectDependency> projectDependencies;

  const ResolvedLocalDependencies(this.jars, this.projectDependencies);

  bool get isEmpty => jars.isEmpty && projectDependencies.isEmpty;

  LocalDependencies get unresolved => LocalDependencies(
      jars,
      projectDependencies
          .map((e) => e.projectDependency)
          .toList(growable: false));
}

extension Resolver on ProjectDependency {
  /// Resolve a [ProjectDependency]'s [JBuildConfiguration].
  Future<ResolvedProjectDependency> resolve() async {
    final dir = Directory(path);
    File configFile;
    if (await dir.exists()) {
      configFile = File(p.join(path, jbFile));
    } else {
      // maybe it's a dependency on a particular jb file
      configFile = File(path);
    }
    if (!await configFile.exists()) {
      throw DartleException(
          message: 'no dependency project found at: "${configFile.path}"');
    }
    JBuildConfiguration config;
    try {
      // the config loader defaults some stuff to the current directory,
      // so we must load it from the right dir.
      config = await withCurrentDirectory(configFile.absolute.parent.path,
          () async => await loadConfig(configFile));
    } catch (e, st) {
      logger.severe('Could not load project dependency', e, st);
      throw DartleException(
          message: 'Error loading project dependency at path: "$path"');
    }
    logger.fine(() => 'Parsed jb project dependency configuration: $config');
    return ResolvedProjectDependency(this, configFile.absolute.path, config);
  }
}

Future<void> initializeProjectDependency(
    ResolvedProjectDependency dep, Options options, JbFiles files) async {
  final configFile = dep.configFile;
  final config = dep._config;
  final runner = JbRunner(files, config);
  final dir = p.dirname(configFile);
  logger.info(() => "Initializing project dependency at '$dir'");
  final workingDir = Directory.current;
  await withCurrentDirectory(
      dir,
      () async => await runner.run(
          _createOptionsForProjectDep(
              options, const [compileTaskName, installRuntimeDepsTaskName]),
          Stopwatch()));
  // Dartle changes the current dir, so we must restore it here
  Directory.current = workingDir;
}

Options _createOptionsForProjectDep(
    Options options, List<String> tasksInvocation) {
  return Options(
      logLevel: options.logLevel,
      colorfulLog: options.colorfulLog,
      forceTasks: options.forceTasks,
      parallelizeTasks: options.parallelizeTasks,
      resetCache: options.resetCache,
      logBuildTime: false,
      runPubGet: options.runPubGet,
      disableCache: options.disableCache,
      tasksInvocation: tasksInvocation);
}
