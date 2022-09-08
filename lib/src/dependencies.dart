import 'package:dartle/dartle.dart';
import 'package:dartle/dartle_cache.dart';

import 'config.dart';
import 'sub_project.dart';
import 'utils.dart';

Future<List<SubProject>> resolveSubProjects(JBuildFiles files,
    JBuildConfiguration config, DartleCache cache, Options options) async {
  final pathDependencies = config.dependencies.entries
      .map((e) => e.value.toPathDependency())
      .whereNonNull()
      .toStream();

  final subProjectFactory = SubProjectFactory(files, config, options, cache);

  final projectDeps = <ProjectDependency>[];
  final jars = <JarDependency>[];

  await for (final pathDep in pathDependencies) {
    pathDep.map(jar: jars.add, jbuildProject: projectDeps.add);
  }

  final subProjects =
      await subProjectFactory.createSubProjects(projectDeps).toList();

  logger.fine(() => 'Resolved ${subProjects.length} sub-projects, '
      '${jars.length} local jar dependencies.');

  return subProjects;
}
