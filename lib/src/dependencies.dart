import 'package:dartle/dartle_cache.dart';

import 'config.dart';
import 'sub_project.dart';
import 'utils.dart';

Future<ResolvedProjectDependencies> resolveLocalDependencies(JBuildFiles files,
    JBuildConfiguration config, DartleCache cache, List<String> args) async {
  final pathDependencies = config.dependencies.entries
      .map((e) => e.value.toPathDependency())
      .whereNonNull()
      .toStream();

  final subProjectFactory = SubProjectFactory(files, config, args, cache);

  final projectDeps = <ProjectDependency>[];
  final jars = <JarDependency>[];

  await for (final pathDep in pathDependencies) {
    pathDep.map(jar: jars.add, jbuildProject: projectDeps.add);
  }

  final subProjects =
      await subProjectFactory.createSubProjects(projectDeps).toList();

  logger.fine(() => 'Resolved ${subProjects.length} sub-projects, '
      '${jars.length} local jar dependencies.');

  for (final subProject in subProjects) {
    subProject.output.when(
        // ignore: void_checks
        dir: (_) {
          throw UnsupportedError('Cannot depend on project ${subProject.name} '
              'because its output is not a jar!');
        },
        jar: (j) => jars.add(JarDependency(subProject.spec, j)));
  }

  return ResolvedProjectDependencies(subProjects, jars);
}
