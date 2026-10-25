import 'dart:io';

import 'package:actors/actors.dart' show Sendable;
import 'package:dartle/dartle.dart';
import 'package:dartle/dartle_cache.dart' show DartleCache;
import 'package:logging/logging.dart';

import '../config.dart';
import '../jvm_executor.dart';
import '../patterns.dart';
import '../utils.dart';
import '../xml_rpc_structs.dart' show ChangeSetToMap;
import 'constructors.dart';
import 'jb_extension.dart';

Future<List<ExtensionTask>> loadExtensionTasks(
  JbConfiguration config,
  String classpath,
  Iterable<BasicExtensionTask> taskConfigs,
  Sendable<JavaCommand, Object?> jvmExecutor,
  String projectName,
) async {
  logger.fine(() => 'Loading extension tasks data from Java extension');
  final futureTasks = taskConfigs.map(
    (taskConfig) => _loadExtensionTask(
      config,
      classpath,
      taskConfig,
      jvmExecutor,
      projectName,
    ),
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
          extensionTask.qualifiedName,
          jvmExecutor,
          project.classpath,
          extensionTask,
          project.rootDir,
          cache,
        );
      })
      .toList(growable: false);
}

Map<String, List<ExtensionProject>> _findAmbiguousTasks(
  List<ExtensionProject> extensionProjects,
) {
  final projectsByTaskName = <String, List<ExtensionProject>>{};
  for (final p in extensionProjects) {
    for (final t in p.model.extensionTasks) {
      projectsByTaskName.update(
        t.name,
        (ps) => [...ps, p],
        ifAbsent: () => [p],
      );
    }
  }
  projectsByTaskName.removeWhere((_, ps) => ps.length == 1);
  return projectsByTaskName;
}

void verifyExtensionTasks(
  JbConfiguration config,
  List<ExtensionProject> extensionProjects,
) {
  final ambiguousTasks = _findAmbiguousTasks(extensionProjects);
  final extras = {...config.extras.keys};

  // ambiguous tasks cannot be configured by their simple name
  for (final extra in extras) {
    final Set<String>? ambiguousOwners = ambiguousTasks[extra]
        ?.map((p) => p.name)
        .toSet();
    if (ambiguousOwners != null) {
      failBuild(
        reason:
            'Configuration of task "$extra" is ambiguous because '
            'it could belong to any of the following extension projects: $ambiguousOwners. '
            'Use the qualified name of the task, e.g. "$extra#${ambiguousOwners.first}".',
      );
    }
  }

  final Set<String> taskNames = {};
  for (final project in extensionProjects) {
    for (final extensionTask in project.model.extensionTasks) {
      final simpleName = extensionTask.name;
      final qualifiedName = extensionTask.qualifiedName;
      final wasAdded = taskNames.add(qualifiedName);
      if (!wasAdded) {
        failBuild(
          reason: "Duplicate extension task name detected: $qualifiedName",
        );
      }
      // allow users to use either qualified or simple name
      final removedQualified = extras.remove(qualifiedName);
      final removedSimple = extras.remove(simpleName);
      if (removedSimple && removedQualified) {
        failBuild(
          reason:
              'Cannot configure task both by simple name ($simpleName) '
              'and qualified name ($qualifiedName).',
        );
      }
      final wasRemoved = removedQualified || removedSimple;
      if (logger.isLoggable(Level.FINE)) {
        logger.fine(
          () =>
              'Configuration ${wasRemoved ? '' : 'not '}found for task: $qualifiedName',
        );
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
  String projectName,
) async {
  final taskName = '${taskConfig.name}#$projectName';
  final constructorData = resolveTaskConstructorData(
    config,
    taskConfig,
    taskName,
  );
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
      qualifiedName: taskName,
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
  String name,
  Sendable<JavaCommand, Object?> jvmExecutor,
  String classpath,
  ExtensionTask extensionTask,
  String absRootDir,
  DartleCache cache,
) {
  final runCondition = _runCondition(extensionTask, cache);
  return Task(
    _taskAction(jvmExecutor, classpath, absRootDir, extensionTask),
    name: name,
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
