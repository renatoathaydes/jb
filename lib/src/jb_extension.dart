import 'dart:convert';
import 'dart:io';

import 'package:actors/actors.dart';
import 'package:archive/archive_io.dart';
import 'package:collection/collection.dart';
import 'package:conveniently/conveniently.dart';
import 'package:dartle/dartle.dart';
import 'package:dartle/dartle_cache.dart';
import 'package:isolate_current_directory/isolate_current_directory.dart';
import 'package:jb/src/jb_files.dart';
import 'package:jb/src/jvm_executor.dart';
import 'package:path/path.dart' as p;

import '../jb.dart';
import 'patterns.dart';
import 'runner.dart';

class ExtensionProject {
  final Iterable<Task> tasks;

  ExtensionProject(this.tasks);
}

final class _JbExtensionConfig {
  final String path;
  final String yaml;
  final String scheme;

  Uri get yamlUri => Uri(scheme: scheme, path: path);

  const _JbExtensionConfig(
      {required this.path, required this.yaml, required this.scheme});
}

/// Load an extension project from the given projectPath, if given, or from the default location otherwise.
Future<ExtensionProject?> loadExtensionProject(
    Sendable<JavaCommand, Object?> jvmExecutor,
    JbFiles files,
    Options options,
    String? extensionProjectPath,
    Map<String, Map<String, Object?>> nonConsumedConfig) async {
  final stopWatch = Stopwatch()..start();
  final projectDir = Directory(extensionProjectPath ?? jbExtension);
  if (!await projectDir.exists()) {
    if (extensionProjectPath != null) {
      throw DartleException(
          message: 'Extension project does not exist: $extensionProjectPath');
    }
    logger.finer('No extension project.');
    return null;
  }

  final dir = projectDir.path;
  logger.info(() => '========= Loading jb extension project: $dir =========');

  final extensionConfig = await withCurrentDirectory(dir, () async {
    return await defaultJbConfigSource.load();
  });
  _verify(extensionConfig);

  final runner = JbRunner(files, extensionConfig);
  final workingDir = Directory.current.path;
  await withCurrentDirectory(
      dir,
      () async => await runner.run(
          copyDartleOptions(
              options, const [compileTaskName, installRuntimeDepsTaskName]),
          Stopwatch(),
          isRoot: false));

  logger.fine(() => "Extension project '$dir' initialized,"
      " moving back to $workingDir");

  // Dartle changes the current dir, so we must restore it here
  Directory.current = workingDir;

  final jbExtensionConfig = await extensionConfig.output.when(
    dir: (d) async => await _jbExtensionFromDir(dir, d),
    jar: (j) async => await _jbExtensionFromJar(dir, j),
  );

  final extensionModel = await loadJbExtensionModel(
      jbExtensionConfig.yaml, jbExtensionConfig.yamlUri);

  final tasks = await _createTasks(extensionModel, extensionConfig, jvmExecutor,
          dir, files, nonConsumedConfig)
      .toList();

  logger.log(profile,
      () => 'Loaded jb extension project in ${elapsedTime(stopWatch)}');
  logger.info('========= jb extension loaded =========');

  return ExtensionProject(tasks);
}

Future<_JbExtensionConfig> _jbExtensionFromJar(
    String rootDir, String jarPath) async {
  final stream = InputFileStream(p.join(rootDir, jarPath));
  try {
    final buffer = ZipDecoder().decodeBuffer(stream);
    final extensionEntry = 'META-INF/jb/$jbExtension.yaml';
    final archiveFile =
        buffer.findFile(extensionEntry).orThrow(() => DartleException(
            message: 'jb extension jar at $jarPath '
                'is missing metadata file: $extensionEntry'));
    final content = archiveFile.content as List<int>;
    return _JbExtensionConfig(
        path: '${stream.path}!$extensionEntry',
        yaml: utf8.decode(content),
        scheme: 'jar');
  } finally {
    await stream.close();
  }
}

Future<_JbExtensionConfig> _jbExtensionFromDir(
    String rootDir, String outputDir) async {
  final yamlFile =
      File(p.join(rootDir, outputDir, 'META-INF', 'jb', '$jbExtension.yaml'));
  return _JbExtensionConfig(
      path: yamlFile.path, yaml: await yamlFile.readAsString(), scheme: 'file');
}

void _verify(JbConfiguration config) {
  final hasJbApiDep =
      config.dependencies.keys.any((dep) => dep.startsWith('$jbApi:'));
  if (!hasJbApiDep) {
    throw DartleException(
        message: 'Extension project is missing dependency on jbuild-api.\n'
            "To fix that, add a dependency on '$jbApi:<version>'");
  }
}

Stream<Task> _createTasks(
    JbExtensionModel extensionModel,
    JbConfiguration extensionConfig,
    Sendable<JavaCommand, Object?> jvmExecutor,
    String dir,
    JbFiles files,
    Map<String, Map<String, Object?>> nonConsumedConfig) async* {
  final cache = DartleCache(p.join(dir, files.jbCache));
  final classpath = await _toClasspath(dir, extensionConfig);
  for (final task in extensionModel.extensionTasks) {
    final name = task.name;
    final taskConfig = nonConsumedConfig.remove(name);
    final constructorData =
        resolveConstructor(name, taskConfig, task.constructors);
    yield _createTask(
        jvmExecutor, classpath, task, dir, cache, constructorData);
  }
}

Task _createTask(
    Sendable<JavaCommand, Object?> jvmExecutor,
    String classpath,
    ExtensionTask extensionTask,
    String path,
    DartleCache cache,
    List<Object?> constructorData) {
  final runCondition = _runCondition(extensionTask, path, cache);
  return Task(
      _taskAction(jvmExecutor, classpath, extensionTask, path, constructorData),
      name: extensionTask.name,
      argsValidator: const AcceptAnyArgs(),
      description: extensionTask.description,
      runCondition: runCondition,
      dependsOn: extensionTask.dependsOn,
      phase: extensionTask.phase);
}

Function(List<String> p1) _taskAction(
    Sendable<JavaCommand, Object?> jvmExecutor,
    String classpath,
    ExtensionTask extensionTask,
    String path,
    List<Object?> constructorData) {
  return (args) async {
    logger.fine(() => 'Requesting JBuild to run classpath=$classpath, '
        'className=${extensionTask.className}, '
        'method=${extensionTask.methodName}, '
        'args=$args');
    return await withCurrentDirectory(
        path,
        () async => await jvmExecutor.send(RunJava(
            extensionTask.name,
            classpath,
            extensionTask.className,
            extensionTask.methodName,
            args,
            constructorData)));
  };
}

RunCondition _runCondition(
    ExtensionTask extensionTask, String path, DartleCache cache) {
  if (extensionTask.inputs.isEmpty && extensionTask.outputs.isEmpty) {
    return const AlwaysRun();
  }
  return RunOnChanges(
      cache: cache,
      inputs: patternFileCollection(
          extensionTask.inputs.map((f) => p.join(path, f))),
      outputs: patternFileCollection(
          extensionTask.outputs.map((f) => p.join(path, f))));
}

Future<String> _toClasspath(
    String rootDir, JbConfiguration extensionConfig) async {
  final absRootDir = p.canonicalize(rootDir);
  final artifact = p.join(absRootDir,
      extensionConfig.output.when(dir: (d) => '$d/', jar: (j) => j));
  final libsDir = Directory(p.join(absRootDir, extensionConfig.runtimeLibsDir));
  if (await libsDir.exists()) {
    final libs = await libsDir
        .list()
        .where((f) => f is File && f.path.endsWith('.jar'))
        .map((f) => f.path)
        .toList();
    return libs.followedBy([artifact]).join(Platform.isWindows ? ';' : ':');
  }
  return artifact;
}

/// Resolve a matching constructor for a given taskConfig.
///
/// The list of constructors contains the available Java constructors and must
/// not be empty (Java requires at least one constructor to exist).
/// Values in taskConfig are matched against each constructor parameter by name
/// and then are type checked.
///
/// A value type checks if its type is identical to a [JavaConfigType] parameter
/// or in case of [JavaConfigType.string], if it's `null`.
/// Parameters of type [JavaConfigType.jbuildLogger] must have value `null`,
/// and if not provided this method injects `null` in their place.
List<Object?> resolveConstructor(String name, Map<String, Object?>? taskConfig,
    List<Map<String, JavaConfigType>> constructors) {
  if (taskConfig == null || taskConfig.isEmpty) {
    return _jbuildLoggerConstructorData(constructors) ??
        constructors.firstWhere((c) => c.isEmpty, orElse: () {
          failBuild(
              reason: "Cannot create jb extension task '$name' because "
                  "no configuration has been provided. Add a top-level config"
                  "value with the name '$name', and then configure it using one of "
                  "the following schemas:\n${_constructorsHelp(constructors)}");
        }).vmap((_) => const []);
  }
  final keyMatch =
      constructors.firstWhere((c) => _keysMatch(c, taskConfig), orElse: () {
    if (_requireNoConfiguration(constructors)) {
      failBuild(
          reason: "Cannot create jb extension task 'task' because "
              "configuration was provided for this task when none was "
              "expected. Please remove it from your jb configuration.");
    }
    failBuild(
        reason: "Cannot create jb extension task '$name' because "
            "the provided configuration for this task does not match any of "
            "the acceptable schemas. Please use one of the following schemas:\n"
            "${_constructorsHelp(constructors)}");
  });
  return keyMatch.entries.map((entry) {
    final type = entry.value;
    final value = taskConfig[entry.key];
    if (switch (value.isOfType(type)) {
      Ok(value: var yes) => yes,
      Fail(exception: var e) => failBuild(
          reason: "Cannot create jb extension task '$name' because "
              "property '${entry.key}' is invalid: $e")
    }) return value;
    logger.warning("'Configuration of task '$name' did not type check. "
        "Value of '$value' is not of type $type!");
    failBuild(
        reason: "Cannot create jb extension task '$name' because "
            "the provided configuration for this task does not match any of "
            "the acceptable schemas. Please use one of the following schemas:\n"
            "${_constructorsHelp(constructors)}");
  }).toList(growable: false);
}

bool _keysMatch(
    Map<String, JavaConfigType> constructor, Map<String, Object?> taskConfig) {
  // allow parameters of type JBuildLogger to be missing
  final loggerKeys = constructor.entries
      .where((e) => e.value == JavaConfigType.jbuildLogger)
      .map((e) => e.key)
      .toSet();
  final nonLoggerConfigKeys =
      taskConfig.keys.where(loggerKeys.contains.not$).toSet();
  final nonLoggerParams =
      constructor.keys.where(loggerKeys.contains.not$).toSet();
  return const SetEquality().equals(nonLoggerConfigKeys, nonLoggerParams);
}

bool _requireNoConfiguration(List<Map<String, JavaConfigType>> constructors) {
  return constructors.every((c) =>
      c.isEmpty || c.values.every((e) => e == JavaConfigType.jbuildLogger));
}

String _constructorsHelp(List<Map<String, JavaConfigType>> constructors) {
  final builder = StringBuffer();
  for (final (i, constructor) in constructors.indexed) {
    builder.writeln('  - option${i + 1}:');
    if (constructor.isEmpty) {
      builder.writeln('    <no configuration>');
    } else {
      constructor.forEach((fieldName, type) {
        builder
          ..write('    ')
          ..write(fieldName)
          ..write(': ')
          ..writeln(type);
      });
    }
  }
  return builder.toString();
}

List<Object?>? _jbuildLoggerConstructorData(
    List<Map<String, JavaConfigType>> constructors) {
  return constructors
      .where((c) => c.values.every((v) => v == JavaConfigType.jbuildLogger))
      .sorted((a, b) => b.keys.length.compareTo(a.keys.length))
      .map((c) => c.values.map((_) => null).toList(growable: false))
      .firstOrNull;
}

extension on Object? {
  Result<bool> isOfType(JavaConfigType type) {
    final result = switch (type) {
      JavaConfigType.string => this is String?,
      JavaConfigType.boolean => this is bool,
      JavaConfigType.int => this is int,
      JavaConfigType.float => this is double,
      JavaConfigType.listOfStrings ||
      JavaConfigType.arrayOfStrings =>
        vmap((self) => self is Iterable && self.every((i) => i is String)),
      JavaConfigType.jbuildLogger => this == null ? true : null,
    };
    return result == null
        ? Result.fail(_PropertyCannotBeConfigured(
            'property of type JBuildLogger cannot be configured'))
        : Result.ok(result);
  }
}

final class _PropertyCannotBeConfigured implements Exception {
  final String message;

  const _PropertyCannotBeConfigured(this.message);

  @override
  String toString() => message;
}
