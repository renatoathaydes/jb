import 'dart:async';
import 'dart:io';

import 'package:dartle/dartle.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import 'config.dart';
import 'exec.dart';

class SubProjectFactory {
  final JBuildFiles files;
  final JBuildConfiguration config;

  const SubProjectFactory(this.files, this.config);

  Stream<SubProject> createSubProjects(Stream<PathDependency> deps) async* {
    await for (final dep in deps) {
      yield await dep.when(
          jar: _createJarSubProject, jbuildProject: _createJBuildSubProject);
    }
  }

  FutureOr<SubProject> _createJarSubProject(DependencySpec spec, String path) {
    if (p.extension(path) == 'jar') {
      return SubProject.jar(File(path));
    }
    throw DartleException(
        message:
            'Cannot use path as a sub-project (not jar file or directory): $path');
  }

  Future<SubProject> _createJBuildSubProject(
      DependencySpec spec, String path) async {
    final dir = Directory(path);
    if (await dir.exists()) {
      final jbuildFile = File(p.join(path, 'jbuild.yaml'));
      if (await jbuildFile.exists()) {
        try {
          final subConfig = configFromJson(loadYaml(
              await jbuildFile.readAsString(),
              sourceUrl: Uri.parse(jbuildFile.path)));
          return SubProject.project(
              _createJBuildTask('compile', path, command: 'compile'),
              _createJBuildTask('test', path, command: 'test'),
              subConfig.output);
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

  Task _createJBuildTask(String taskPrefix, String subProjectPath,
      {required String command, List<String> args = const []}) {
    final taskName = '$taskPrefix-$subProjectPath';
    return Task((_) => execJBuildCli(command, [...config.preArgs(), ...args]),
        name: taskName, description: 'Run $subProjectPath $taskPrefix task.');
  }
}
