import 'dart:io';

import 'package:actors/actors.dart';
import 'package:dartle/dartle.dart';
import 'package:isolate_current_directory/isolate_current_directory.dart';
import 'package:path/path.dart' as p;

import 'config.dart';
import 'config_source.dart';
import 'dependencies/deps_cache.dart';
import 'jb_files.dart';
import 'jvm_executor.dart';
import 'options.dart';
import 'path_dependency.dart';
import 'runner.dart';
import 'tasks.dart';

final class ResolvedProjectDependency {
  final ProjectDependency projectDependency;
  final String projectDir;
  final JbConfigContainer _config;

  DependencySpec get spec => projectDependency.spec;

  String get artifact => "$group:$module:$version";

  Map<String, DependencySpec?> get dependencies => _config.config.dependencies;

  Map<String, DependencySpec?> get processorDependencies =>
      _config.config.processorDependencies;

  String get path => projectDependency.path;

  String? get group => _config.config.group;

  String? get module => _config.config.module;

  String? get version => _config.config.version;

  List<String> get exclusions => _config.config.dependencyExclusionPatterns;

  List<String> get procExclusions =>
      _config.config.processorDependencyExclusionPatterns;

  DependencyScope get scope => projectDependency.spec.scope;

  CompileOutput get output => _config.output.when(
    dir: (d) => CompileOutput.dir(_relativize(d)),
    jar: (j) => CompileOutput.jar(_relativize(j)),
  );

  String get runtimeLibsDir => _relativize(_config.config.runtimeLibsDir);

  String get compileLibsDir => _relativize(_config.config.compileLibsDir);

  const ResolvedProjectDependency(
    this.projectDependency,
    this.projectDir,
    this._config,
  );

  String _relativize(String path) {
    return p.join(projectDir, path);
  }

  Future<void> initialize(
    Options options,
    JbFiles files,
    JBuildSender jvmExecutor,
    Sendable<DepsCacheMessage, ResolvedDependencies> depsCache,
  ) async {
    final runner = JbRunner(files, _config.config, jvmExecutor, depsCache);
    logger.info(() => "Initializing project dependency at '$projectDir'");
    await withCurrentDirectory(
      projectDir,
      () async => await runner.run(
        options.copy(
          tasksInvocation: const [compileTaskName, installRuntimeDepsTaskName],
        ),
        Stopwatch(),
        isRoot: false,
      ),
    );

    logger.fine(() => "Project dependency '$projectDir' initialized");
  }

  ResolvedDependency toResolvedDependency({required bool isDirect}) =>
      ResolvedDependency(
        artifact: artifact,
        spec: spec,
        sha1: '',
        isDirect: isDirect,
        dependencies: dependencies.keys.toList(growable: false),
      );
}

final class ResolvedLocalDependencies {
  static const empty = ResolvedLocalDependencies([], []);

  final List<JarDependency> jars;
  final List<ResolvedProjectDependency> projectDependencies;

  const ResolvedLocalDependencies(this.jars, this.projectDependencies);

  bool get isEmpty => jars.isEmpty && projectDependencies.isEmpty;

  bool get isNotEmpty => !isEmpty;
}

extension Resolver on ProjectDependency {
  /// Resolve a [ProjectDependency]'s [JbConfiguration].
  ///
  /// The `path` may be one of the following:
  ///   * directory containing a jb project.
  ///   * file expected to be the jb config file.
  Future<ResolvedProjectDependency> resolve() async {
    final dir = Directory(path);
    FileConfigSource configSource;
    String projectDir;
    if (await dir.exists()) {
      configSource = defaultJbConfigSource;
      projectDir = p.canonicalize(dir.absolute.path);
    } else {
      // maybe it's a dependency on a particular jb file
      if (const {jsonJbFile, yamlJbFile}.contains(p.basename(path))) {
        configSource = FileConfigSource([path]);
        projectDir = p.canonicalize(p.dirname(path));
      } else {
        throw DartleException(
          message:
              'Cannot load project dependency at path "$path": '
              'not a jb project directory or jb config file.',
        );
      }
    }
    JbConfigContainer config;
    try {
      // the config loader defaults some stuff to the current directory,
      // so we must load it from the right dir.
      config = await withCurrentDirectory(
        projectDir,
        () async => JbConfigContainer(await configSource.load()),
      );
    } catch (e) {
      throw DartleException(
        message: 'Error loading project dependency at path: "$path": $e',
      );
    }
    logger.fine(() => 'Parsed jb project dependency configuration: $config');
    return ResolvedProjectDependency(this, projectDir, config);
  }
}
