import 'dart:convert' show base64Url, jsonDecode, jsonEncode, utf8;
import 'dart:io';

import 'package:actors/actors.dart' show Sendable;
import 'package:archive/archive_io.dart';
import 'package:collection/collection.dart';
import 'package:conveniently/conveniently.dart';
import 'package:crypto/crypto.dart' show sha1;
import 'package:dartle/dartle.dart' show elapsedTime, profile;
import 'package:dartle/dartle_cache.dart';
import 'package:jb/src/extension/constructors.dart';
import 'package:path/path.dart' as p;

import '../config.dart';
import '../jb_files.dart';
import '../jvm_executor.dart';
import '../utils.dart';

/// The name of the file inside the Dartle Cache where the full extension project
/// data model is cached.
final modelJsonFile = 'jb-model.json';

final class _JbExtensionConfig {
  final String path;
  final String yaml;
  final String scheme;

  Uri get yamlUri => Uri(scheme: scheme, path: path);

  const _JbExtensionConfig({
    required this.path,
    required this.yaml,
    required this.scheme,
  });
}

sealed class _CacheTask {
  const _CacheTask();
}

final class _CacheMissTask extends _CacheTask {
  final BasicExtensionTask basicExtensionTask;

  const _CacheMissTask(this.basicExtensionTask);
}

final class _CachedTask extends _CacheTask {
  final ExtensionTask extensionTask;

  const _CachedTask(this.extensionTask);
}

Future<JbExtensionModel> createJbExtensionModel(
  JbConfigContainer configContainer,
  String rootDir,
  String classpath,
  DartleCache cache,
  Sendable<JavaCommand, Object?> jvmExecutor,
) async {
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

  final stopWatch = Stopwatch()..start();
  List<ExtensionTask>? extensionTasks;

  // if anything in the output changed, we need to reload the extension config
  // fully as it's not possible to know whether it's necessary.
  // Otherwise, try to load tasks from cache if the cache exists.
  if (!await cache.hasChanged(out)) {
    final cacheTasks = await _loadExtensionTasksFromCache(
      config,
      taskConfigs,
      cache,
      rootDir,
    );
    if (cacheTasks != null) {
      final cacheMisses = cacheTasks.groupFoldBy<bool, int>(
        (t) => t is _CacheMissTask,
        (int? prev, _) => (prev ?? 0) + 1,
      );
      logger.fine(
        () =>
            'Loaded ${cacheMisses[false] ?? 0} task(s) from the cache, '
            '${cacheMisses[true] ?? 0} cache misses',
      );

      extensionTasks = await Stream.fromIterable(cacheTasks)
          .asyncMap(
            (task) => switch (task) {
              _CachedTask(extensionTask: final t) => Future.value(t),
              _CacheMissTask(basicExtensionTask: final t) => _loadExtensionTask(
                config,
                classpath,
                t,
                jvmExecutor,
              ),
            },
          )
          .toList();

      // only cache if there was at least one cache miss
      if ((cacheMisses[true] ?? 0) > 0) {
        await _cacheExtensionTasks(cache, rootDir, extensionTasks);
      }
    }
  }

  if (extensionTasks == null) {
    extensionTasks = await _loadExtensionTasks(
      config,
      classpath,
      taskConfigs,
      jvmExecutor,
    );
    await _cacheExtensionTasks(cache, rootDir, extensionTasks);
  }

  logger.log(
    profile,
    () => 'Loaded extension tasks in ${elapsedTime(stopWatch)}',
  );

  return JbExtensionModel(config, classpath, extensionTasks);
}

void verifyAllExtrasMatchExtensionTasks(
  JbConfiguration config,
  List<ExtensionTask> extensionTasks,
) {
  final extras = config.extras.keys.toSet();
  final taskNames = extensionTasks.map((t) => t.name).toSet();
  final badExtras = extras.difference(taskNames);
  if (badExtras.isNotEmpty) {
    failBuild(
      reason:
          'The following keys are not jb configuration entries, '
          'nor custom tasks configurations: '
          '${badExtras.map((s) => s.quote()).join(', ')}. '
          'Remove them from your jb file or add the required extensions.',
    );
  }
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

Future<List<ExtensionTask>> _loadExtensionTasks(
  JbConfiguration config,
  String classpath,
  Iterable<BasicExtensionTask> taskConfigs,
  Sendable<JavaCommand, Object?> jvmExecutor,
) async {
  logger.fine(() => 'Loading extension tasks data from Java extension');
  final futureTasks = taskConfigs.map(
    (taskConfig) =>
        _loadExtensionTask(config, classpath, taskConfig, jvmExecutor),
  );
  // wait for all Futures to complete now
  return await Future.wait(futureTasks);
}

Future<ExtensionTask> _loadExtensionTask(
  JbConfiguration config,
  String classpath,
  BasicExtensionTask taskConfig,
  Sendable<JavaCommand, Object?> jvmExecutor,
) async {
  final constructorData = resolveTaskConstructorData(config, taskConfig);
  final summary = await jvmExecutor.send(
    RunJava(
      '_getSummary_${taskConfig.name}',
      classpath,
      taskConfig.className,
      'getSummary',
      const [],
      constructorData,
    ),
  );
  if (summary is List && summary.length == 4) {
    final [inputs, outputs, dependsOn, dependents] = summary;
    return ExtensionTask(
      basicConfig: taskConfig,
      constructorData: constructorData,
      extraConfig: ExtensionTaskExtra(
        // TODO the config may change even if the jb file does not,
        // so we should check the actual JbConfiguration object if possible.
        inputs: _addJbFileIfRequiringConfig(
          taskConfig.constructors,
          _ensureStrings(inputs),
        ),
        outputs: _ensureStrings(outputs),
        dependsOn: _ensureStrings(dependsOn),
        dependents: _ensureStrings(dependents),
      ),
    );
  } else {
    failBuild(
      reason:
          'getSummary should return list with 4 elements, '
          'but got: $summary',
    );
  }
}

List<String> _addJbFileIfRequiringConfig(
  List<Map<String, ConfigType>> constructors,
  List<String> inputs,
) {
  // if any constructor requires jbConfig, we need to add the jb config file
  // to the inputs if it's not already there.
  if (constructors.any((c) => c.values.any((v) => v == ConfigType.jbConfig)) &&
      !inputs.contains(yamlJbFile) &&
      !inputs.contains(jsonJbFile)) {
    return inputs.followedBy([yamlJbFile, jsonJbFile]).toList(growable: false);
  }
  return inputs;
}

Future<List<_CacheTask>?> _loadExtensionTasksFromCache(
  JbConfiguration config,
  Iterable<BasicExtensionTask> taskConfigs,
  DartleCache cache,
  String rootDir,
) async {
  final cacheFile = File(_modelCacheLocation(cache, rootDir));
  if (!await cacheFile.exists()) {
    logger.fine(
      () =>
          'Cannot load extensions tasks from cache '
          'as cached model file does not exist: ${cacheFile.path}',
    );
    return null;
  }
  logger.fine(() => 'Loading extension tasks data from cache');
  final extras =
      jsonDecode(await cacheFile.readAsString()) as Map<String, dynamic>;
  return taskConfigs
      .map((taskConfig) {
        final extra = extras[taskConfig.name];
        if (extra == null) {
          logger.fine(
            () =>
                'Task with name "${taskConfig.name}" was not found in serialized extension task cache: $extras',
          );
          return _CacheMissTask(taskConfig);
        }

        final constructorData = resolveTaskConstructorData(config, taskConfig);

        return _CachedTask(
          ExtensionTask(
            basicConfig: taskConfig,
            constructorData: constructorData,
            extraConfig: ExtensionTaskExtra.fromJson(extra),
          ),
        );
      })
      .nonNulls
      .toList(growable: false);
}

Future<void> _cacheExtensionTasks(
  DartleCache cache,
  String rootDir,
  List<ExtensionTask> tasks,
) async {
  logger.fine(() => 'Caching jb extension tasks for project $rootDir');
  final cacheFile = File(_modelCacheLocation(cache, rootDir));
  await cacheFile.parent.create(recursive: true);
  final toSerialize = tasks.asMap().map(
    (_, task) => MapEntry(task.name, task.extraConfig),
  );
  await cacheFile.writeAsString(jsonEncode(toSerialize));
}

String _modelCacheLocation(DartleCache cache, String dir) {
  final encodedName = base64Url.encode(sha1.convert(dir.codeUnits).bytes);
  return p.join(cache.rootDir, 'jb-extensions', encodedName, modelJsonFile);
}

List<String> _ensureStrings(dynamic value) {
  List list = value.toList();
  final badValues = list.where((e) => e is! String).toList();
  if (badValues.isNotEmpty) {
    failBuild(reason: 'Non-string values found in Set<String>: $badValues');
  }
  return list.whereType<String>().toList();
}
