import 'dart:io';

import 'package:dartle/dartle.dart';
import 'package:io/ansi.dart' as ansi;

import '../config.dart' show logger, yamlJbFile;
import 'basic.dart';
import 'helpers.dart';
import 'jb_extension.dart';

enum _ProjectType { basic, jbExtension }

/// Create a new jb project.
Future<void> createNewProject(List<String> arguments,
    {bool colors = true}) async {
  if (arguments.length > 1) {
    throw DartleException(
        message: 'create command does not accept any arguments');
  }
  final jbuildFile = File(yamlJbFile);
  await FileCreator(jbuildFile).check();
  await _create(jbuildFile, colors: colors);
}

Future<void> _create(File jbuildFile, {required bool colors}) async {
  stdout.write(ansi.styleItalic
      .wrap('Please enter a project group ID: ', forScript: !colors));
  final groupId = stdin.readLineSync().or('my-group');
  stdout.write(ansi.styleItalic
      .wrap('\nEnter the artifact ID of this project: ', forScript: !colors));
  final artifactId = stdin.readLineSync().or('my-app');
  final defaultPackage = '${groupId.toJavaId()}.${artifactId.toJavaId()}';
  stdout.write(ansi.styleItalic.wrap(
      '\nEnter the root package [$defaultPackage]: ',
      forScript: !colors));
  final package = stdin.readLineSync().or(defaultPackage).validateJavaPackage();
  stdout.write(ansi.styleItalic.wrap(
      '\nWould you like to create a test module [Y/n]? ',
      forScript: !colors));
  final createTestModule = stdin.readLineSync().or('yes').yesOrNo();
  final projectType = stdin.chooseProjectType(colors: colors);

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

  logger.info(
      () => PlainMessage('\njb project created at ${Directory.current.path}'));
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
  _ProjectType chooseProjectType({required bool colors}) {
    stdout.write(ansi.styleItalic.wrap(
        '\nSelect a project type:\n'
        '  ${ansi.green.wrap('1', forScript: !colors)}. basic project.\n'
        '  ${ansi.green.wrap('2', forScript: !colors)}. jb extension.\n'
        'Choose [1]: ',
        forScript: !colors));

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
          stdout.writeln(ansi.red.wrap('ERROR: Please enter a valid option.'));
      }
    }
  }
}
