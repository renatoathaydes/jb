import 'dart:convert';
import 'dart:io';

import 'package:actors/actors.dart';
import 'package:archive/archive_io.dart';
import 'package:collection/collection.dart' as col;
import 'package:conveniently/conveniently.dart';
import 'package:dartle/dartle.dart'
    show
        Task,
        Options,
        profile,
        elapsedTime,
        AcceptAnyArgs,
        RunOnChanges,
        RunCondition,
        AlwaysRun,
        failBuild;
import 'package:dartle/dartle_cache.dart' show DartleCache;
import 'package:isolate_current_directory/isolate_current_directory.dart';
import 'package:path/path.dart' as p;

import 'config.dart';
import 'config_source.dart';
import 'jb_files.dart';
import 'jvm_executor.dart';
import 'options.dart';
import 'patterns.dart';
import 'runner.dart';
import 'tasks.dart';

class ExtensionProject {
  final String name;
  final JbExtensionModel model;
  final Iterable<Task> tasks;

  const ExtensionProject(this.name, this.model, this.tasks);
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
    JbConfiguration config,
    DartleCache cache) async {
  final extensionProjectPath = config.extensionProject;
  final stopWatch = Stopwatch()..start();
  final projectDir = Directory(extensionProjectPath ?? jbExtension);
  if (!await projectDir.exists()) {
    if (extensionProjectPath != null) {
      failBuild(
          reason: 'Extension project does not exist: $extensionProjectPath');
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

  final configContainer =
      await withCurrentDirectory(dir, () => JbConfigContainer(config));
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

  final jbExtensionConfig = await configContainer.output.when(
    dir: (d) async => await _jbExtensionFromDir(dir, d),
    jar: (j) async => await _jbExtensionFromJar(dir, j),
  );

  final taskConfigs = await loadExtensionTaskConfigs(
      config, jbExtensionConfig.yaml, jbExtensionConfig.yamlUri);

  final classpath = await _toClasspath(dir, configContainer);

  final extensionModel =
      await _loadExtensionModel(config, taskConfigs, jvmExecutor, classpath);

  final tasks = await _createTasks(extensionModel, configContainer, jvmExecutor,
          dir, files, config, cache)
      .toList();

  logger.log(profile,
      () => 'Loaded jb extension project in ${elapsedTime(stopWatch)}');
  logger.info('========= jb extension loaded =========');

  return ExtensionProject(projectDir.path, extensionModel, tasks);
}

Future<JbExtensionModel> _loadExtensionModel(
    JbConfiguration config,
    List<ExtensionTaskConfig> taskConfigs,
    Sendable<JavaCommand, Object?> jvmExecutor,
    String classpath) async {
  final tasks =
      _loadExtensionTasks(config, classpath, taskConfigs, jvmExecutor);
  return JbExtensionModel(config, classpath, await tasks.toList());
}

Stream<ExtensionTask> _loadExtensionTasks(
    JbConfiguration config,
    String classpath,
    List<ExtensionTaskConfig> taskConfigs,
    Sendable<JavaCommand, Object?> jvmExecutor) async* {
  for (final taskConfig in taskConfigs) {
    final name = taskConfig.name;
    final taskConfigData = config.extras[name];
    if (taskConfigData is! Map<String, Object>?) {
      failBuild(
          reason: "Cannot create jb extension task '$name' because the "
              "provided configuration is not an object: $taskConfigData");
    }

    final constructorData = resolveConstructorData(
        taskConfig.name, taskConfigData, taskConfig.constructors, config);

    logger.fine(() => "Resolved data for constructor of extension "
        "task '$name': $constructorData");

    final summary = await jvmExecutor.send(RunJava(
        '_getSummary_${taskConfig.name}',
        classpath,
        taskConfig.className,
        'getSummary',
        const [],
        constructorData));
    if (summary is List && summary.length == 4) {
      final [inputs, outputs, dependsOn, dependents] = summary;
      yield ExtensionTask.from(taskConfig,
          inputs: _ensureStringSet(inputs),
          outputs: _ensureStringSet(outputs),
          dependsOn: _ensureStringSet(dependsOn),
          dependents: _ensureStringSet(dependents),
          constructorData: constructorData);
    } else {
      failBuild(
          reason: 'getSummary should return list with 4 elements, '
              'but got: $summary');
    }
  }
}

Future<_JbExtensionConfig> _jbExtensionFromJar(
    String rootDir, String jarPath) async {
  final path = p.join(rootDir, jarPath);
  final stream = InputFileStream(path);
  try {
    final buffer = ZipDecoder().decodeBuffer(stream);
    final extensionEntry = 'META-INF/jb/$jbExtension.yaml';
    final archiveFile = buffer.findFile(extensionEntry).orThrow(() => failBuild(
        reason: 'jb extension jar at $jarPath '
            'is missing metadata file: $extensionEntry'));
    final content = archiveFile.content as List<int>;
    return _JbExtensionConfig(
        path: '$path!$extensionEntry',
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
    failBuild(
        reason: 'Extension project is missing dependency on jbuild-api.\n'
            "To fix that, add a dependency on '$jbApi:<version>'");
  }
}

class JbExtensionModelBuilder {
  final Sendable<JavaCommand, Object?> jvmExecutor;

  const JbExtensionModelBuilder(this.jvmExecutor);
}

Stream<Task> _createTasks(
    JbExtensionModel extensionModel,
    JbConfigContainer extensionConfig,
    Sendable<JavaCommand, Object?> jvmExecutor,
    String extensionDir,
    JbFiles files,
    JbConfiguration config,
    DartleCache cache) async* {
  for (final task in extensionModel.extensionTasks) {
    yield _createTask(jvmExecutor, extensionModel.classpath, task, cache);
  }
}

Task _createTask(Sendable<JavaCommand, Object?> jvmExecutor, String classpath,
    ExtensionTask extensionTask, DartleCache cache) {
  final runCondition = _runCondition(extensionTask, cache);
  return Task(_taskAction(jvmExecutor, classpath, extensionTask),
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
    ExtensionTask extensionTask) {
  return (args) async {
    logger.fine(() => 'Requesting JBuild to run classpath=$classpath, '
        'className=${extensionTask.className}, '
        'method=${extensionTask.methodName}, '
        'args=$args');
    return await jvmExecutor.send(RunJava(
        extensionTask.name,
        classpath,
        extensionTask.className,
        extensionTask.methodName,
        args,
        extensionTask.constructorData));
  };
}

RunCondition _runCondition(ExtensionTask extensionTask, DartleCache cache) {
  if (extensionTask.inputs.isEmpty && extensionTask.outputs.isEmpty) {
    return const AlwaysRun();
  }
  return RunOnChanges(
      cache: cache,
      inputs: patternFileCollection(extensionTask.inputs),
      outputs: patternFileCollection(extensionTask.outputs));
}

Future<String> _toClasspath(
    String rootDir, JbConfigContainer extensionConfig) async {
  final absRootDir = p.canonicalize(rootDir);
  final artifact = p.join(absRootDir,
      extensionConfig.output.when(dir: (d) => '$d/', jar: (j) => j));
  final libsDir =
      Directory(p.join(absRootDir, extensionConfig.config.runtimeLibsDir));
  logger.fine(() => 'Extension artifact: $artifact, '
      'Extension libs dir: ${libsDir.path}');
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

/// Resolve a matching constructor for a given taskConfig, resolving the data
/// that should be used to invoke it.
///
/// The list of constructors contains the available Java constructors and must
/// not be empty (Java requires at least one constructor to exist).
/// Values in taskConfig are matched against each constructor parameter by name
/// and then are type checked.
///
/// A value type checks if its type is identical to a [ConfigType] parameter
/// or in case of [ConfigType.string], if it's `null`.
/// Parameters of type [ConfigType.jbuildLogger] must have value `null`,
/// and if not provided this method injects `null` in their place.
///
/// Parameters that have a jbName are resolved against JBuild's own
/// configuration.
List<Object?> resolveConstructorData(
    String name,
    Map<String, Object?>? taskConfig,
    List<JavaConstructor> constructors,
    JbConfiguration config) {
  if (taskConfig == null || taskConfig.isEmpty) {
    return _jbuildNoConfigConstructorData(name, constructors, config) ??
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
          reason: "Cannot create jb extension task '$name' because "
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
    if (value != null && !type.mayBeConfigured()) {
      failBuild(
          reason: "Cannot create jb extension task '$name' because "
              "its configuration is trying to provide a value for a "
              "non-configurable property '${entry.key}'! "
              "Please remove this property from configuration.");
    }
    if (type == ConfigType.jbuildLogger) {
      return null;
    } else if (type == ConfigType.jbConfig) {
      return config.toJson();
    } else if (type.mayBeConfigured() && value.isOfType(type)) {
      return value;
    }
    logger.warning("'Configuration of task '$name' did not type check. "
        "Value of '$value' is not of type $type!");
    failBuild(
        reason: "Cannot create jb extension task '$name' because "
            "the provided configuration for this task does not match any of "
            "the acceptable schemas. Please use one of the following schemas:\n"
            "${_constructorsHelp(constructors)}");
  }).toList(growable: false);
}

bool _keysMatch(JavaConstructor constructor, Map<String, Object?> taskConfig) {
  final mayBeMissingKeys = constructor.entries
      .where((e) => !e.value.mayBeConfigured())
      .map((e) => e.key)
      .toSet();
  final mandatoryConfigKeys =
      taskConfig.keys.where(mayBeMissingKeys.contains.not$).toSet();
  final mandatoryParamKeys =
      constructor.keys.where(mayBeMissingKeys.contains.not$).toSet();
  return const col.SetEquality()
      .equals(mandatoryConfigKeys, mandatoryParamKeys);
}

bool _requireNoConfiguration(List<JavaConstructor> constructors) {
  return constructors
      .every((c) => c.isEmpty || c.values.every((e) => !e.mayBeConfigured()));
}

String _constructorsHelp(List<JavaConstructor> constructors) {
  final builder = StringBuffer();
  var listedNoConfig = false;
  for (final (i, constructor) in constructors.indexed) {
    builder.writeln('  - option${i + 1}:');
    if (constructor.isEmpty ||
        constructor.values.every((t) => !t.mayBeConfigured())) {
      if (!listedNoConfig) {
        builder.writeln('    <no configuration>');
        listedNoConfig = true;
      }
    } else {
      constructor.forEach((fieldName, type) {
        if (type.mayBeConfigured()) {
          builder
            ..write('    ')
            ..write(fieldName)
            ..write(': ')
            ..writeln(type);
        }
      });
    }
  }
  return builder.toString();
}

/// Try to find a constructor that requires no configuration, considering
/// longer parameter lists first.
List<Object?>? _jbuildNoConfigConstructorData(
    String name, List<JavaConstructor> constructors, JbConfiguration config) {
  return constructors
      .where((c) => c.values.every((type) => !type.mayBeConfigured()))
      .sorted((a, b) => b.keys.length.compareTo(a.keys.length))
      .map((c) => c.values.map((type) {
            return (type == ConfigType.jbConfig) ? config.toJson() : null;
          }).toList(growable: false))
      .firstOrNull;
}

Set<String> _ensureStringSet(dynamic value) {
  List list = value.toList();
  final badValues = list.where((e) => e is! String).toList();
  if (badValues.isNotEmpty) {
    failBuild(reason: 'Non-string values found in Set<String>: $badValues');
  }
  return list.whereType<String>().toSet();
}

extension on Object? {
  bool isOfType(ConfigType type) {
    return switch (type) {
      ConfigType.string => this is String?,
      ConfigType.boolean => this is bool,
      ConfigType.int => this is int,
      ConfigType.float => this is double,
      ConfigType.listOfStrings ||
      ConfigType.arrayOfStrings =>
        vmap((self) => self is Iterable && self.every((i) => i is String)),
      ConfigType.jbuildLogger || ConfigType.jbConfig => false,
    };
  }
}
