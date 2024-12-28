import 'dart:io';

import 'package:dartle/dartle.dart';
import 'package:path/path.dart' as p;

import '../config.dart';

final groovyJarPattern = RegExp(r'groovy-\d+\.\d+\..*\.jar');

bool hasGroovyDependency(JbConfiguration config) {
  const groovy3Prefix = '$groovy3:';
  const groovy4Prefix = '$groovy4:';
  const spockPrefix = '$spockCore:';
  return config.dependencies.keys.any((k) =>
      k.startsWith(groovy3Prefix) ||
      k.startsWith(groovy4Prefix) ||
      k.startsWith(spockPrefix));
}

Future<String> findGroovyJar(JbConfiguration config) async {
  final jar = await Directory(config.compileLibsDir).list().firstWhere(
      (f) =>
          f is File &&
          groovyJarPattern.matchAsPrefix(p.basename(f.path)) != null,
      orElse: () => failBuild(
          reason:
              'Project has a Groovy dependency but Groovy jar was not found in '
              '${config.compileLibsDir}'));
  return jar.path;
}
