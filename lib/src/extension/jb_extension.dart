import 'dart:convert' show utf8;
import 'dart:io';

import 'package:actors/actors.dart' show Sendable;
import 'package:actors/actors.dart';
import 'package:archive/archive_io.dart';
import 'package:conveniently/conveniently.dart';
import 'package:dartle/dartle.dart'
    show Options, profile, elapsedTime, failBuild, dir, file;
import 'package:dartle/dartle_cache.dart' show DartleCache;
import 'package:isolate_current_directory/isolate_current_directory.dart';
import 'package:path/path.dart' as p;

import '../config.dart';
import '../config_import.dart';
import '../config_source.dart';
import '../jb_actors.dart';
import '../jb_files.dart';
import '../jvm_executor.dart';
import '../options.dart';
import '../runner.dart';
import '../tasks.dart';
import '../utils.dart';
import 'cache_model.dart';
import 'extension_tasks.dart';

final class ExtensionProject(
  final String name,
  final String rootDir,
  final String classpath,
  final JbExtensionModel model,
);

sealed class _ExtensionSource;

final class _LocalDirectoryExtension(final Directory dir)
    extends _ExtensionSource;

final class _DependencyExtension(final String coordinates)
    extends _ExtensionSource;

final class _JbExtensionConfig({
  required final String path,
  required final String yaml,
  required final String scheme,
}) {
  Uri get yamlUri => Uri(scheme: scheme, path: path);
}

/// Load all extension projects from configuration, if given,
/// or from the default location otherwise.
Stream<ExtensionProject> loadExtensionProjects(
  JbFiles files,
  JbActors actors,
  Options options,
  JbConfigWithImports cwi,
  DartleCache cache,
) async* {
  for (final extension in _extensionSources(cwi.config.extensionProjects)) {
    yield switch (extension) {
      _LocalDirectoryExtension(dir: var dir) => //
      await _loadExtensionFromDir(dir, files, actors, options, cwi, cache),
      _DependencyExtension(coordinates: var coord) => //
      await _loadExtensionFromDep(coord, files, actors, options, cwi, cache),
    };
  }
}

Future<JbExtensionModel> createJbExtensionModel(
  JbConfigContainer configContainer,
  JbConfiguration hostConfig,
  String projectName,
  String rootDir,
  String classpath,
  DartleCache cache,
  Sendable<JavaCommand, Object?> jvmExecutor, {
  required bool extensionUpToDate,
}) async {
  final out = configContainer.output.when(dir: dir, jar: file);
  final jbExtensionConfig = await configContainer.output.when(
    dir: (d) async => await _jbExtensionFromDir(rootDir, d),
    jar: (j) async => await _jbExtensionFromJar(rootDir, j),
  );
  final config = configContainer.config;
  final taskConfigs = await loadExtensionTaskConfigs(
    config,
    jbExtensionConfig.yaml,
    jbExtensionConfig.yamlUri,
  );

  List<ExtensionTask>? extensionTasks;

  if (extensionUpToDate && !await cache.hasChanged(out)) {
    extensionTasks = await loadExtensionTasksFromCache(
      hostConfig,
      taskConfigs,
      cache,
      rootDir,
      projectName,
    );
  }

  if (extensionTasks == null) {
    extensionTasks = await loadExtensionTasks(
      hostConfig,
      classpath,
      taskConfigs,
      jvmExecutor,
      projectName,
    );
    await cacheExtensionTasks(cache, rootDir, extensionTasks);
  }

  return JbExtensionModel(config, classpath, extensionTasks);
}

Future<_JbExtensionConfig> _jbExtensionFromJar(
  String rootDir,
  String jarPath,
) async {
  final path = p.join(rootDir, jarPath);
  logger.fine(() => 'Loading jb extension from jar: $path');
  final stream = InputFileStream(path);
  try {
    final buffer = ZipDecoder().decodeStream(stream);
    final extensionEntry = 'META-INF/jb/$jbExtension.yaml';
    final archiveFile = buffer
        .findFile(extensionEntry)
        .orThrow(
          () => failBuild(
            reason:
                'jb extension jar at $jarPath '
                'is missing metadata file: $extensionEntry',
          ),
        );
    final content = archiveFile.content as List<int>;
    return _JbExtensionConfig(
      path: '$path!$extensionEntry',
      yaml: utf8.decode(content),
      scheme: 'jar',
    );
  } finally {
    await stream.close();
  }
}

Future<_JbExtensionConfig> _jbExtensionFromDir(
  String rootDir,
  String outputDir,
) async {
  logger.fine(
    () => 'Loading jb extension from directory: ${p.join(rootDir, outputDir)}',
  );
  final yamlFile = File(
    p.join(rootDir, outputDir, 'META-INF', 'jb', '$jbExtension.yaml'),
  );
  return _JbExtensionConfig(
    path: yamlFile.path,
    yaml: await yamlFile.readAsString(),
    scheme: 'file',
  );
}

Iterable<_ExtensionSource> _extensionSources(
  List<String> extensionProjects,
) sync* {
  _ExtensionSource extensionFromPath(String path) {
    if (path.startsWith('.')) {
      final dir = Directory(path);
      if (!dir.existsSync()) {
        failBuild(reason: "Extension project does not exist at path '$path'");
      }
      return _LocalDirectoryExtension(dir);
    }
    return _DependencyExtension(path);
  }

  yield* extensionProjects.map(extensionFromPath);

  // if the default extension is not declared explicitly, only add it if it exists
  if (!extensionProjects.contains(jbExtension)) {
    final dir = Directory(jbExtension);
    if (dir.existsSync()) {
      logger.fine(
        () => "Including the default jb-extension project at $jbExtension",
      );
      yield _LocalDirectoryExtension(dir);
    }
  }
}

Future<ExtensionProject> _loadExtensionFromDep(
  String coordinates,
  JbFiles files,
  JbActors actors,
  Options options,
  JbConfigWithImports cwi,
  DartleCache cache,
) async {
  // TODO
  throw UnimplementedError('_loadExtensionFromDep');
}

Future<ExtensionProject> _loadExtensionFromDir(
  Directory projectDir,
  JbFiles files,
  JbActors actors,
  Options options,
  JbConfigWithImports cwi,
  DartleCache cache,
) async {
  final stopWatch = Stopwatch()..start();

  final rootDir = projectDir.path;
  logger.info(
    () => '========= Loading jb extension project: $rootDir =========',
  );

  final extensionCwi = await withCurrentDirectory(rootDir, () async {
    return await defaultJbConfigSource.load();
  }, onError: changedDirectoryOnError(rootDir));
  _verifyJBuildApiDependency(extensionCwi.config);

  final configContainer = await withCurrentDirectory(
    rootDir,
    onError: changedDirectoryOnError(rootDir),
    () => JbConfigContainer(extensionCwi),
  );
  final runner = JbRunner(files, extensionCwi, actors);

  // run the extension project's compile task so that its
  // jb tasks can be executed later
  final extensionProjectTasks = await withCurrentDirectory(
    rootDir,
    onError: changedDirectoryOnError(rootDir),
    () async => await runner.run(
      options.copy(
        tasksInvocation: const [compileTaskName, installRuntimeDepsTaskName],
      ),
      isRoot: false,
    ),
  );

  logger.log(
    profile,
    () =>
        "Extension project '$rootDir' initialized in ${elapsedTime(stopWatch)}",
  );
  stopWatch.reset();

  final absRootDir = p.canonicalize(rootDir);
  final classpath = await _toClasspath(rootDir, configContainer);
  final name = configContainer.config.module ?? rootDir;

  final extensionModel = await createJbExtensionModel(
    configContainer,
    cwi.config,
    name,
    rootDir,
    classpath,
    cache,
    actors.jvmExecutor.takingJavaCommands(),
    extensionUpToDate: extensionProjectTasks.every((t) => t.mustRunCount == 0),
  );

  _warnOnUnexpectedConfig(extensionModel, cwi.config.extras);

  logger.log(
    profile,
    () =>
        "Extension project '$rootDir' model loaded in ${elapsedTime(stopWatch)}",
  );
  logger.info('========= jb extension loaded =========');

  return ExtensionProject(name, absRootDir, classpath, extensionModel);
}

void _verifyJBuildApiDependency(JbConfiguration config) {
  final hasJbApiDep = config.dependencies.keys.any(
    (dep) => dep.startsWith('$jbApi:'),
  );
  if (!hasJbApiDep) {
    failBuild(
      reason:
          'Extension project is missing dependency on jbuild-api.\n'
          "To fix that, add a dependency on '$jbApi:<version>'",
    );
  }
}

void _warnOnUnexpectedConfig(
  JbExtensionModel extensionModel,
  Map<String, Object?> extras,
) {
  // extension project's task names including also qualified names
  final taskNames = extensionModel.extensionTasks
      .expand((t) => [t.name, t.qualifiedName])
      .toSet();
  final unknownKeys = extras.keys.where(taskNames.contains.not$);
  if (unknownKeys.isNotEmpty) {
    logger.warning(
      () =>
          'jb configuration keys do not match any known parameter or extension task: $unknownKeys',
    );
  }
}

class JbExtensionModelBuilder {
  final Sendable<JavaCommand, Object?> jvmExecutor;

  const JbExtensionModelBuilder(this.jvmExecutor);
}

Future<String> _toClasspath(
  String absRootDir,
  JbConfigContainer extensionConfig,
) async {
  final artifact = p.join(
    absRootDir,
    extensionConfig.output.when(dir: (d) => d.asDirPath(), jar: (j) => j),
  );
  final libsDir = Directory(
    p.join(absRootDir, extensionConfig.config.runtimeLibsDir.asOsPath()),
  );
  logger.fine(
    () =>
        'Extension artifact: $artifact, '
        'Extension libs dir: ${libsDir.path}',
  );
  if (await libsDir.exists()) {
    final libs = await libsDir
        .list()
        .where((f) => f is File && f.path.endsWith('.jar'))
        .map((f) => f.path)
        .toList();
    return libs.followedBy([artifact]).join(classpathSeparator);
  }
  return artifact;
}
