import 'dart:io';

import 'package:dartle/dartle.dart';
import 'package:path/path.dart' as p;

import '../config.dart';

final groovyJarPattern = RegExp(r'groovy-\d+\.\d+\..*\.jar');

bool hasGroovyDependency(
  Iterable<MapEntry<String, DependencySpec>> dependencies,
) {
  const groovy3Prefix = '$groovy3:';
  const groovy4Prefix = '$groovy4:';
  const spockPrefix = '$spockCore:';
  return dependencies.any((entry) {
    final key = entry.key;
    return key.startsWith(groovy3Prefix) ||
        key.startsWith(groovy4Prefix) ||
        key.startsWith(spockPrefix);
  });
}

Future<String> findGroovyJar(JbConfiguration config) async {
  final jar = await Directory(config.compileLibsDir).list().firstWhere(
    (f) =>
        f is File && groovyJarPattern.matchAsPrefix(p.basename(f.path)) != null,
    orElse: () => failBuild(
      reason:
          'Project has a Groovy or Spock dependency but Groovy jar was not found in '
          '${config.compileLibsDir}',
    ),
  );
  return jar.path;
}
