import 'dart:io' show File;

import 'package:actors/actors.dart' show Sendable;
import 'package:conveniently/conveniently.dart';
import 'package:dartle/dartle.dart' show failBuild;

import 'config.dart' show jbuild, logger;
import 'jvm_executor.dart';
import 'paths.dart' show jbuildJarPath;
import 'tasks.dart' show updateJBuildTaskName;

final _versionPattern = RegExp(r'^\d+.\d+.\d+(.\d+)?$');

Future<void> jbuildUpdate(JBuildSender jBuildSender) async {
  final localVersionOutput = _Lines();
  final latestVersionOutput = _Lines();
  try {
    await _update(jBuildSender, localVersionOutput, latestVersionOutput);
  } catch (e) {
    localVersionOutput.lines.vmap((lines) => _print('jbuild --version', lines));
    latestVersionOutput.lines.vmap((lines) => _print('jbuild versions', lines));
    rethrow;
  }
}

Future<void> _update(JBuildSender jBuildSender, _Lines localVersionOutput,
    _Lines latestVersionOutput) async {
  await jBuildSender.send(RunJBuild(
    updateJBuildTaskName,
    const ['-q', 'version'],
    localVersionOutput,
  ));
  final currentVersion = localVersionOutput.lines
          .where(_versionPattern.hasMatch)
          .firstOrNull
          ?.trim() ??
      '';
  if (currentVersion.isEmpty) {
    failBuild(reason: 'Could not get JBuild current version');
  }
  logger.fine(() => 'JBuild current version: $currentVersion');
  await jBuildSender.send(RunJBuild(updateJBuildTaskName,
      const ['-q', 'versions', jbuild], latestVersionOutput));
  final latestVersion = latestVersionOutput.lines
      .where((it) => it.startsWith('  * Latest: '))
      .map((it) => it.substring('  * Latest: '.length))
      .firstOrNull
      ?.trim();
  if (latestVersion == null || latestVersion.isEmpty) {
    failBuild(reason: 'Could not get JBuild latest version');
  }
  logger.fine(() => 'JBuild latest version is $latestVersion');
  if (currentVersion == latestVersion) {
    return logger.info(() =>
        'Nothing to do, current version is already the latest: $latestVersion');
  }
  logger.fine('Fetching latest JBuild jar');
  final jarFile = File(jbuildJarPath());
  final jarDir = jarFile.parent;
  await jBuildSender.send(
      RunJBuild('fetch', ['-d', jarDir.path, '$jbuild:$latestVersion:jar']));
  await File('jbuild-$latestVersion.jar').rename(jarFile.path);
  logger.info(() => 'Updated JBuild to version $latestVersion');
}

void _print(String command, List<String> lines) {
  if (lines.isEmpty) return;
  logger.warning('Command "$command" failed');
  for (final line in lines) {
    logger.warning('$command> $line');
  }
}

final class _Lines with Sendable<String, void> {
  final lines = <String>[];

  @override
  Future<void> send(String line) async => lines.add(line);
}
