import 'dart:io';

import 'package:dartle/dartle.dart' show Task, TaskPhase;
import 'package:dartle/dartle_dart.dart'
    show DartleDart, DirectoryEntry, RunOnChanges, files, entities;
import 'package:schemake/dart_gen.dart';
import 'package:schemake/json_schema.dart';

import 'config/compilation_path_schema.dart';
import 'config/jb_config_schema.dart';
import 'config/jb_extension_schema.dart';
import 'config/resolved_dependencies.dart';
import 'format.dart';

const generateJbConfigModelTaskName = 'generateJbConfigModel';

const _generatorOptions = DartGeneratorOptions(
  insertBeforeClass: _finalPrefix,
  methodGenerators: [
    ...DartGeneratorOptions.defaultMethodGenerators,
    ...DartGeneratorOptions.jsonMethodGenerators,
  ],
);

void setupTaskDependencies(DartleDart dartleDart) {
  dartleDart.formatCode.dependsOn(const {generateJbConfigModelTaskName});
  dartleDart.analyzeCode.dependsOn(const {generateJbConfigModelTaskName});
}

String _finalPrefix(String _) => '\nfinal ';

Task generateJbConfigModelTask = Task(
  (_) => _generateJbConfigModel(
    File(configFile),
    File(compilationPathFile),
    File(jsonSchemaFile),
  ),
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
    outputs: files([configFile, compilationPathFile, jsonSchemaFile]),
  ),
);

Future<void> _generateJbConfigModel(
  File dartFile,
  File compilationPathFile,
  File jsonSchema,
) async {
  await jsonSchema.parent.create(recursive: true);
  await jsonSchema.writeAsString(
    generateJsonSchema(jbConfig, schemaId: jsonSchemaUri).toString(),
  );
  final writer = dartFile.openWrite();
  await _writeTo(dartFile, (writer) {
    writer.write(
      generateDartClasses([
        jbConfig,
        extensionTask,
        resolvedDependencies,
      ], options: _generatorOptions),
    );
  });

  await _writeTo(compilationPathFile, (writer) {
    writer.write(
      generateDartClasses([compilationPath], options: _generatorOptions),
    );
  });

  // format the generated code to avoid making the 'analyse' task to run
  await formatDart(configFile);
}

Future<void> _writeTo(File file, void Function(IOSink) write) async {
  final writer = file.openWrite();
  try {
    write(writer);
  } finally {
    await writer.flush();
    await writer.close();
  }
}
