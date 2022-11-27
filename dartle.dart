import 'package:dartle/dartle_dart.dart';

import 'dartle-src/clean_tests.dart' as cleaners;
import 'dartle-src/empty_generated_assets.dart' as emptier;
import 'dartle-src/generate_embedded_assets.dart' as comp;
import 'dartle-src/setup_test_mvn_repo.dart' as tests;
import 'dartle-src/distribution.dart' as dist;
import 'dartle-src/generate_version_file.dart' as gen;

final dartleDart = DartleDart();

void main(List<String> args) async {
  comp.setupTaskDependencies(dartleDart);
  tests.setupTaskDependencies(dartleDart);
  cleaners.setupTaskDependencies(dartleDart);
  dist.setupTaskDependencies(dartleDart);
  gen.setupTaskDependencies(dartleDart);

  await run(args, tasks: {
    comp.generateEmbeddedAssetsTask,
    tests.buildMvnRepoListsProjectTask,
    tests.setupTestMvnRepoTask,
    emptier.emptyGeneratedAssetsTask,
    dist.distributionTask,
    gen.generateVersionFileTask,
    await cleaners.cleanTestsTask(),
    ...dartleDart.tasks,
  }, defaultTasks: {
    dartleDart.build
  });
}
