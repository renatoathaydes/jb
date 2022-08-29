import 'package:dartle/dartle_dart.dart';
import 'package:path/path.dart' as p;

import 'dartle-src/generate_embedded_assets.dart' as comp;
import 'dartle-src/setup_test_mvn_repo.dart' as tests;

final dartleDart = DartleDart(DartConfig(
    buildRunnerRunCondition: RunOnChanges(
  inputs: files({p.join('lib', 'src', 'config.dart')}),
  outputs: files({p.join('lib', 'src', 'config.freezed.dart')}),
)));

void main(List<String> args) {
  comp.setupTaskDependencies(dartleDart);
  tests.setupTaskDependencies(dartleDart);

  run(args, tasks: {
    comp.generateEmbeddedAssetsTask,
    tests.buildMvnRepoListsProjectTask,
    tests.setupTestMvnRepoTask,
    ...dartleDart.tasks,
  }, defaultTasks: {
    dartleDart.build
  });
}
