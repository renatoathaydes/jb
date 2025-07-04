import 'dart:convert';
import 'dart:io';

import 'package:dartle/dartle_dart.dart';
import 'package:path/path.dart' as p;

const generateVersionFileTaskName = 'generateVersionFile';

String _versionFilePath = p.join('lib', 'src', 'version.g.dart');

Task generateVersionFileTask = Task(
  _generateVersionFile,
  name: generateVersionFileTaskName,
  description: 'Generates the version file from pubspec.',
  phase: TaskPhase.setup,
  runCondition: RunOnChanges(
    inputs: file('pubspec.yaml'),
    outputs: file(_versionFilePath),
  ),
);

void setupTaskDependencies(DartleDart dartle) {
  dartle.formatCode.dependsOn(const {generateVersionFileTaskName});
  dartle.analyzeCode.dependsOn(const {generateVersionFileTaskName});
}

Future<void> _generateVersionFile(_) async {
  final versionLine = await File('pubspec.yaml')
      .openRead()
      .map(utf8.decode)
      .transform(const LineSplitter())
      .firstWhere((line) => line.startsWith('version: '), orElse: () => '');
  if (versionLine.isEmpty) {
    throw DartleException(message: 'Could not find version in pubspec');
  }
  await _writeVersionFile(versionLine.substring('version: '.length).trim());
}

Future<void> _writeVersionFile(String version) async {
  await File(_versionFilePath).writeAsString('''
// Generated by dartle-src/generate_version_file.dart
const jbVersion = '$version';
''');
}
