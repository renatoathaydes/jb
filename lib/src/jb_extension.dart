import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:dartle/dartle.dart';
import 'package:dartle/dartle_cache.dart';
import 'package:isolate_current_directory/isolate_current_directory.dart';
import 'package:jb/jb.dart';
import 'package:jb/src/jvm_executor.dart';
import 'package:jb/src/patterns.dart';
import 'package:path/path.dart' as p;

import 'utils.dart';

class ExtensionProject {
  final JvmExecutor _executor;
  final Iterable<Task> tasks;

  ExtensionProject(this.tasks, this._executor);

  Future<void> close() async {
    final code = await _executor.close();
    if (code != 0) {
      logger.fine('JvmExecutor closed with code: $code');
    }
  }
}

/// Load an extension project from the given projectPath, if given, or from the default location otherwise.
Future<ExtensionProject?> loadExtensionProject(
    JBuildFiles files, String? projectPath, DartleCache cache) async {
  final projectDir = projectPath?.map((path) => Directory(path)) ??
      files.jbExtensionProjectDir;
  if (await projectDir.exists()) {
    logger.info('========= Loading jb extension project =========');
    final stopWatch = Stopwatch()..start();
    final path = projectDir.path;

    try {
      final config = await withCurrentDirectory(path, () async {
        final configFile = files.configFile;
        if (!(await configFile.exists())) {
          throw DartleException(
              message:
                  'Extension project at $path is missing file ${configFile.path}');
        }
        final options = Options(tasksInvocation: [
          compileTaskName,
          installRuntimeDepsTaskName,
        ]);

        final config = await loadConfig(configFile);
        _verify(config);

        final extensionDartle =
            JBuildDartle.root(files, config, cache, options, stopWatch);

        final closable = await extensionDartle.init;

        try {
          await runBasic(extensionDartle.tasks, extensionDartle.defaultTasks,
              options, cache);
        } finally {
          await closable();
        }

        return config;
      });

      final extensionProject = await _load(path, files.jbuildJar, config);
      logger.log(
          profile,
          () =>
              'Loaded jb extension project in ${stopWatch.elapsedMilliseconds} ms');
      return extensionProject;
    } finally {
      logger.info('========= Loaded jb extension project =========');
    }
  } else if (projectPath != null) {
    throw DartleException(
        message: 'Extension project does not exist: $projectPath');
  }

  return null;
}

void _verify(JBuildConfiguration config) {
  final hasJbApiDep =
      config.dependencies.keys.any((dep) => dep.startsWith('$jbApi:'));
  if (!hasJbApiDep) {
    throw DartleException(
        message: 'Extension project is missing dependency on jbuild-api.\n'
            "To fix that, add a dependency on '$jbApi:<version>'");
  }
}

Future<ExtensionProject> _load(
    String projectPath, File jbuildJar, JBuildConfiguration config) async {
  final jar = config.output.when(
      dir: (d) => throw DartleException(
          message: 'jb extension project must configure an '
              "'output-jar', not 'output-dir'."),
      jar: (j) => p.join(projectPath, j));

  final runtimeLibsDir = p.join(projectPath, config.runtimeLibsDir);

  const extService = 'META-INF/jb/jb-extension.yaml';
  logger.fine('Reading jb extension project manifest file');
  final archive = ZipDecoder().decodeBuffer(InputFileStream(jar));
  final extFile = archive.findFile(extService);
  if (extFile == null) {
    throw DartleException(
        message: 'jb extension project jar is missing manifest file.'
            ' Have you added a dependency on jb to your extension project?');
  }
  final model = await loadJbExtensionModel(
      utf8.decode(extFile.content), Uri.parse('jar:file:$jar!$extService'));

  final classpath =
      await Directory(runtimeLibsDir).toClasspath({File(jar), jbuildJar});
  final jvmExec = JvmExecutor(classpath);
  return ExtensionProject([
    for (final extTask in model.extensionTasks)
      _createTask(jvmExec, extTask, projectPath)
  ], jvmExec);
}

Task _createTask(
    JvmExecutor executor, ExtensionTask extensionTask, String path) {
  final runCondition = _runCondition(extensionTask, path);
  return Task(
      (args) async => await withCurrentDirectory(
          path,
          () async => await executor
              .run(extensionTask.className, extensionTask.methodName, [args])),
      name: extensionTask.name,
      argsValidator: const AcceptAnyArgs(),
      description: extensionTask.description,
      runCondition: runCondition,
      dependsOn: extensionTask.dependsOn,
      phase: extensionTask.phase);
}

RunCondition _runCondition(ExtensionTask extensionTask, String path) {
  if (extensionTask.inputs.isEmpty && extensionTask.outputs.isEmpty) {
    return const AlwaysRun();
  }
  return RunOnChanges(
      inputs: patternFileCollection(
          extensionTask.inputs.map((f) => p.join(path, f))),
      outputs: patternFileCollection(
          extensionTask.outputs.map((f) => p.join(path, f))));
}
