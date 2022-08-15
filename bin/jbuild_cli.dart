import 'dart:io';

import 'package:dartle/dartle.dart';
import 'package:jbuild_cli/jbuild_cli.dart';

void main(List<String> arguments) async {
  final jbuildJar = await createIfNeededAndGetJBuildJarFile();
  final configFile = File('jbuild.yaml');
  try {
    await JBuildCli(jbuildJar, configFile).start(arguments);
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
