import 'dart:io';

import 'package:actors/actors.dart' show Sendable;
import 'package:dartle/dartle.dart';
import 'package:dartle/dartle_cache.dart';
import 'package:jb/jb.dart';
import 'package:jb/src/patterns.dart';

import '../jvm_executor.dart';
import '../utils.dart';
import '../xml_rpc_structs.dart' show ChangeSetToMap;
import 'constructors.dart';

Future<List<ExtensionTask>> loadExtensionTasks(
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

/// Create Dartle [Task]s for the given [ExtensionProject].
List<Task> createExtensionTasks(
  ExtensionProject project,
  Sendable<JavaCommand, Object?> jvmExecutor,
  DartleCache cache,
) {
  return project.model.extensionTasks
      .map((extensionTask) {
        return _createTask(
          project.name,
          jvmExecutor,
          project.classpath,
          extensionTask,
          project.rootDir,
          cache,
        );
      })
      .toList(growable: false);
}

void verifyExtensionTasks(
  JbConfiguration config,
  List<ExtensionProject> extensionProjects,
) {
  final extras = {...config.extras.keys};
  final Set<String> taskNames = {};
  for (final project in extensionProjects) {
    final projectName = project.name;
    for (final extensionTask in project.model.extensionTasks) {
      final taskName = "${extensionTask.name}:$projectName";
      final wasAdded = taskNames.add(taskName);
      if (!wasAdded) {
        failBuild(reason: "Duplicate extension task name detected: $taskName");
      }
      final wasRemoved = extras.remove(taskName);
      if (wasRemoved) {
        logger.fine(() => 'Configuration found for task: $taskName');
      } else {
        logger.fine(() => 'No configuration found for task: $taskName');
      }
    }
  }

  if (extras.isNotEmpty) {
    failBuild(
      reason:
          'The following keys are not jb configuration entries, '
          'nor custom tasks configurations: '
          '${extras.map((s) => s.quote()).join(', ')}. '
          'Remove them from your jb file or add the required extensions.',
    );
  }
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

Task _createTask(
  String projectName,
  Sendable<JavaCommand, Object?> jvmExecutor,
  String classpath,
  ExtensionTask extensionTask,
  String absRootDir,
  DartleCache cache,
) {
  final runCondition = _runCondition(extensionTask, cache);
  return Task(
    _taskAction(jvmExecutor, classpath, absRootDir, extensionTask),
    name: "${extensionTask.name}:$projectName",
    argsValidator: const AcceptAnyArgs(),
    description: extensionTask.description,
    runCondition: runCondition,
    dependsOn: extensionTask.dependsOn.toSet(),
    phase: extensionTask.phase,
  );
}

Future<void> Function(List<String>, [ChangeSet?]) _taskAction(
  Sendable<JavaCommand, Object?> jvmExecutor,
  String classpath,
  String absRootDir,
  ExtensionTask extensionTask,
) {
  return (List<String> taskArgs, [ChangeSet? changes]) async {
    logger.fine(
      () =>
          'Requesting JBuild to run classpath=$classpath, '
          'className=${extensionTask.className}, '
          'method=${extensionTask.methodName}, '
          'args=$taskArgs, '
          'changes=$changes '
          'on directory ${Directory.current.path}',
    );
    await jvmExecutor.send(
      RunJava(
        extensionTask.name,
        classpath,
        extensionTask.className,
        extensionTask.methodName,
        [changes?.toMap(), taskArgs],
        extensionTask.constructorData,
      ),
    );
  };
}

RunCondition _runCondition(ExtensionTask extensionTask, DartleCache cache) {
  final dependsOnJbConfig = extensionTask.basicConfig.constructors.any(
    (c) => c.values.any((v) => v == ConfigType.jbConfig),
  );

  if (!dependsOnJbConfig &&
      extensionTask.inputs.isEmpty &&
      extensionTask.outputs.isEmpty) {
    return const AlwaysRun();
  }
  return RunOnChanges(
    cache: cache,
    inputs: patternFileCollection(
      extensionTask.inputs.followedBy([yamlJbFile, jsonJbFile]),
    ),
    outputs: patternFileCollection(extensionTask.outputs),
  );
}

List<String> _ensureStrings(dynamic value) {
  List list = value.toList();
  final badValues = list.where((e) => e is! String).toList();
  if (badValues.isNotEmpty) {
    failBuild(reason: 'Non-string values found in Set<String>: $badValues');
  }
  return list.whereType<String>().toList();
}
