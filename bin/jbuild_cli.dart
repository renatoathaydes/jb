import 'dart:io';

import 'package:dartle/dartle.dart';
import 'package:jbuild_cli/jbuild_cli.dart';

void main(List<String> arguments) async {
  final jbuildJar = await createIfNeededAndGetJBuildJarFile();
  final configFile = File('jbuild.yaml');
  try {
    await JBuildCli(jbuildJar, configFile).start(arguments);
  } on DartleException catch (e) {
    print(e.message);
    exit(e.exitCode);
  } catch (e) {
    print('$e');
    exit(1);
  }
}
