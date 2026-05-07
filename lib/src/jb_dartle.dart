import 'package:collection/collection.dart';
import 'package:conveniently/conveniently.dart';
import 'package:dartle/dartle.dart';
import 'package:dartle/dartle_cache.dart';
import 'package:jb/jb.dart';
import 'package:jb/src/extension/cache_model.dart';

import 'compute_compilation_path.dart';
import 'jb_actors.dart';
import 'utils.dart';

/// jb Dartle build definition.
///
/// Users of this class must await on the [init] Future for this class to
/// be fully initialized before using it.
class JbDartle {
  final JbFiles _files;
  final JbConfigWithImports _cwi;
  final DartleCache _cache;
  final Options _options;
  final JbActors _actors;

  /// Whether this project is the root project being executed.
  final bool isRoot;

  late final Task compile,
      publicationCompile,
      checkJavaVersion,
      writeDeps,
      verifyDeps,
      installGroovydocs,
      installCompile,
      installRuntime,
      installProcessor,
      createCompilationPath,
      createRuntimePath,
      generateEclipse,
      generatePom,
      requirements,
      clean,
      run,
      jshell,
      downloadTestRunner,
      downloadChecksums,
      test,
      showConfig,
      deps,
      publish,
      updateJBuild;

  /// Get the tasks that are configured as part of a build.
  late final Set<Task> tasks;

  /// Wait for all sub-projects tasks to be initialized.
  late final Future<void> init;

  JbConfiguration get _config => _cwi.config;

  JbDartle._(
    this._files,
    this._cwi,
    this._cache,
    this._options,
    this._actors,
    this.isRoot,
  ) {
    final localDeps = Future.wait([
      _resolveLocalDependencies(_config.allDependencies, name: 'main'),
      _resolveLocalDependencies(
        _config.allProcessorDependencies,
        name: 'annotation processor',
      ),
    ]);
    init = localDeps.then((d) => _initialize(d[0], d[1]));
  }

  JbDartle.create(
    JbFiles files,
    JbConfigWithImports cwi,
    DartleCache cache,
    Options options,
    JbActors actors, {
    required bool isRoot,
  }) : this._(files, cwi, cache, options, actors, isRoot);

  /// Get the default tasks (`{ compile }`).
  Set<Task> get defaultTasks {
    return {compile};
  }

  Future<ResolvedLocalDependencies> _resolveLocalDependencies(
    Iterable<MapEntry<String, DependencySpec>> dependencies, {
    required String name,
  }) async {
    final pathDependencies = dependencies
        .map((e) => e.value.toPathDependency(e.key))
        .nonNulls;

    final projectDeps = <ProjectDependency>[];
    final jars = <JarDependency>[];

    for (final pathDep in pathDependencies) {
      pathDep.when(jar: jars.add, jbuildProject: projectDeps.add);
    }

    final subProjects = await projectDeps
        .toStream()
        .asyncMap((e) => e.resolve())
        .toList();

    logger.fine(
      () =>
          'Resolved $name configuration: '
          '${subProjects.length} project dependenc${subProjects.length == 1 ? 'y' : 'ies'}, '
          '${jars.length} local jar dependenc${jars.length == 1 ? 'y' : 'ies'}.',
    );

    return ResolvedLocalDependencies(jars, subProjects);
  }

  Future<void> _initialize(
    ResolvedLocalDependencies localDependencies,
    ResolvedLocalDependencies localProcessorDependencies,
  ) async {
    final stopwatch = Stopwatch()..start();
    final configContainer = JbConfigContainer(_cwi);

    final jvmExecutor = _actors.jvmExecutor;
    final javaExecutor = jvmExecutor.takingJavaCommands();
    final depsCache = _actors.depsCache;
    final compPath = _actors.compPath;

    final FileCollection jbFileInputs = _inputsFrom(_cwi);
    final artifact = createArtifact(_config);
    final compilationFiles = CompilationPathFiles(_cache);
    final projectTasks = <Task>{};

    checkJavaVersion = createCheckJavaVersionTask(_files, _actors);

    compile = createCompileTask(
      _files,
      configContainer,
      compilationFiles,
      _cache,
      _actors,
    );
    publicationCompile = createPublicationCompileTask(
      _files,
      configContainer,
      compilationFiles,
      _cache,
      _actors,
    );
    writeDeps = createWriteDependenciesTask(
      _files,
      _config,
      localDependencies,
      localProcessorDependencies,
      depsCache,
      _cache,
      jbFileInputs,
      javaExecutor,
    );
    downloadChecksums = createDownloadDependenciesChecksumsTask(
      _files,
      _config,
      javaExecutor,
      depsCache,
      _cache,
    );
    verifyDeps = createVerifyDependenciesTask(_files, depsCache, _cache);
    installCompile = createInstallCompileDepsTask(
      _files,
      _config,
      javaExecutor,
      depsCache,
      _cache,
      localDependencies,
    );
    installGroovydocs = createInstallGroovydocsTask(
      _files,
      configContainer,
      javaExecutor,
      depsCache,
      _cache,
      localDependencies,
    );
    installRuntime = createInstallRuntimeDepsTask(
      _files,
      configContainer,
      javaExecutor,
      depsCache,
      _cache,
      localDependencies,
    );
    installProcessor = createInstallProcessorDepsTask(
      _files,
      _config,
      javaExecutor,
      depsCache,
      _cache,
      localProcessorDependencies,
    );
    createCompilationPath = createJavaCompilationPathTask(
      _files,
      configContainer,
      javaExecutor,
      compPath,
      compilationFiles,
    );
    createRuntimePath = createJavaRuntimePathTask(
      _files,
      configContainer,
      javaExecutor,
      compPath,
      compilationFiles,
    );
    run = createRunTask(
      _files,
      configContainer,
      _cache,
      _actors,
      compilationFiles,
    );
    jshell = createJshellTask(_files, configContainer, _cache);
    downloadTestRunner = createDownloadTestRunnerTask(
      _files,
      configContainer,
      javaExecutor,
      depsCache,
      _cache,
      jbFileInputs,
    );
    test = createTestTask(
      _files.jbuildJar,
      configContainer,
      _cache,
      !_options.colorfulLog,
    );
    deps = createDepsTask(
      _files,
      _config,
      depsCache,
      _cache,
      localDependencies,
      localProcessorDependencies,
    );
    showConfig = createShowConfigTask(_config, !_options.colorfulLog);
    requirements = createRequirementsTask(_files.jbuildJar, configContainer);
    generateEclipse = createEclipseTask(_config);
    generatePom = createGeneratePomTask(
      artifact,
      localDependencies,
      _files.dependenciesFile,
      depsCache,
    );
    publish = createPublishTask(
      artifact,
      _files.dependenciesFile,
      depsCache,
      configContainer.output.when(dir: (_) => null, jar: (j) => j),
      localDependencies,
    );
    updateJBuild = createUpdateJBuildTask(javaExecutor);

    final extensionProject = await loadExtensionProject(
      _files,
      _actors,
      _options,
      _cwi,
      _cache,
    );

    final extensionTasks = extensionProject.vmap((extProject) {
      verifyAllExtrasMatchExtensionTasks(
        _config,
        extProject?.model.extensionTasks ?? const [],
      );
      return extProject?.tasks;
    });

    projectTasks.addAll({
      checkJavaVersion,
      compile,
      publicationCompile,
      writeDeps,
      verifyDeps,
      installGroovydocs,
      installCompile,
      installRuntime,
      installProcessor,
      createCompilationPath,
      createRuntimePath,
      run,
      jshell,
      downloadChecksums,
      downloadTestRunner,
      test,
      deps,
      showConfig,
      requirements,
      generateEclipse,
      generatePom,
      publish,
      updateJBuild,
      if (extensionTasks != null) ...extensionTasks,
    });

    clean = createCleanTask(
      tasks: projectTasks,
      name: cleanTaskName,
      description: 'deletes the outputs of all other tasks.',
    );
    projectTasks.add(clean);

    extensionProject?.vmap((p) => _wireupTasks(p, projectTasks));

    if (localDependencies.projectDependencies.isNotEmpty) {
      await _initializeProjectDeps(localDependencies.projectDependencies);
      if (isRoot) {
        logger.info('All project dependencies have been initialized');
      }
    }

    tasks = Set.unmodifiable(projectTasks);

    logger.log(
      profile,
      () => 'Project initialization completed in ${elapsedTime(stopwatch)}.',
    );
  }

  Future<void> _initializeProjectDeps(
    List<ResolvedProjectDependency> projectDeps,
  ) async {
    for (var dep in projectDeps) {
      await dep.initialize(_options, _files, _actors);
    }
  }
}

FileCollection _inputsFrom(JbConfigWithImports cwi) {
  return files([?cwi.configFile, ...cwi.imports]);
}

void _wireupTasks(ExtensionProject extensionProject, Set<Task> allTasks) {
  final taskMap = allTasks.groupFoldBy((t) => t.name, (a, b) => b);
  for (final exTask in extensionProject.model.extensionTasks) {
    for (final dep in exTask.dependents) {
      final dependent = taskMap[dep].orThrow(
        () => DartleException(
          message:
              "Task '${exTask.name}' of extension project"
              " '${extensionProject.name}' has non-existent task "
              "dependent '$dep'",
        ),
      );
      dependent.dependsOn({exTask.name});
    }
    for (final dep in exTask.dependsOn) {
      // no need to add dependencies as they're added when the task is created
      taskMap[dep].orThrow(
        () => DartleException(
          message:
              "Task '${exTask.name}' of extension project"
              " '${extensionProject.name}' has non-existent task "
              "dependency '$dep'",
        ),
      );
    }
  }
}
