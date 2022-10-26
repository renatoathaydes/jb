import 'dart:io';

import 'package:dartle/dartle_dart.dart';
import 'package:path/path.dart' as p;
import 'paths.dart';

Stream<Directory> _deletables() async* {
  await for (final entity in Directory(testProjectsDir).list(recursive: true)) {
    if (entity is Directory) {
      final name = p.basename(entity.path);
      if (const {'build', '.jbuild-cache'}.contains(name)) {
        yield entity;
      }
    }
  }
}

void setupTaskDependencies(DartleDart dartleDart) {
  dartleDart.clean.dependsOn(const {'cleanTests'});
}

Future<Task> cleanTestsTask() async => Task(cleanTests,
    description: 'Cleans the test directories from temporary files.',
    phase: TaskPhase.setup,
    runCondition:
        RunToDelete(dirs((await _deletables().toList()).map((e) => e.path))));

Future<void> cleanTests(_) async {
  await for (final entity in _deletables()) {
    await ignoreExceptions(() async => await entity.delete(recursive: true));
  }
}
