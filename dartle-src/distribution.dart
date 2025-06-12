import 'package:dartle/dartle_dart.dart';
import 'package:path/path.dart' as p;

const distributionTaskName = 'distribution';

final _bin = p.join('build', 'bin');
final _tar = p.join('build', 'jb.tar.gz');
final _tarContents = entities(
  const ['README.md', 'LICENSE'],
  [DirectoryEntry(path: _bin)],
);

final distributionTask = Task(
  _tarAll,
  name: distributionTaskName,
  description:
      'Compacts the binary executable as well as other informational files '
      'for distribution to end users.',
  runCondition: RunOnChanges(inputs: _tarContents, outputs: file(_tar)),
  phase: TaskPhase.tearDown,
);

void setupTaskDependencies(DartleDart dartle) {
  distributionTask.dependsOn({dartle.compileExe.name});
}

Future<void> _tarAll(_) => tar(
  _tarContents,
  destination: _tar,
  destinationPath: (path) =>
      path.startsWith('build') ? path.substring('build/'.length) : path,
);
