import 'dart:io';

import 'package:dartle/dartle.dart' show Task, TaskPhase;
import 'package:dartle/dartle_dart.dart'
    show DartleDart, DirectoryEntry, RunOnChanges, files, entities;
import 'package:schemake/dart_gen.dart';
import 'package:schemake/json_schema.dart';

import 'config/jb_config_schema.dart';
import 'config/jb_extension_schema.dart';
import 'config/resolved_dependencies.dart';
import 'format.dart';

const generateJbConfigModelTaskName = 'generateJbConfigModel';

void setupTaskDependencies(DartleDart dartleDart) {
  dartleDart.formatCode.dependsOn(const {generateJbConfigModelTaskName});
  dartleDart.analyzeCode.dependsOn(const {generateJbConfigModelTaskName});
}

String _finalPrefix(String _) => '\nfinal ';

Task generateJbConfigModelTask = Task(
  (_) => _generateJbConfigModel(File(configFile), File(jsonSchemaFile)),
  name: generateJbConfigModelTaskName,
  phase: TaskPhase.setup,
  description: 'Generate the jb configuration model from the Schemake schema',
  runCondition: RunOnChanges(
    inputs: entities(
      ['pubspec.yaml'],
      [
        DirectoryEntry(path: 'dartle-src/config', fileExtensions: {'.dart'}),
      ],
    ),
    outputs: files([configFile, jsonSchemaFile]),
  ),
);

Future<void> _generateJbConfigModel(File dartFile, File jsonSchema) async {
  await jsonSchema.parent.create(recursive: true);
  await jsonSchema.writeAsString(
    generateJsonSchema(jbConfig, schemaId: jsonSchemaUri).toString(),
  );
  final writer = dartFile.openWrite();
  try {
    writer.write(
      generateDartClasses(
        [jbConfig, extensionTask, resolvedDependencies],
        options: const DartGeneratorOptions(
          insertBeforeClass: _finalPrefix,
          methodGenerators: [
            ...DartGeneratorOptions.defaultMethodGenerators,
            ...DartGeneratorOptions.jsonMethodGenerators,
          ],
        ),
      ),
    );
  } finally {
    await writer.flush();
    await writer.close();
  }

  // format the generated code to avoid making the 'analyse' task to run
  await formatDart(configFile);
}
