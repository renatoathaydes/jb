import 'dart:async';
import 'dart:io';

import 'package:dartle/dartle.dart';
import 'package:dartle/dartle_cache.dart';
import 'package:jbuild_cli/src/tasks.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import 'config.dart';
import 'exec.dart';
import 'utils.dart';

class SubProjectFactory {
  final JBuildFiles files;
  final JBuildConfiguration config;
  final List<String> taskArgs;
  final DartleCache cache;

  SubProjectFactory(this.files, this.config, Options options, this.cache)
      : taskArgs = options.toArgs(includeTasks: false);

  Stream<SubProject> createSubProjects(List<ProjectDependency> deps) async* {
    for (final dep in deps) {
      yield await _createJBuildSubProject(dep);
    }
  }

  Future<SubProject> _createJBuildSubProject(
      ProjectDependency dependency) async {
    final path = dependency.path;
    final projectName = path.replaceAll(separatorPattern, ':');
    final dir = Directory(path);
    if (await dir.exists()) {
      final subConfigFile = File(p.join(path, 'jbuild.yaml'));
      if (await subConfigFile.exists()) {
        try {
          final subConfig = await _resolveSubProjectConfig(dir, subConfigFile);
          logger.fine(() => 'Sub-project $path configuration: $subConfig');
          return SubProject(
            projectName,
            subConfig.output.when(
                dir: (d) => CompileOutput.dir(p.join(path, d)),
                jar: (j) => CompileOutput.jar(p.join(path, j))),
            dependency.spec,
            compileTask: _createJBuildTask('compile', projectName, path,
                command: 'compile',
                runCondition: createCompileRunCondition(subConfig, cache,
                    rootPath: path)),
            testTask:
                _createJBuildTask('test', projectName, path, command: 'test'),
            cleanTask: _createJBuildTask('clean', projectName, path,
                phase: TaskPhase.setup, command: 'clean'),
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

  Task _createJBuildTask(
      String taskPrefix, String projectName, String subProjectPath,
      {required String command,
      TaskPhase phase = TaskPhase.build,
      RunCondition runCondition = const AlwaysRun()}) {
    final taskName = '$taskPrefix-$projectName';
    return Task((_) async {
      final exitCode = await execJBuildCli(projectName, [command, ...taskArgs],
          workingDir: subProjectPath);
      if (exitCode != 0) {
        throw DartleException(
            message: "Sub-project '$projectName' - task '$taskPrefix' failed");
      }
    },
        name: taskName,
        phase: phase,
        runCondition: runCondition,
        description: "Run $subProjectPath sub-project's $taskPrefix task.");
  }

  Future<JBuildConfiguration> _resolveSubProjectConfig(
      Directory directory, File subConfigFile) async {
    final config = await subConfigFile.readAsString();
    return withCurrentDir(
        directory.path,
        () => configFromJson(
            loadYaml(config, sourceUrl: Uri.parse(subConfigFile.path))));
  }
}
