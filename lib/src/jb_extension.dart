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

import 'path_dependency.dart';
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
    JBuildFiles files,
    String? projectPath,
    SubProjectFactory subProjectFactory,
    DartleCache cache) async {
  final projectDir = projectPath?.map((path) => Directory(path)) ??
      files.jbExtensionProjectDir;
  if (await projectDir.exists()) {
    logger.fine('Loading jb extension project');
    final path = projectDir.path;
    final jbExtensionProject = await subProjectFactory.createJBuildSubProject(
        ProjectDependency(
            DependencySpec(
                transitive: false, scope: DependencyScope.all, path: path),
            path));

    logger.fine(() => 'Verifying jb extension project');
    _verify(jbExtensionProject);

    logger.fine('Running jb extension project build');

    await runBasic(
        jbExtensionProject.tasks.values.toSet(),
        const {},
        Options(tasksInvocation: [
          '$path:$compileTaskName',
          '$path:$installRuntimeDepsTaskName',
        ]),
        cache);

    return await _load(path, files.jbuildJar, jbExtensionProject);
  } else if (projectPath != null) {
    throw DartleException(
        message: 'Extension project does not exist: $projectPath');
  }

  return null;
}

void _verify(SubProject project) {
  const jbApi = 'com.athaydes.jb:jb-api';
  final hasJbApiDep =
      project.config.dependencies.keys.any((dep) => dep.startsWith('$jbApi:'));
  if (!hasJbApiDep) {
    throw DartleException(
        message: 'Extension project is missing dependency on jb-api.\n'
            "To fix that, add a dependency on '$jbApi:<version>'");
  }
}

Future<ExtensionProject> _load(
    String projectPath, File jbuildJar, SubProject subProject) async {
  final jar = subProject.config.output.when(
      dir: (d) => throw DartleException(
          message: 'jb extension project must configure an '
              "'output-jar', not 'output-dir'."),
      jar: (j) => p.join(projectPath, j));

  final runtimeLibsDir = p.join(projectPath, subProject.config.runtimeLibsDir);

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
          () async => await executor.run(extensionTask.className,
              extensionTask.methodName, [args])),
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
