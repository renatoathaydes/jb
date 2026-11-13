import '../config.dart' show logger;
import '../jvm_executor.dart';

/// Installs the given [artifacts] (without their transitive dependencies)
/// into [outputDir] using JBuild.
///
/// If [installToMavenLocal] is `true`, artifacts are also installed in Maven Local.
Future<void> installArtifacts(
  String taskName,
  JBuildSender jBuildSender,
  List<String> preArgs,
  List<String> artifacts,
  String outputDir, {
  required bool installToMavenLocal,
}) async {
  if (artifacts.isEmpty) {
    return logger.fine("No dependencies to install for '$taskName'.");
  }
  await jBuildSender.send(
    RunJBuild(taskName, preArgs, 'install', [
      '--non-transitive',
      if (installToMavenLocal) '--maven-local',
      '--directory',
      outputDir,
      ...artifacts,
    ]),
  );
}
