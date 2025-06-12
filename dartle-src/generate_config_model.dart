import 'dart:io';

import 'package:dartle/dartle.dart' show Task, TaskPhase;
import 'package:dartle/dartle_dart.dart' show DartleDart, RunOnChanges, file;
import 'package:schemake/dart_gen.dart';

import 'config/jb_config_schema.dart';
import 'config/jb_extension_schema.dart';
import 'config/resolved_dependencies.dart';
import 'format.dart';

const generateJbConfigModelTaskName = 'generateJbConfigModel';

void setupTaskDependencies(DartleDart dartleDart) {
  dartleDart.formatCode.dependsOn(const {generateJbConfigModelTaskName});
  dartleDart.analyzeCode.dependsOn(const {generateJbConfigModelTaskName});
}

const outputFile = configFile;

Task generateJbConfigModelTask = Task(
  (_) => _generateJbConfigModel(File(outputFile)),
  name: generateJbConfigModelTaskName,
  phase: TaskPhase.setup,
  description: 'Generate the jb configuration model from the Schemake schema',
  runCondition: RunOnChanges(
    inputs: file('pubspec.yaml'),
    outputs: file(outputFile),
  ),
);

Future<void> _generateJbConfigModel(File output) async {
  final writer = output.openWrite();
  try {
    writer.write(
      generateDartClasses(
        [jbConfig, extensionTask, resolvedDependencies],
        options: const DartGeneratorOptions(
          methodGenerators: [
            ...DartGeneratorOptions.defaultMethodGenerators,
            DartToJsonMethodGenerator(),
            DartFromJsonMethodGenerator(),
          ],
        ),
      ),
    );
  } finally {
    await writer.flush();
    await writer.close();
  }

  // format the generated code to avoid making the 'analyse' task to run
  await formatDart(outputFile);
}
