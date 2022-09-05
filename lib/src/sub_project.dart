import 'dart:async';
import 'dart:io';

import 'package:dartle/dartle.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import 'config.dart';
import 'exec.dart';
import 'utils.dart';

class SubProjectFactory {
  final JBuildFiles files;
  final JBuildConfiguration config;

  const SubProjectFactory(this.files, this.config);

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
              _createJBuildTask('compile', projectName, path,
                  command: 'compile'),
              _createJBuildTask('test', projectName, path, command: 'test'),
              _createJBuildTask('clean', projectName, path,
                  phase: TaskPhase.setup, command: 'clean'),
              subConfig.output.when(
                  dir: (d) => CompileOutput.dir(p.join(path, d)),
                  jar: (j) => CompileOutput.jar(p.join(path, j))),
              dependency.spec);
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
      List<String> args = const []}) {
    final taskName = '$taskPrefix-$projectName';
    return Task(
        (_) => execJBuildCli(command, [...config.preArgs(), ...args],
            workingDir: subProjectPath),
        name: taskName,
        phase: phase,
        description: "Run $subProjectPath sub-project's $taskPrefix task.");
  }

  Future<JBuildConfiguration> _resolveSubProjectConfig(
      Directory directory, File subConfigFile) async {
    final config = await subConfigFile.readAsString();
    return withCurrentDir(
        directory.path,
        () async => configFromJson(
            loadYaml(config, sourceUrl: Uri.parse(subConfigFile.path))));
  }
}
