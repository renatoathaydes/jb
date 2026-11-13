import 'dart:io';

import 'package:actors/actors.dart' show Sendable;
import 'package:dartle/dartle.dart';
import 'package:dartle/dartle_cache.dart' show DartleCache;
import 'package:path/path.dart' as p;

import '../config.dart';
import '../config_import.dart';
import '../dependencies/checksums.dart';
import '../dependencies/deps_cache.dart';
import '../jb_actors.dart';
import '../jb_files.dart';
import '../jvm_executor.dart';
import '../options.dart';
import '../utils.dart';
import 'dependency_extension.dart';
import 'jb_extension.dart';

/// Name of the directory, inside `.jb-cache`, of the extension pipeline's [DartleCache].
const _pipelineCacheDir = 'jb-extensions';

const writeExtensionChecksumsTaskName = 'writeExtensionChecksums';

sealed class _ExtensionSource;

final class _LocalDirectoryExtension(final Directory dir)
    extends _ExtensionSource;

final class _DependencyExtension(final String coordinates)
    extends _ExtensionSource;

/// Load all jb extensions of the project, from configuration if given, or
/// from the default location otherwise.
///
/// Extensions define tasks which the project's build may depend on, so they
/// must be loaded before the build starts. Loading is done by an internal Dartle
/// run, whose tasks download, check and load each extension.
///
/// The run uses its own [DartleCache] because Dartle deletes the cache entries
/// of the tasks it does not know about, which would be all the project's tasks.
Future<List<ExtensionProject>> loadExtensionProjects(
  JbFiles files,
  JbActors actors,
  Options options,
  JbConfigWithImports cwi,
) async {
  final sources = _extensionSources(cwi.config.extensionProjects)
      .toList(growable: false);
  if (sources.isEmpty) {
    // extensions may have been removed from the configuration
    if (await files.extensionDependenciesChecksumFile.exists()) {
      await updateExtensionChecksums(files, keep: const {});
    }
    return const [];
  }

  final context = ExtensionPipelineContext(
    files,
    actors,
    cwi,
    options,
    DartleCache(p.join(JbFiles.jbCache, _pipelineCacheDir)),
  );

  final tasks = <Task>{};
  final loadTaskNames = <String>[];
  final invocation = <String>[];
  final resolvedFiles = <String>[];
  final downloadTaskNames = <String>{};
  for (final source in sources) {
    final extension = switch (source) {
      _LocalDirectoryExtension(dir: var dir) => //
      await createLocalExtensionTasks(dir, context),
      _DependencyExtension(coordinates: var coord) => //
      createDependencyExtensionTasks(coord, context),
    };
    if (loadTaskNames.contains(extension.loadTaskName)) {
      failBuild(
        reason:
            'jb extension project declared more than once, or two extension '
            'projects with the same name: ${extension.loadTaskName}',
      );
    }
    tasks.addAll(extension.tasks);
    loadTaskNames.add(extension.loadTaskName);
    invocation.add(extension.loadTaskName);
    if (extension.resolvedDependenciesFile case var file?) {
      resolvedFiles.add(file);
    }
    if (extension.downloadTaskName case var task?) {
      downloadTaskNames.add(task);
    }
  }

  // Removes the checksums of extensions no longer configured. It is only needed
  // when there are dependency extensions, or a checksums file to clean up.
  if (resolvedFiles.isNotEmpty ||
      await files.extensionDependenciesChecksumFile.exists()) {
    final writeChecksums = Task(
      (_) => _pruneExtensionChecksums(context, resolvedFiles),
      name: writeExtensionChecksumsTaskName,
      runCondition: const AlwaysRun(),
      dependsOn: downloadTaskNames,
      description:
          'Writes the checksums of the dependency extensions to '
          '${JbFiles.extensionDependenciesChecksum}.',
    );
    tasks.add(writeChecksums);
    invocation.add(writeChecksums.name);
  }

  // extension loading changes the working directory, so tasks must run in sequence
  await runBasic(
    tasks,
    const {},
    options.copy(tasksInvocation: invocation, parallelizeTasks: false),
    context.cache,
  );

  return [
    for (final name in loadTaskNames)
      context.loaded[name] ??
          (throw StateError('Extension was not loaded by task $name')),
  ];
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
    // assume it's a dependency, so it must be of the form group:artifact<:version>
    if (!path.contains(':')) {
      failBuild(
        reason:
            "Invalid extension declaration: '$path'. "
            "Must be either a local path starting with '.', or a dependency "
            "of the form group:artifact<:version>.",
      );
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

/// The tasks which load one extension.
final class ExtensionTasks {
  final Set<Task> tasks;

  /// Name of the task which stores the loaded [ExtensionProject] in
  /// [ExtensionPipelineContext.loaded].
  final String loadTaskName;

  /// Name of the task which downloads the extension's dependencies, if any.
  final String? downloadTaskName;

  /// File where the extension's resolved dependency tree is stored, if any.
  final String? resolvedDependenciesFile;

  const ExtensionTasks({
    required this.tasks,
    required this.loadTaskName,
    this.downloadTaskName,
    this.resolvedDependenciesFile,
  });
}

/// State shared by the tasks of the extension pipeline.
final class ExtensionPipelineContext {
  final JbFiles files;
  final JbActors actors;
  final JbConfigWithImports cwi;
  final Options options;

  /// Cache of the extension pipeline, separate from the project's cache.
  final DartleCache cache;

  /// Loaded extensions, by the name of the task that loads each one.
  final Map<String, ExtensionProject> loaded = {};

  ExtensionPipelineContext(
    this.files,
    this.actors,
    this.cwi,
    this.options,
    this.cache,
  );

  /// The project's jb configuration.
  JbConfiguration get config => cwi.config;

  /// Sender for JBuild commands.
  Sendable<JavaCommand, Object?> get jBuildSender =>
      actors.jvmExecutor.takingJavaCommands();

  /// JBuild arguments for the project's configuration.
  List<String> get jBuildPreArgs => config.preArgs(Directory.current.path);

  /// The file where the compilation path of a local extension is stored.
  String compilationPathFile(String absRootDir) => p.join(
    cache.rootDir,
    'compilation-paths',
    absRootDir.asEncodedPath(),
    'compilation-path.json',
  );
}

/// Runs only while [path] does not exist.
///
/// Used for extension artifacts, which are never modified after being created,
/// so their contents are not hashed.
final class MissingPathCondition with RunCondition {
  final String path;

  const MissingPathCondition(this.path);

  @override
  bool shouldRun(TaskInvocation invocation) {
    return FileSystemEntity.typeSync(path) == FileSystemEntityType.notFound;
  }

  @override
  void postRun(TaskResult result) {}
}

/// Adds [add] to the extension checksums file and, if [keep] is given, removes
/// all other checksums from it.
Future<void> updateExtensionChecksums(
  JbFiles files, {
  Map<String, String> add = const {},
  Set<String>? keep,
}) async {
  final file = files.extensionDependenciesChecksumFile;
  final merged = {...await readChecksums(file), ...add};
  final result = keep == null
      ? merged
      : {
          for (final entry in merged.entries)
            if (keep.contains(entry.key)) entry.key: entry.value,
        };
  await writeChecksums(file, result);
}

Future<void> _pruneExtensionChecksums(
  ExtensionPipelineContext context,
  List<String> resolvedFiles,
) async {
  final artifacts = <String>{};
  for (final file in resolvedFiles) {
    final resolved = await context.actors.depsCache.send(GetDeps(file));
    artifacts.addAll(
      resolved.dependencies
          .where((dep) => dep.spec.path == null)
          .map((dep) => dep.artifact),
    );
  }
  await updateExtensionChecksums(context.files, keep: artifacts);
}
