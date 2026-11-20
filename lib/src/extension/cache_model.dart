import 'dart:convert' show jsonDecode, jsonEncode;
import 'dart:io';

import 'package:dartle/dartle_cache.dart';
import 'package:path/path.dart' as p;

import '../config.dart';
import '../utils.dart';
import 'constructors.dart';

/// The name of the file inside the Dartle Cache where the full extension project
/// data model is cached.
final modelJsonFile = 'jb-model.json';

/// Loads the extension tasks from the cached model, without starting the JVM.
///
/// Returns `null` if the cached model does not exist, or if it was cached for
/// different constructor data (i.e. the jb configuration changed), so the caller
/// must load the model again.
Future<List<ExtensionTask>?> loadExtensionTasksFromCache(
  JbConfiguration config,
  Iterable<BasicExtensionTask> taskConfigs,
  DartleCache cache,
  String rootDir,
  String projectName,
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
  final cached =
      jsonDecode(await cacheFile.readAsString()) as Map<String, dynamic>;
  final tasks = <ExtensionTask>[];
  for (final taskConfig in taskConfigs) {
    final taskName = '${taskConfig.name}#$projectName';
    final constructorData = resolveTaskConstructorData(
      config,
      taskConfig,
      taskName,
    );
    final entry = cached[taskConfig.name];
    if (entry is! Map<String, dynamic> ||
        jsonEncode(entry[_constructorDataKey]) != jsonEncode(constructorData)) {
      logger.fine(
        () => 'Cached extension model is outdated for task: $taskName',
      );
      return null;
    }
    tasks.add(
      ExtensionTask(
        basicConfig: taskConfig,
        constructorData: constructorData,
        extraConfig: ExtensionTaskExtra.fromJson(entry[_extraKey]),
        qualifiedName: taskName,
      ),
    );
  }
  return tasks;
}

Future<void> cacheExtensionTasks(
  DartleCache cache,
  String rootDir,
  List<ExtensionTask> tasks,
) async {
  logger.fine(() => 'Caching jb extension tasks for project $rootDir');
  final cacheFile = File(_modelCacheLocation(cache, rootDir));
  await cacheFile.parent.create(recursive: true);
  // the constructor data is part of the model, as the extension's task
  // summary (inputs, outputs...) depends on it
  final toSerialize = {
    for (final task in tasks)
      task.name: {
        _constructorDataKey: task.constructorData,
        _extraKey: task.extraConfig,
      },
  };
  await cacheFile.writeAsString(jsonEncode(toSerialize));
}

const _constructorDataKey = 'constructorData';
const _extraKey = 'extra';

String _modelCacheLocation(DartleCache cache, String dir) {
  return p.join(cache.rootDir, dir.asEncodedPath(), modelJsonFile);
}
