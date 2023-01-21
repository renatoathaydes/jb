import 'dart:io';

import 'package:dartle/dartle_dart.dart';
import 'package:path/path.dart' as p;
import 'paths.dart';

Stream<Directory> _deletables() async* {
  await for (final entity in Directory(testProjectsDir).list()) {
    if (entity is Directory) {
      yield* _deletablesIn(entity);
    }
  }
}

Stream<Directory> _deletablesIn(Directory entity) async* {
  await for (final projectDir in entity.list()) {
    final name = p.basename(entity.path);
    if (projectDir is Directory &&
        const {'build', '.jbuild-cache', '.dartle_tool', 'test-repo'}
            .contains(name)) {
      yield projectDir;
      if (name == 'with-sub-project') {
        yield* _deletablesIn(projectDir);
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
