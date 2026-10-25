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

Future<List<ExtensionTask>> loadExtensionTasksFromCache(
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
    return const [];
  }
  logger.fine(() => 'Loading extension tasks data from cache');
  final extras =
      jsonDecode(await cacheFile.readAsString()) as Map<String, dynamic>;
  return taskConfigs
      .map((taskConfig) {
        final extra = extras[taskConfig.name];
        if (extra == null) {
          failBuild(
            reason:
                'Cannot find extension task configuration in '
                'cache ${cacheFile.path}: ${taskConfig.name}',
          );
        }

        final taskName = '${taskConfig.name}#$projectName';
        final constructorData = resolveTaskConstructorData(
          config,
          taskConfig,
          taskName,
        );

        return ExtensionTask(
          basicConfig: taskConfig,
          constructorData: constructorData,
          extraConfig: ExtensionTaskExtra.fromJson(extra),
          qualifiedName: taskName,
        );
      })
      .toList(growable: false);
}

Future<void> cacheExtensionTasks(
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
  return p.join(
    cache.rootDir,
    'jb-extensions',
    dir.asEncodedPath(),
    modelJsonFile,
  );
}
