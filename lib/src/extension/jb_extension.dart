import 'dart:convert' show utf8;
import 'dart:io';

import 'package:actors/actors.dart' show Sendable;
import 'package:actors/actors.dart';
import 'package:archive/archive_io.dart';
import 'package:conveniently/conveniently.dart';
import 'package:dartle/dartle.dart'
    show AlwaysRun, Task, profile, elapsedTime, failBuild, dir, file;
import 'package:dartle/dartle_cache.dart' show DartleCache;
import 'package:isolate_current_directory/isolate_current_directory.dart';
import 'package:path/path.dart' as p;

import '../compute_compilation_path.dart' show computeLibsCompilationPath;
import '../config.dart';
import '../config_source.dart';
import '../jb_actors.dart';
import '../jb_files.dart';
import '../jvm_executor.dart';
import '../options.dart';
import '../runner.dart';
import '../tasks.dart';
import '../utils.dart';
import 'cache_model.dart';
import 'extension_pipeline.dart';
import 'extension_tasks.dart';

final class ExtensionProject(
  final String name,
  final String rootDir,
  final String classpath,
  final JbExtensionModel model,
);

final class _JbExtensionConfig({
  required final String path,
  required final String yaml,
  required final String scheme,
}) {
  Uri get yamlUri => Uri(scheme: scheme, path: path);
}

Future<JbExtensionModel> createJbExtensionModel(
  CompileOutput extensionConfigOutput,
  JbConfiguration hostConfig,
  String projectName,
  String rootDir,
  String classpath,
  DartleCache cache,
  Sendable<JavaCommand, Object?> jvmExecutor, {
  required bool extensionUpToDate,
  required bool outputMayChange,
}) async {
  // relative to rootDir, like the output paths used below
  final out = extensionConfigOutput.when(
    dir: (d) => dir(p.join(rootDir, d)),
    jar: (j) => file(p.join(rootDir, j)),
  );
  final jbExtensionConfig = await extensionConfigOutput.when(
    dir: (d) async => await _jbExtensionFromDir(p.join(rootDir, d)),
    jar: (j) async => await _jbExtensionFromJar(p.join(rootDir, j)),
  );
  final taskConfigs = await loadExtensionTaskConfigs(
    jbExtensionConfig.yaml,
    jbExtensionConfig.yamlUri,
  );

  List<ExtensionTask>? extensionTasks;

  if (extensionUpToDate && (!outputMayChange || !await cache.hasChanged(out))) {
    extensionTasks = await loadExtensionTasksFromCache(
      hostConfig,
      taskConfigs,
      cache,
      rootDir,
      projectName,
    );
  }

  if (extensionTasks == null) {
    extensionTasks = await loadExtensionTasks(
      hostConfig,
      classpath,
      taskConfigs,
      jvmExecutor,
      projectName,
    );
    await cacheExtensionTasks(cache, rootDir, extensionTasks);
  }

  return JbExtensionModel(extensionTasks);
}

Future<_JbExtensionConfig> _jbExtensionFromJar(String jarPath) async {
  logger.fine(() => 'Loading jb extension from jar: $jarPath');
  final stream = InputFileStream(jarPath);
  try {
    final buffer = ZipDecoder().decodeStream(stream);
    final extensionEntry = 'META-INF/jb/$jbExtension.yaml';
    final archiveFile = buffer
        .findFile(extensionEntry)
        .orThrow(
          () => failBuild(
            reason:
                'jb extension jar at $jarPath '
                'is missing metadata file: $extensionEntry',
          ),
        );
    final content = archiveFile.content as List<int>;
    return _JbExtensionConfig(
      path: '$jarPath!$extensionEntry',
      yaml: utf8.decode(content),
      scheme: 'jar',
    );
  } finally {
    await stream.close();
  }
}

Future<_JbExtensionConfig> _jbExtensionFromDir(String outputDir) async {
  logger.fine(() => 'Loading jb extension from directory: $outputDir');
  final yamlFile = File(
    p.join(outputDir, 'META-INF', 'jb', '$jbExtension.yaml'),
  );
  return _JbExtensionConfig(
    path: yamlFile.path,
    yaml: await yamlFile.readAsString(),
    scheme: 'file',
  );
}

/// Creates the tasks which build, check and load a local extension project.
///
/// The project is configured and built at creation, as the extension's own
/// jb tasks are only known after it is built.
Future<ExtensionTasks> createLocalExtensionTasks(
  Directory projectDir,
  ExtensionPipelineContext context,
) async {
  final stopWatch = Stopwatch()..start();

  final rootDir = projectDir.path;
  logger.info(
    () => '========= Loading jb extension project: $rootDir =========',
  );

  final extensionCwi = await withCurrentDirectory(rootDir, () async {
    return await defaultJbConfigSource.load();
  }, onError: changedDirectoryOnError(rootDir));
  _verifyJBuildApiDependency(extensionCwi.config);

  final configContainer = await withCurrentDirectory(
    rootDir,
    onError: changedDirectoryOnError(rootDir),
    () => JbConfigContainer(extensionCwi),
  );
  final runner = JbRunner(context.files, extensionCwi, context.actors);

  final absRootDir = p.canonicalize(rootDir);
  final name = configContainer.config.module ?? rootDir;
  final runtimeLibsDir = p.join(
    absRootDir,
    configContainer.config.runtimeLibsDir.asOsPath(),
  );
  final compPathFile = context.compilationPathFile(absRootDir);
  // the key names the tasks which load this extension
  final key = configContainer.config.module ?? p.basename(absRootDir);
  final buildTaskName = 'buildExtension#$key';
  final javaCheckTaskName = 'checkExtensionJavaVersion#$key';
  final loadTaskName = 'loadExtension#$key';

  // whether all the extension project's own tasks were up-to-date
  var extensionUpToDate = false;

  // This task always runs, because the extension's own tasks decide what is
  // up-to-date. Tasks depending on an always-running task also always run,
  // which is why the compilation path is computed here, not in a separate task.
  final build = Task(
    (_) async {
      // run the extension project's compile task so that its
      // jb tasks can be executed later
      final extensionProjectTasks = await withCurrentDirectory(
        rootDir,
        onError: changedDirectoryOnError(rootDir),
        () async => await runner.run(
          context.options.copy(
            tasksInvocation: const [
              compileTaskName,
              installRuntimeDepsTaskName,
            ],
          ),
          isRoot: false,
        ),
      );
      extensionUpToDate = extensionProjectTasks.every(
        (t) => t.mustRunCount == 0,
      );
      logger.log(
        profile,
        () =>
            "Extension project '$rootDir' initialized in ${elapsedTime(stopWatch)}",
      );
      // the runtime libs only change when the extension's own tasks run
      if (!extensionUpToDate || !await File(compPathFile).exists()) {
        await computeLibsCompilationPath(
          'computeExtensionCompilationPath#$key',
          name,
          extensionCwi.config.preArgs(absRootDir),
          context.jBuildSender,
          runtimeLibsDir,
          context.actors.compPath,
          compPathFile,
        );
      }
    },
    name: buildTaskName,
    runCondition: const AlwaysRun(),
    description: 'Builds the jb extension project at $rootDir.',
  );
  final javaCheck = Task(
    (_) => checkDepsJavaVersion(
      context.actors.jvmExecutor,
      context.actors.compPath,
      name,
      runtimeLibsDir,
      compPathFile,
    ),
    name: javaCheckTaskName,
    runCondition: const AlwaysRun(),
    dependsOn: {buildTaskName},
    description: 'Checks the Java version required by extension $name.',
  );
  final load = Task(
    (_) async {
      final classpath = await _toClasspath(rootDir, configContainer);
      final project = await loadExtensionProject(
        context,
        name: name,
        rootDir: rootDir,
        classpath: classpath,
        output: configContainer.output,
        extensionUpToDate: extensionUpToDate,
        // the extension's artifact is re-built when its sources change
        outputMayChange: true,
      );
      context.loaded[loadTaskName] = project;
      logger.info('========= jb extension loaded =========');
    },
    name: loadTaskName,
    runCondition: const AlwaysRun(),
    dependsOn: {javaCheckTaskName},
    description: 'Loads the jb tasks of extension $name.',
  );

  return ExtensionTasks(
    tasks: {build, javaCheck, load},
    loadTaskName: loadTaskName,
  );
}

/// Loads the [ExtensionProject] of an extension whose artifacts are in
/// [rootDir] and [classpath].
///
/// If [outputMayChange] is `false`, the extension's artifact is assumed to be
/// the same as in the last load, so it is not checked for changes.
Future<ExtensionProject> loadExtensionProject(
  ExtensionPipelineContext context, {
  required String name,
  required String rootDir,
  required String classpath,
  required CompileOutput output,
  required bool extensionUpToDate,
  required bool outputMayChange,
}) async {
  final model = await createJbExtensionModel(
    output,
    context.config,
    name,
    rootDir,
    classpath,
    context.cache,
    context.actors.jvmExecutor.takingJavaCommands(),
    extensionUpToDate: extensionUpToDate,
    outputMayChange: outputMayChange,
  );
  _warnOnUnexpectedConfig(model, context.config.extras);
  return ExtensionProject(name, p.canonicalize(rootDir), classpath, model);
}

void _verifyJBuildApiDependency(JbConfiguration config) {
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

void _warnOnUnexpectedConfig(
  JbExtensionModel extensionModel,
  Map<String, Object?> extras,
) {
  // extension project's task names including also qualified names
  final taskNames = extensionModel.extensionTasks
      .expand((t) => [t.name, t.qualifiedName])
      .toSet();
  final unknownKeys = extras.keys.where(taskNames.contains.not$);
  if (unknownKeys.isNotEmpty) {
    logger.warning(
      () =>
          'jb configuration keys do not match any known parameter or extension task: $unknownKeys',
    );
  }
}

class JbExtensionModelBuilder {
  final Sendable<JavaCommand, Object?> jvmExecutor;

  const JbExtensionModelBuilder(this.jvmExecutor);
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
    p.join(absRootDir, extensionConfig.config.runtimeLibsDir.asOsPath()),
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
