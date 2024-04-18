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
    JbConfiguration config) async {
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

  final extensionModel = await loadJbExtensionModel(
      jbExtensionConfig.yaml, jbExtensionConfig.yamlUri);

  final tasks = await _createTasks(
          extensionModel, configContainer, jvmExecutor, dir, files, config)
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
    final archiveFile = buffer.findFile(extensionEntry).orThrow(() => failBuild(
        reason: 'jb extension jar at $jarPath '
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
    failBuild(
        reason: 'Extension project is missing dependency on jbuild-api.\n'
            "To fix that, add a dependency on '$jbApi:<version>'");
  }
}

Stream<Task> _createTasks(
    JbExtensionModel extensionModel,
    JbConfigContainer extensionConfig,
    Sendable<JavaCommand, Object?> jvmExecutor,
    String extensionDir,
    JbFiles files,
    JbConfiguration config) async* {
  final cache = DartleCache(p.join(extensionDir, files.jbCache));
  final classpath = await _toClasspath(extensionDir, extensionConfig);
  for (final task in extensionModel.extensionTasks) {
    final name = task.name;
    final taskConfig = config.extras[name];
    if (taskConfig is! Map<String, Object>?) {
      failBuild(
          reason: "Cannot create jb extension task '$name' because the "
              "provided configuration is not an object: $taskConfig");
    }
    final constructorData =
        resolveConstructorData(name, taskConfig, task.constructors, config);
    yield _createTask(jvmExecutor, classpath, task, cache, constructorData);
  }
}

Task _createTask(
    Sendable<JavaCommand, Object?> jvmExecutor,
    String classpath,
    ExtensionTask extensionTask,
    DartleCache cache,
    List<Object?> constructorData) {
  final runCondition = _runCondition(extensionTask, cache);
  return Task(
      _taskAction(jvmExecutor, classpath, extensionTask, constructorData),
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
    List<Object?> constructorData) {
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
        constructorData));
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
    return _jbuildConstructorData(name, constructors, config) ??
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
  final configMap = config.toJson();
  return keyMatch.entries.map((entry) {
    final (jbName, type) = entry.value;
    final value = taskConfig[entry.key];
    if (jbName != null) {
      if (value != null) {
        failBuild(
            reason: "Cannot create jb extension task '$name' because "
                "its configuration is trying to provide jb property '$jbName'! "
                "Please remove this property from configuration.");
      }
      return _resolveJbConfig(configMap, jbName, type, name);
    }
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

bool _keysMatch(JavaConstructor constructor, Map<String, Object?> taskConfig) {
  // allow parameters of type JBuildLogger and with jbName to be missing
  final mayBeMissingKeys = constructor.entries
      .where((e) {
        final (jbName, type) = e.value;
        // will type check later
        if (jbName != null) return true;
        return type == ConfigType.jbuildLogger;
      })
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
  return constructors.every((c) =>
      c.isEmpty || c.values.every((e) => e.$2 == ConfigType.jbuildLogger));
}

String _constructorsHelp(List<JavaConstructor> constructors) {
  final builder = StringBuffer();
  for (final (i, constructor) in constructors.indexed) {
    builder.writeln('  - option${i + 1}:');
    if (constructor.isEmpty) {
      builder.writeln('    <no configuration>');
    } else {
      constructor.forEach((fieldName, entry) {
        final (_, type) = entry;
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

List<Object?>? _jbuildConstructorData(
    String name, List<JavaConstructor> constructors, JbConfiguration config) {
  final configMap = config.toJson();
  return constructors
      .where((c) => c.values.every((v) {
            final (jbName, type) = v;
            return jbName != null || type == ConfigType.jbuildLogger;
          }))
      .sorted((a, b) => b.keys.length.compareTo(a.keys.length))
      .map((c) => c.values.map((v) {
            final (jbName, type) = v;
            return (jbName != null)
                ? _resolveJbConfig(configMap, jbName, type, name)
                : null;
          }).toList(growable: false))
      .firstOrNull;
}

Object? _resolveJbConfig(
    Map<String, Object?> config, String jbName, ConfigType type, String name) {
  final value = config[jbName];
  if (type.isInstance(value)) return value;
  final details = (!config.containsKey(jbName))
      ? 'does not exist! Please remove this argument from the '
          "task's constructor or use another name."
      : "is not of type $type! Please modify the task's "
          "constructor property to take the proper type.";
  failBuild(
      reason: "Cannot create jb extension task '$name' because "
          "its configuration is invalid: jb property '$jbName' "
          "$details");
}

extension on Object? {
  Result<bool> isOfType(ConfigType type) {
    final result = switch (type) {
      ConfigType.string => this is String?,
      ConfigType.boolean => this is bool,
      ConfigType.int => this is int,
      ConfigType.float => this is double,
      ConfigType.listOfStrings ||
      ConfigType.arrayOfStrings =>
        vmap((self) => self is Iterable && self.every((i) => i is String)),
      ConfigType.jbuildLogger => this == null ? true : null,
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
