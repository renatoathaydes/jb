import 'dart:async';
import 'dart:io';

import 'package:dartle/dartle.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import 'config.dart';
import 'exec.dart';
import 'jbuild_dartle.dart';
import 'utils.dart';

class SubProjectFactory {
  final JBuildComponents components;
  final List<String> cliOptions;

  SubProjectFactory(this.components)
      : cliOptions = components.options.toArgs(includeTasks: false);

  Stream<SubProject> createSubProjects(List<ProjectDependency> deps) async* {
    for (final dep in deps) {
      yield await _createJBuildSubProject(dep);
    }
  }

  Future<SubProject> _createJBuildSubProject(
      ProjectDependency dependency) async {
    final path = dependency.path;
    if (await Directory(path).exists()) {
      final subConfigFile = File(p.join(path, 'jbuild.yaml'));
      if (await subConfigFile.exists()) {
        try {
          final subJBuildDartle = await _resolveSubProject(path);
          final subConfig = subJBuildDartle.config;
          final subTasks = subJBuildDartle.tasks
              .map((task) =>
                  MapEntry(task.name, _wrapTask(task, path, subJBuildDartle)))
              .toMap();
          return SubProject(
            subJBuildDartle.projectPath,
            subConfig.output.when(
                dir: (d) => CompileOutput.dir(p.join(path, d)),
                jar: (j) => CompileOutput.jar(p.join(path, j))),
            dependency.spec,
            compileLibsDir: p.join(path, subConfig.compileLibsDir),
            runtimeLibsDir: p.join(path, subConfig.runtimeLibsDir),
            tasks: subTasks,
          );
        } catch (e) {
          throw DartleException(
              message: 'Could not load sub-project at $path: $e');
        }
      }
    }
    throw DartleException(
        message:
            'Cannot use path as a sub-project (not jar file or directory): $path');
  }

  Task _wrapTask(Task task, String path, JBuildDartle subProject) {
    final projectPath = subProject.projectPath;
    final projectName = subProject.projectName;
    return Task((args) async {
      logger
          .fine(() => "Executing subProject '$projectPath' task '${task.name}' "
              "on a separate process");
      final exitCode = await execJBuildCli(
          projectPath, [...cliOptions, task.name, ...args.map((a) => ':$a')],
          workingDir: path);
      if (exitCode != 0) {
        throw DartleException(
            message: "Task '$projectPath:${task.name}' failed");
      }
    },
        description: "Run subProject '$projectPath' task '${task.name}'.",
        name: '$projectName:${task.name}',
        dependsOn: task.depends.map((d) => '$projectName:$d').toSet(),
        runCondition: _subTaskRunCondition(path, task.name, task.runCondition),
        argsValidator: task.argsValidator,
        phase: task.phase);
  }

  Future<JBuildDartle> _resolveSubProject(String path) async {
    return await withCurrentDir(path, () async {
      final subConfig =
          await _resolveSubProjectConfig(components.files.configFile);
      final subProject =
          JBuildDartle(components.child(p.basename(path), subConfig));
      await subProject.init;
      return subProject;
    });
  }

  Future<JBuildConfiguration> _resolveSubProjectConfig(
      File subConfigFile) async {
    final config = await subConfigFile.readAsString();
    return configFromJson(
        loadYaml(config, sourceUrl: Uri.parse(subConfigFile.path)));
  }

  RunCondition _subTaskRunCondition(
      String path, String taskName, RunCondition runCondition) {
    if (runCondition is FilesCondition) {
      return _SubProjectRunCondition(path, taskName, runCondition);
    }
    return runCondition;
  }
}

extension _FileCollectionExtension on FileCollection {
  FileCollection relativize(String path) {
    if (isEmpty) return FileCollection.empty;
    return entities(
        this.files.map((e) => p.join(path, e)),
        directories.map((e) => DirectoryEntry(
            path: p.join(path, e.path),
            recurse: e.recurse,
            includeHidden: e.includeHidden,
            exclusions: e.exclusions,
            fileExtensions: e.fileExtensions)));
  }
}

class _SubProjectRunCondition implements FilesCondition {
  final String path;
  final String taskName;
  final FilesCondition delegate;

  @override
  late final FileCollection deletions;
  @override
  late final FileCollection inputs;
  @override
  late final FileCollection outputs;

  _SubProjectRunCondition(this.path, this.taskName, this.delegate) {
    deletions = delegate.deletions.relativize(path);
    inputs = delegate.inputs.relativize(path);
    outputs = delegate.outputs.relativize(path);
  }

  @override
  FutureOr<void> postRun(TaskResult result) {
    // nothing to do because the task will be executed in a sub-process,
    // which will itself take care of doing this.
  }

  @override
  FutureOr<bool> shouldRun(TaskInvocation invocation) {
    // We do need to check if the task should run in the current process!
    // This is safe because Dartle always calls this in the main Isolate,
    // before running any tasks.
    return withCurrentDir(path, () async {
      return await delegate.shouldRun(
          TaskInvocation(invocation.task, invocation.args, taskName));
    });
  }

  @override
  String toString() {
    return 'RelativeCondition{path: $path, $delegate}';
  }
}
