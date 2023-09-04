import 'dart:io';

import 'package:dartle/dartle.dart';

import '../config.dart' show logger, jbFile;
import 'basic.dart';
import 'helpers.dart';
import 'jb_extension.dart';

enum _ProjectType { basic, jbExtension }

/// Create a new jb project.
Future<void> createNewProject(List<String> arguments) async {
  if (arguments.length > 1) {
    throw DartleException(
        message: 'create command does not accept any arguments');
  }
  final jbuildFile = File(jbFile);
  await FileCreator(jbuildFile).check();
  await _create(jbuildFile);
}

Future<void> _create(File jbuildFile) async {
  stdout.write('Please enter a project group ID: ');
  final groupId = stdin.readLineSync().or('my-group');
  stdout.write('\nEnter the artifact ID of this project: ');
  final artifactId = stdin.readLineSync().or('my-app');
  final defaultPackage = '${groupId.toJavaId()}.${artifactId.toJavaId()}';
  stdout.write('\nEnter the root package [$defaultPackage]: ');
  final package = stdin.readLineSync().or(defaultPackage).validateJavaPackage();
  stdout.write('\nWould you like to create a test module [Y/n]? ');
  final createTestModule = stdin.readLineSync().or('yes').yesOrNo();
  final projectType = stdin.chooseProjectType();

  List<FileCreator> fileCreators;

  switch (projectType) {
    case _ProjectType.basic:
      fileCreators = getBasicFileCreators(jbuildFile,
          groupId: groupId,
          artifactId: artifactId,
          package: package,
          createTestModule: createTestModule);
      break;
    case _ProjectType.jbExtension:
      fileCreators = getJbExtensionFileCreators(jbuildFile,
          groupId: groupId,
          artifactId: artifactId,
          package: package,
          createTestModule: createTestModule);
      break;
  }

  await _createAll(fileCreators);

  logger.info(() =>
      PlainMessage('\nJBuild project created at ${Directory.current.path}'));
}

Future<void> _createAll(List<FileCreator> fileCreators) async {
  for (final create in fileCreators) {
    await create.check();
  }
  for (final create in fileCreators) {
    await create();
  }
}

extension on Stdin {
  _ProjectType chooseProjectType() {
    stdout.write('\nSelect a project type:\n'
        '  1. basic project.\n'
        '  2. jb extension.\n'
        'Choose [1]: ');

    while (true) {
      final answer = readLineSync()?.trim();
      switch (answer) {
        case '1':
        case '':
          return _ProjectType.basic;
        case '2':
          return _ProjectType.jbExtension;
        case null:
          throw DartleException(message: 'Aborted!');
        default:
          stdout.writeln('ERROR: Please enter a valid option.');
      }
    }
  }
}
