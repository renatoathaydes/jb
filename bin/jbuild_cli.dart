import 'dart:io';

import 'package:dartle/dartle.dart';
import 'package:jb/jb.dart';

void main(List<String> arguments) async {
  final stopWatch = Stopwatch()..start();
  final jbuildJar = await createIfNeededAndGetJBuildJarFile();
  try {
    await runJBuild(arguments, stopWatch, jbuildJar);
  } on DartleException catch (e, st) {
    print(e.message);
    print(st);
    exit(e.exitCode);
  } catch (e, st) {
    print('$e');
    print(st);
    exit(1);
  }
}
