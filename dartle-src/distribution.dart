import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:dartle/dartle_dart.dart';
import 'package:path/path.dart' as p;

const distributionTaskName = 'distribution';

final _executable = File(p.join('build', 'bin', 'jb'));
final _tar = File(p.join('build', 'jb.tar.gz'));

final distributionTask = Task(_tarAll,
    name: distributionTaskName,
    description:
        'Compacts the binary executable as well as other informational files '
        'for distribution to end users.',
    runCondition: RunOnChanges(
        inputs: files([_executable.path, 'README.md', 'LICENSE']),
        outputs: file(_tar.path)),
    phase: TaskPhase.tearDown);

void setupTaskDependencies(DartleDart dartle) {
  distributionTask.dependsOn({dartle.compileExe.name});
}

Future<void> _tarAll(_) async {
  final encoder = TarFileEncoder();
  final tempTar = File(p.join(Directory.systemTemp.path, 'temp_jb.tar'));
  encoder.create(tempTar.path);
  await encoder.addDirectory(_executable.parent);
  await encoder.addFile(File('README.md'));
  await encoder.addFile(File('LICENSE'));
  await encoder.close();

  final gzip = GZipEncoder();
  try {
    await _tar.writeAsBytes(gzip.encode(await tempTar.readAsBytes())!);
  } finally {
    await ignoreExceptions(() async => await tempTar.delete());
  }
}
