import 'dart:io';

import 'package:actors/actors.dart';
import 'package:dartle/dartle.dart'
    show
        Task,
        Options,
        profile,
        elapsedTime,
        AcceptAnyArgs,
        RunOnChanges,
        RunCondition,
        ChangeSet,
        AlwaysRun,
        failBuild;
import 'package:dartle/dartle_cache.dart' show DartleCache;
import 'package:isolate_current_directory/isolate_current_directory.dart';
import 'package:path/path.dart' as p;

import '../config.dart';
import '../config_source.dart';
import '../jb_files.dart';
import '../jvm_executor.dart';
import '../options.dart';
import '../patterns.dart';
import '../runner.dart';
import '../tasks.dart';
import '../utils.dart';
import '../xml_rpc_structs.dart';
import 'cache_model.dart';

class ExtensionProject {
  final String name;
  final String rootDir;
  final JbExtensionModel model;
  final List<Task> tasks;

  const ExtensionProject(this.name, this.rootDir, this.model, this.tasks);
}

/// Load an extension project from the given projectPath, if given, or from the default location otherwise.
Future<ExtensionProject?> loadExtensionProject(
  Sendable<JavaCommand, Object?> jvmExecutor,
  JbFiles files,
  Options options,
  JbConfiguration config,
  DartleCache cache,
) async {
  final extensionProjectPath = config.extensionProject;
  final stopWatch = Stopwatch()..start();
  final projectDir = Directory(extensionProjectPath ?? jbExtension);
  if (!await projectDir.exists()) {
    if (extensionProjectPath != null) {
      failBuild(
        reason: 'Extension project does not exist: $extensionProjectPath',
      );
    }
    logger.finer('No extension project.');
    return null;
  }

  final rootDir = projectDir.path;
  logger.info(
    () => '========= Loading jb extension project: $rootDir =========',
  );

  final extensionConfig = await withCurrentDirectory(rootDir, () async {
    return await defaultJbConfigSource.load();
  });
  _verify(extensionConfig);

  final configContainer = await withCurrentDirectory(
    rootDir,
    () => JbConfigContainer(config),
  );
  final runner = JbRunner(files, extensionConfig, jvmExecutor);

  // run the extension project's compile task so that its
  // jb tasks can be executed later
  await withCurrentDirectory(
    rootDir,
    () async => await runner.run(
      options.copy(
        tasksInvocation: const [compileTaskName, installRuntimeDepsTaskName],
      ),
      Stopwatch(),
      isRoot: false,
    ),
  );

  logger.fine(() => "Extension project '$rootDir' initialized");

  final absRootDir = p.canonicalize(rootDir);
  final classpath = await _toClasspath(rootDir, configContainer);

  final extensionModel = await createJbExtensionModel(
    configContainer,
    rootDir,
    classpath,
    cache,
    jvmExecutor,
  );

  // convert the [ExtensionTask]s and constructor data into Dartle [Task]s
  final tasks = extensionModel.extensionTasks
      .map((extensionTask) {
        return _createTask(
          jvmExecutor,
          classpath,
          extensionTask,
          absRootDir,
          cache,
        );
      })
      .toList(growable: false);

  logger.log(
    profile,
    () => 'Loaded jb extension project in ${elapsedTime(stopWatch)}',
  );
  logger.info('========= jb extension loaded =========');

  return ExtensionProject(rootDir, absRootDir, extensionModel, tasks);
}

void _verify(JbConfiguration config) {
  final hasJbApiDep = config.dependencies.keys.any(
    (dep) => dep.startsWith('$jbApi:'),
  );
  if (!hasJbApiDep) {
    failBuild(
      reason:
          'Extension project is missing dependency on jbuild-api.\n'
          "To fix that, add a dependency on '$jbApi:<version>'",
    );
  }
}

class JbExtensionModelBuilder {
  final Sendable<JavaCommand, Object?> jvmExecutor;

  const JbExtensionModelBuilder(this.jvmExecutor);
}

Task _createTask(
  Sendable<JavaCommand, Object?> jvmExecutor,
  String classpath,
  ExtensionTask extensionTask,
  String absRootDir,
  DartleCache cache,
) {
  final runCondition = _runCondition(extensionTask, cache);
  return Task(
    _taskAction(jvmExecutor, classpath, absRootDir, extensionTask),
    name: extensionTask.name,
    argsValidator: const AcceptAnyArgs(),
    description: extensionTask.description,
    runCondition: runCondition,
    dependsOn: extensionTask.dependsOn.toSet(),
    phase: extensionTask.phase,
  );
}

Future<void> Function(List<String>, [ChangeSet?]) _taskAction(
  Sendable<JavaCommand, Object?> jvmExecutor,
  String classpath,
  String absRootDir,
  ExtensionTask extensionTask,
) {
  return (List<String> taskArgs, [ChangeSet? changes]) async {
    logger.fine(
      () =>
          'Requesting JBuild to run classpath=$classpath, '
          'className=${extensionTask.className}, '
          'method=${extensionTask.methodName}, '
          'args=$taskArgs, '
          'changes=$changes',
    );
    await jvmExecutor.send(
      RunJava(
        extensionTask.name,
        classpath,
        extensionTask.className,
        extensionTask.methodName,
        [changes?.toMap(), taskArgs],
        extensionTask.constructorData,
      ),
    );
  };
}

RunCondition _runCondition(ExtensionTask extensionTask, DartleCache cache) {
  final dependsOnJbConfig = extensionTask.basicConfig.constructors.any(
    (c) => c.values.any((v) => v == ConfigType.jbConfig),
  );

  if (!dependsOnJbConfig &&
      extensionTask.inputs.isEmpty &&
      extensionTask.outputs.isEmpty) {
    return const AlwaysRun();
  }
  return RunOnChanges(
    cache: cache,
    inputs: patternFileCollection(
      extensionTask.inputs.followedBy([yamlJbFile, jsonJbFile]),
    ),
    outputs: patternFileCollection(extensionTask.outputs),
  );
}

Future<String> _toClasspath(
  String absRootDir,
  JbConfigContainer extensionConfig,
) async {
  final artifact = p.join(
    absRootDir,
    extensionConfig.output.when(dir: (d) => d.asDirPath(), jar: (j) => j),
  );
  final libsDir = Directory(
    p.join(absRootDir, extensionConfig.config.runtimeLibsDir),
  );
  logger.fine(
    () =>
        'Extension artifact: $artifact, '
        'Extension libs dir: ${libsDir.path}',
  );
  if (await libsDir.exists()) {
    final libs = await libsDir
        .list()
        .where((f) => f is File && f.path.endsWith('.jar'))
        .map((f) => f.path)
        .toList();
    return libs.followedBy([artifact]).join(classpathSeparator);
  }
  return artifact;
}
