import 'package:dartle/dartle_dart.dart';
import 'package:path/path.dart' as p;

import 'dartle-src/generate_embedded_assets.dart';

final dartleDart = DartleDart(DartConfig(
    buildRunnerRunCondition: RunOnChanges(
  inputs: files({p.join('lib', 'src', 'config.dart')}),
  outputs: files({p.join('lib', 'src', 'config.freezed.dart')}),
)));

void main(List<String> args) {
  setupTaskDependencies(dartleDart);

  run(args, tasks: {
    generateEmbeddedAssetsTask,
    ...dartleDart.tasks,
  }, defaultTasks: {
    dartleDart.build
  });
}
