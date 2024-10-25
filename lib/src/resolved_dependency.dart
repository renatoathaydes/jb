import 'dart:io';

import 'package:dartle/dartle.dart';
import 'package:isolate_current_directory/isolate_current_directory.dart';
import 'package:path/path.dart' as p;

import 'config.dart';
import 'config_source.dart';
import 'jb_files.dart';
import 'options.dart';
import 'path_dependency.dart';
import 'runner.dart';
import 'tasks.dart';

final class ResolvedProjectDependency {
  final ProjectDependency projectDependency;
  final String projectDir;
  final JbConfigContainer _config;

  DependencySpec get spec => projectDependency.spec;

  String get path => projectDependency.path;

  String? get group => _config.config.group;

  String? get module => _config.config.module;

  String? get version => _config.config.version;

  DependencyScope get scope => projectDependency.spec.scope;

  CompileOutput get output => _config.output.when(
      dir: (d) => CompileOutput.dir(_relativize(d)),
      jar: (j) => CompileOutput.jar(_relativize(j)));

  String get runtimeLibsDir => _relativize(_config.config.runtimeLibsDir);

  String get compileLibsDir => _relativize(_config.config.compileLibsDir);

  const ResolvedProjectDependency(
      this.projectDependency, this.projectDir, this._config);

  String _relativize(String path) {
    return p.join(projectDir, path);
  }

  Future<void> initialize(Options options, JbFiles files) async {
    final runner = JbRunner(files, _config.config);
    logger.info(() => "Initializing project dependency at '$projectDir'");
    await withCurrentDirectory(
        projectDir,
        () async => await runner.run(
            copyDartleOptions(
                options, const [compileTaskName, installRuntimeDepsTaskName]),
            Stopwatch(),
            isRoot: false));

    logger.fine(() => "Project dependency '$projectDir' initialized");
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
  /// Resolve a [ProjectDependency]'s [JbConfiguration].
  Future<ResolvedProjectDependency> resolve() async {
    final dir = Directory(path);
    FileConfigSource configSource;
    String projectDir;
    if (await dir.exists()) {
      configSource = defaultJbConfigSource;
      projectDir = p.canonicalize(dir.absolute.path);
    } else {
      // maybe it's a dependency on a particular jb file
      configSource = FileConfigSource([path]);
      projectDir = p.canonicalize(p.dirname(path));
    }
    JbConfigContainer config;
    try {
      // the config loader defaults some stuff to the current directory,
      // so we must load it from the right dir.
      config = await withCurrentDirectory(
          projectDir, () async => JbConfigContainer(await configSource.load()));
    } catch (e) {
      throw DartleException(
          message: 'Error loading project dependency at path: "$path": $e');
    }
    logger.fine(() => 'Parsed jb project dependency configuration: $config');
    return ResolvedProjectDependency(this, projectDir, config);
  }
}
