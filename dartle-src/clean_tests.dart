import 'dart:io';

import 'package:dartle/dartle_dart.dart';
import 'package:path/path.dart' as p;

import 'paths.dart';

class _CachedFileCollection {
  final Stream<Directory> Function() loader;

  List<Directory>? _cached;

  _CachedFileCollection(this.loader);

  Future<List<Directory>> dirs() async => _cached ??= await loader().toList();

  @override
  String toString() => 'CachedDirectories($_cached)';
}

final _testDirs = _CachedFileCollection(() => _deletables(tests: true));
final _exampleDirs = _CachedFileCollection(() => _deletables(examples: true));

Stream<T> _appendStreams<T>(List<Stream<T>> streams) async* {
  for (final stream in streams) {
    yield* stream;
  }
}

Stream<Directory> _deletables(
    {bool tests = false, bool examples = false}) async* {
  await for (final entity in _appendStreams([
    if (tests) Directory(testProjectsDir).list(),
    if (examples) Directory(exampleProjectsDir).list(),
  ])) {
    if (entity is Directory) {
      yield* _deletablesIn(entity);
      final tests = Directory(p.join(entity.path, 'test'));
      if (await tests.exists()) {
        yield* _deletablesIn(tests);
      }
    }
  }
}

Stream<Directory> _deletablesIn(Directory entity) async* {
  await for (final projectDir in entity.list()) {
    final name = p.basename(projectDir.path);
    if (projectDir is Directory &&
        const {'build', '.jb-cache', '.dartle_tool', 'test-repo'}
            .contains(name)) {
      yield projectDir;
      if (name == 'with-sub-project') {
        yield* _deletablesIn(projectDir);
      }
    }
  }
}

void setupTaskDependencies(DartleDart dartleDart) {
  // the examples include a lot of jars that would get cached by Dartle
  // if not cleaned as the 'example' dir is considered part of Dart tests.
  dartleDart.test.dependsOn(const {'cleanExamples'});

  dartleDart.clean.dependsOn(const {'cleanTests', 'cleanExamples'});
}

Future<Task> cleanTestsTask() async => Task(cleanTests,
    description: 'Cleans the test directories from temporary files.',
    phase: TaskPhase.setup,
    runCondition:
        RunToDelete(dirs((await _testDirs.dirs()).map((e) => e.path))));

Future<Task> cleanExamplesTask() async => Task(cleanExamples,
    description: 'Cleans the example dir from generated files.',
    phase: TaskPhase.setup,
    runCondition:
        RunToDelete(dirs((await _exampleDirs.dirs()).map((e) => e.path))));

Future<void> cleanTests(_) async {
  for (final entity in await _testDirs.dirs()) {
    await ignoreExceptions(() async => await entity.delete(recursive: true));
  }
}

Future<void> cleanExamples(_) async {
  await _exampleDirs.dirs();
  for (final entity in await _exampleDirs.dirs()) {
    await ignoreExceptions(() async => await entity.delete(recursive: true));
  }
}
