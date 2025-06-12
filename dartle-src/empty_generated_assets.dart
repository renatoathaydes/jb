import 'dart:io';

import 'package:dartle/dartle.dart';
import 'package:path/path.dart' as p;

final emptyGeneratedAssetsTask = Task(
  emptyGeneratedAssets,
  phase: TaskPhase.setup,
  description: 'empties the contents of all generated assets',
);

Future<void> emptyGeneratedAssets(List<String> args) async {
  await File(
    p.join('lib', 'src', 'jbuild_jar.g.dart'),
  ).writeAsString("const jbuildJarB64 = '';");
}
