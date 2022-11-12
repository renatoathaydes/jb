import 'dart:io';

import 'package:dartle/dartle_dart.dart';
import 'package:path/path.dart' as path;

import 'paths.dart';

final _listsJar = path.join(listsMavenRepoProjectSrc, 'lists.jar');
final _listsPom = path.join(listsMavenRepoProjectSrc, 'pom.xml');
final _listsRepoDir =
    path.join(testMavenRepo, 'com', 'example', 'lists', '1.0');

void setupTaskDependencies(DartleDart dartleDart) {
  dartleDart.test.dependsOn(const {'setupTestMvnRepo'});
}

final buildMvnRepoListsProjectTask = Task(buildMvnRepoListsProject,
    description: 'Builds the _lists_ project for the test Maven repository.',
    runCondition: RunOnChanges(
        inputs: dir(listsMavenRepoProjectSrc, fileExtensions: const {'.java'}),
        outputs: file(_listsJar)));

final setupTestMvnRepoTask = Task(setupTestMvnRepo,
    description: 'Creates a simple Maven repository to be used during tests.',
    dependsOn: const {'buildMvnRepoListsProject'},
    runCondition: RunOnChanges(
        inputs: files([_listsPom, _listsJar]),
        outputs: dir(testMavenRepo, fileExtensions: const {'.pom', '.jar'})));

Future<void> setupTestMvnRepo(_) async {
  await Directory(_listsRepoDir).create(recursive: true);
  await File(_listsJar).copy(path.join(_listsRepoDir, 'lists-1.0.jar'));
  await File(_listsPom).copy(path.join(_listsRepoDir, 'lists-1.0.pom'));
}

Future<void> buildMvnRepoListsProject(_) async {
  await _buildProject('lists');
}

Future<void> _buildProject(String name) async {
  final exitCode = await exec(
      Process.start('java', ['-jar', await jbuildJarPath(), 'compile'],
          workingDirectory: listsMavenRepoProjectSrc),
      name: 'java (compile $name project)');

  if (exitCode != 0) {
    throw DartleException(
        message: 'jbuild compile command failed', exitCode: exitCode);
  }
}
