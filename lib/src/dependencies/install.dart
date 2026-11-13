import '../config.dart' show logger;
import '../jvm_executor.dart';
import '../utils.dart';

/// Installs the given [artifacts] (without their transitive dependencies)
/// into [outputDir] using JBuild.
///
/// Artifacts are also installed in Maven Local, unless the environment variable
/// `JB_INSTALL_TO_MAVEN_LOCAL` is set to `false`.
Future<void> installArtifacts(
  String taskName,
  JBuildSender jBuildSender,
  List<String> preArgs,
  List<String> artifacts,
  String outputDir,
) async {
  if (artifacts.isEmpty) {
    return logger.fine("No dependencies to install for '$taskName'.");
  }
  await jBuildSender.send(
    RunJBuild(taskName, preArgs, 'install', [
      '--non-transitive',
      if ('JB_INSTALL_TO_MAVEN_LOCAL'.envVar().isNotFalse) '--maven-local',
      '--directory',
      outputDir,
      ...artifacts,
    ]),
  );
}
