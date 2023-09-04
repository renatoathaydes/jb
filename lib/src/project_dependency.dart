import 'dart:io';

import 'package:dartle/dartle.dart';
import 'package:isolate_current_directory/isolate_current_directory.dart';
import 'package:path/path.dart' as p;

import 'config.dart';
import 'path_dependency.dart';
import 'runner.dart';
import 'utils.dart';

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

Task createProjectDependencyTask(ResolvedProjectDependency dep, Options options,
    {required String mainTaskName}) {
  final subTaskName = '${dep.path}:$mainTaskName';
  return Task(
      _ProjectDependencyCompileTask(
          dep.configFile, dep._config, options, mainTaskName),
      name: subTaskName,
      argsValidator: const AcceptAnyArgs());
}

final class _ProjectDependencyCompileTask {
  final String configFile;
  final Options options;
  final String taskName;
  final JBuildConfiguration config;

  _ProjectDependencyCompileTask(
      this.configFile, this.config, this.options, this.taskName);

  Future<void> call(List<String> args) async {
    final jbuildJar = await createIfNeededAndGetJBuildJarFile();
    final runner = JbRunner(JBuildFiles(jbuildJar, configFile), config);
    final dir = p.dirname(configFile);
    final pwd = Directory.current.path;
    logger.info(
        () => "Running project dependency task '$taskName' at directory '$dir',"
            " current dir is ${Directory.current.path}");
    await withCurrentDirectory(
        dir,
        () async => await runner.run(
            _createOptionsForProjectDep(options, taskName), Stopwatch()));
    // FIXME this shouldn't be needed!!
    Directory.current = pwd;
    logger.info(() =>
        'Sub-project task run, current dir is: ${Directory.current.path}');
  }

  Options _createOptionsForProjectDep(Options options, String taskName) {
    return Options(
        logLevel: options.logLevel,
        colorfulLog: options.colorfulLog,
        forceTasks: options.forceTasks,
        parallelizeTasks: options.parallelizeTasks,
        resetCache: options.resetCache,
        logBuildTime: false,
        runPubGet: options.runPubGet,
        disableCache: options.disableCache,
        tasksInvocation: [taskName]);
  }
}
