import 'package:dartle/dartle_dart.dart';
import 'package:path/path.dart' as p;

import 'dartle-src/generate_embedded_assets.dart' as comp;
import 'dartle-src/setup_test_mvn_repo.dart' as tests;
import 'dartle-src/clean_tests.dart' as cleaners;
import 'dartle-src/empty_generated_assets.dart' as emptier;

final dartleDart = DartleDart(DartConfig(
    buildRunnerRunCondition: RunOnChanges(
  inputs: files({p.join('lib', 'src', 'config.dart')}),
  outputs: files({p.join('lib', 'src', 'config.freezed.dart')}),
)));

void main(List<String> args) async {
  comp.setupTaskDependencies(dartleDart);
  tests.setupTaskDependencies(dartleDart);
  cleaners.setupTaskDependencies(dartleDart);

  await run(args, tasks: {
    comp.generateEmbeddedAssetsTask,
    tests.buildMvnRepoListsProjectTask,
    tests.setupTestMvnRepoTask,
    emptier.emptyGeneratedAssetsTask,
    await cleaners.cleanTestsTask(),
    ...dartleDart.tasks,
  }, defaultTasks: {
    dartleDart.build
  });
}
