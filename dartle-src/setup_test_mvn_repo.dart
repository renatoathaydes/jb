import 'dart:io';

import 'package:dartle/dartle_dart.dart';
import 'package:path/path.dart' as path;

// for copyContentsInto
import '../lib/src/utils.dart' show DirectoryExtension;
import 'paths.dart';

final setupTestsPhase = TaskPhase.custom(
  TaskPhase.setup.index + 1,
  'setupTests',
);

const buildMvnRepoListsProjectTaskName = 'buildMvnRepoListsProject';
const setupTestMvnRepoTaskName = 'setupTestMvnRepo';

final _listsJar = path.join(listsMavenRepoProjectSrc, 'build', 'lists.jar');
final _listsPom = path.join(listsMavenRepoProjectSrc, 'pom.xml');
final _listsRepoDir = path.join(
  testMavenRepo,
  'com',
  'example',
  'lists',
  '1.0',
);

void setupTaskDependencies(DartleDart dartleDart) {
  dartleDart.test.dependsOn(const {setupTestMvnRepoTaskName});
}

final buildMvnRepoListsProjectTask = Task(
  _buildMvnRepoListsProject,
  name: buildMvnRepoListsProjectTaskName,
  phase: setupTestsPhase,
  description: 'Builds the _lists_ project for the test Maven repository.',
  runCondition: RunOnChanges(
    inputs: dir(listsMavenRepoProjectSrc, fileExtensions: const {'.java'}),
    outputs: file(_listsJar),
  ),
);

final setupTestMvnRepoTask = Task(
  _setupTestMvnRepo,
  name: setupTestMvnRepoTaskName,
  phase: setupTestsPhase,
  description: 'Creates a simple Maven repository to be used during tests.',
  dependsOn: const {buildMvnRepoListsProjectTaskName},
  runCondition: RunOnChanges(
    inputs: entities(
      [_listsPom, _listsJar],
      [DirectoryEntry(path: testMavenRepoPreBuilt)],
    ),
    outputs: dir(testMavenRepo, fileExtensions: const {'.pom', '.jar'}),
  ),
);

Future<void> _setupTestMvnRepo(_) async {
  await Directory(_listsRepoDir).create(recursive: true);
  await File(_listsJar).copy(path.join(_listsRepoDir, 'lists-1.0.jar'));
  await File(_listsPom).copy(path.join(_listsRepoDir, 'lists-1.0.pom'));

  await Directory(testMavenRepoPreBuilt).copyContentsInto(testMavenRepo);
}

Future<void> _buildMvnRepoListsProject(_) async {
  await _buildProject('lists');
}

Future<void> _buildProject(String name) async {
  final exitCode = await exec(
    Process.start('java', [
      '-jar',
      await jbuildJarPath(),
      'compile',
      '-j',
      path.join('build', 'lists.jar'),
      '--',
      '--release',
      '11',
    ], workingDirectory: listsMavenRepoProjectSrc),
    name: 'java (compile $name project)',
  );

  if (exitCode != 0) {
    throw DartleException(
      message: 'jbuild compile command failed',
      exitCode: exitCode,
    );
  }
}
