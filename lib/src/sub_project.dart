import 'dart:async';
import 'dart:io';

import 'package:dartle/dartle.dart';
import 'package:isolate_current_directory/isolate_current_directory.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import 'config.dart';
import 'jbuild_dartle.dart';
import 'utils.dart';

final Set<String> _projectRoots = {};

/// Factory used to create `SubProject`s given a project's dependencies.
class SubProjectFactory {
  final JBuildComponents components;
  final List<String> cliOptions;

  SubProjectFactory(this.components)
      : cliOptions = components.options.toArgs(includeTasks: false) {
    if (components.projectPath.isEmpty) return;
    final path = components.projectPath.last;
    if (!_projectRoots.add(path)) {
      throw DartleException(
          message: 'Dependency project cycle detected: '
              '${_projectRoots.join(' -> ')} -> $path');
    }
  }

  /// Create sub-projects from provided project dependencies.
  Stream<SubProject> createSubProjects(List<ProjectDependency> deps) async* {
    for (final dep in deps) {
      yield await _createJBuildSubProject(dep);
    }
  }

  Future<SubProject> _createJBuildSubProject(
      ProjectDependency dependency) async {
    final path = dependency.path;
    if (await Directory(path).exists()) {
      final subConfigFile = File(p.join(path, 'jbuild.yaml')).absolute;
      if (await subConfigFile.exists()) {
        try {
          final subJBuildDartle =
              await _resolveSubProject(subConfigFile, dependency.path);
          final subTasks = subJBuildDartle.tasks
              .map((task) =>
                  MapEntry(task.name, _wrapTask(task, path, subJBuildDartle)))
              .toMap();
          return SubProject(subJBuildDartle,
              tasks: subTasks, spec: dependency.spec);
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
      logger.fine(
          () => "Executing subProject '$projectPath' task '${task.name}'");
      return await withCurrentDirectory(path, () async {
        return await task.action(args);
      });
    },
        description: "Run sub-project '$projectPath' task '${task.name}'.",
        name: '$projectName:${task.name}',
        dependsOn: task.depends.map((d) => '$projectName:$d').toSet(),
        runCondition: _subTaskRunCondition(path, task.name, task.runCondition),
        argsValidator: task.argsValidator,
        phase: task.phase);
  }

  Future<JBuildDartle> _resolveSubProject(File configFile, String path) async {
    logger.fine(() => "Resolving sub-project at '${configFile.path}'");
    final dir = p.dirname(configFile.path);
    return await withCurrentDirectory(dir, () async {
      final subConfig = await _resolveSubProjectConfig(configFile);
      final subProject = JBuildDartle(components.child(path, subConfig));
      await subProject.init;
      return subProject;
    });
  }

  Future<JBuildConfiguration> _resolveSubProjectConfig(
      File subConfigFile) async {
    logger.fine(() => 'Reading config file: ${subConfigFile.path}');
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
    // when running a sub-project postRun, we need to convert the invocation
    // so that it looks like the task was invoked directly from the
    // sub-project dir.
    final invocation = _subInvocation(result.invocation);
    return withCurrentDirectory(path, () async {
      await delegate
          .postRun(TaskResult(invocation, result.exceptionAndStackTrace));
    });
  }

  @override
  FutureOr<bool> shouldRun(TaskInvocation invocation) {
    return withCurrentDirectory(path, () async {
      return await delegate.shouldRun(
          TaskInvocation(invocation.task, invocation.args, taskName));
    });
  }

  @override
  String toString() {
    return 'RelativeCondition{path: $path, $delegate}';
  }
}

TaskInvocation _subInvocation(TaskInvocation invocation) {
  final name = invocation.name.substring(invocation.name.lastIndexOf(':') + 1);
  return TaskInvocation(invocation.task, invocation.args, name);
}
