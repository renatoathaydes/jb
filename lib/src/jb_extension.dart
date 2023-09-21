import 'dart:convert';
import 'dart:io';

import 'package:actors/actors.dart';
import 'package:archive/archive_io.dart';
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
    String? extensionProjectPath) async {
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
    return await loadConfig(File(jbFile));
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

  final tasks = await _createTasks(
          extensionModel, extensionConfig, jvmExecutor, dir, files)
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
    JbFiles files) async* {
  final cache = DartleCache(p.join(dir, files.jbCache));
  final classpath = await _toClasspath(dir, extensionConfig);
  for (final task in extensionModel.extensionTasks) {
    yield _createTask(jvmExecutor, classpath, task, dir, cache);
  }
}

Task _createTask(Sendable<JavaCommand, Object?> jvmExecutor, String classpath,
    ExtensionTask extensionTask, String path, DartleCache cache) {
  final runCondition = _runCondition(extensionTask, path, cache);
  return Task(_taskAction(jvmExecutor, classpath, extensionTask, path),
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
    String path) {
  return (args) async {
    logger.fine(() => 'Requesting JBuild to run classpath=$classpath, '
        'className=${extensionTask.className}, '
        'method=${extensionTask.methodName}, '
        'args=$args');
    return await withCurrentDirectory(
        path,
        () async => await jvmExecutor.send(RunJava(classpath,
            extensionTask.className, extensionTask.methodName, args)));
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
