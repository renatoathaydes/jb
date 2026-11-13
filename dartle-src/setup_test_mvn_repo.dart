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
const buildMvnRepoExampleExtensionTaskName = 'buildMvnRepoExampleExtension';
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

final _exampleExtensionProjectDir = path.join(
  testProjectsDir,
  'example-extension',
);
final _exampleExtensionJbuildYaml = path.join(
  _exampleExtensionProjectDir,
  'jbuild.yaml',
);
final _exampleExtensionSrcDir = path.join(_exampleExtensionProjectDir, 'src');

final _extensionProjectDir = path.join(testMavenRepoSrc, 'example-extension');
final _extensionJar = path.join(
  _extensionProjectDir,
  'build',
  'example-extension.jar',
);
final _extensionProjectPom = path.join(_extensionProjectDir, 'pom.xml');
final _extensionRepoDir = path.join(
  testMavenRepo,
  'com',
  'example',
  'example-extension',
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
    outputs: files([_listsJar, '$_listsJar.sha1']),
  ),
);

final buildMvnRepoExampleExtensionTask = Task(
  _buildMvnRepoExampleExtension,
  name: buildMvnRepoExampleExtensionTaskName,
  phase: setupTestsPhase,
  description: 'Builds the example-extension jb extension for the test Maven repository.',
  runCondition: RunOnChanges(
    inputs: entities(
      [_exampleExtensionJbuildYaml, _extensionProjectPom],
      [
        DirectoryEntry(
          path: _exampleExtensionSrcDir,
          fileExtensions: const {'.java'},
        ),
      ],
    ),
    outputs: files([_extensionJar, '$_extensionJar.sha1']),
  ),
);

final setupTestMvnRepoTask = Task(
  _setupTestMvnRepo,
  name: setupTestMvnRepoTaskName,
  phase: setupTestsPhase,
  description: 'Creates a simple Maven repository to be used during tests.',
  dependsOn: const {
    buildMvnRepoListsProjectTaskName,
    buildMvnRepoExampleExtensionTaskName,
  },
  runCondition: RunOnChanges(
    inputs: entities(
      [_listsPom, _listsJar, _extensionProjectPom, _extensionJar],
      [DirectoryEntry(path: testMavenRepoPreBuilt)],
    ),
    outputs: dir(testMavenRepo, fileExtensions: const {'.pom', '.jar'}),
  ),
);

Future<void> _setupTestMvnRepo(_) async {
  await Directory(_listsRepoDir).create(recursive: true);
  await File(_listsJar).copy(path.join(_listsRepoDir, 'lists-1.0.jar'));
  await File('$_listsJar.sha1')
      .copy(path.join(_listsRepoDir, 'lists-1.0.jar.sha1'));
  await File(_listsPom).copy(path.join(_listsRepoDir, 'lists-1.0.pom'));

  await Directory(_extensionRepoDir).create(recursive: true);
  await File(_extensionJar)
      .copy(path.join(_extensionRepoDir, 'example-extension-1.0.jar'));
  await File('$_extensionJar.sha1')
      .copy(path.join(_extensionRepoDir, 'example-extension-1.0.jar.sha1'));
  await File(_extensionProjectPom)
      .copy(path.join(_extensionRepoDir, 'example-extension-1.0.pom'));

  await Directory(testMavenRepoPreBuilt)
      .copyContentsInto(testMavenRepo)
      .drain();
}

Future<void> _buildMvnRepoListsProject(_) async {
  await _buildProject(
    name: 'lists',
    workingDirectory: listsMavenRepoProjectSrc,
    jarPath: path.join('build', 'lists.jar'),
    javacArgs: const ['--', '--release', '11'],
  );
}

Future<void> _buildMvnRepoExampleExtension(_) async {
  await Directory(path.dirname(_extensionJar)).create(recursive: true);
  await _buildProject(
    name: 'example-extension',
    workingDirectory: _exampleExtensionProjectDir,
    // the extension's own build dir is cleaned by tests, so use the repo src dir
    jarPath: path.absolute(_extensionJar),
    jbExtension: true,
  );
}

Future<void> _buildProject({
  required String name,
  required String workingDirectory,
  required String jarPath,
  List<String> javacArgs = const [],
  bool jbExtension = false,
}) async {
  final exitCode = await exec(
    Process.start('java', [
      '-jar',
      await jbuildJarPath(),
      'compile',
      '-j',
      jarPath,
      '--checksum',
      if (jbExtension) '--jb-extension',
      if (javacArgs.isNotEmpty) ...javacArgs,
    ], workingDirectory: workingDirectory),
    name: 'java (compile $name project)',
  );

  if (exitCode != 0) {
    throw DartleException(
      message: 'jbuild compile command failed',
      exitCode: exitCode,
    );
  }
}
