import 'dart:io';

import 'package:dartle/dartle.dart';
import 'package:jb/src/utils.dart';
import 'package:path/path.dart' as p;

import '../config.dart';

final groovyJarPattern = RegExp(r'groovy-\d+\.\d+\..*\.jar$');

const _groovy3Prefix = '$groovy3:';
const _groovy4Prefix = '$groovy4:';
const _spockPrefix = '$spockCore:';
final _groovydocs = 'groovy-groovydoc';

bool hasGroovyDependency(
  Iterable<MapEntry<String, DependencySpec>> dependencies,
) {
  return dependencies.any((entry) {
    final key = entry.key;
    return key.startsWith(_groovy3Prefix) ||
        key.startsWith(_groovy4Prefix) ||
        key.startsWith(_spockPrefix);
  });
}

Future<String> findGroovyJar(JbConfiguration config) async {
  final libsDir = config.compileLibsDir.asOsPath();
  final jar = await Directory(libsDir).list().firstWhere(
    (f) =>
        f is File && groovyJarPattern.matchAsPrefix(p.basename(f.path)) != null,
    orElse: () => failBuild(
      reason:
          'Project has a Groovy or Spock dependency but Groovy jar was '
          'not found in $libsDir',
    ),
  );
  logger.finer(() => 'Groovy jar: ${jar.path}');
  return jar.path;
}

/// Figure out the Groovydocs depedendency to be used given the list of
/// resolved dependencies.
///
/// If no Groovy dependency is declared, return `null`, otherwise, find the
/// Groovy version being used and return the appropriate Groovydocs artifact.
Future<String?> findGroovydocsDependency(
  List<ResolvedDependency> dependencies,
) async {
  for (final (prefix, isV3) in const [
    (_groovy3Prefix, true),
    (_groovy4Prefix, false),
  ]) {
    final dep = dependencies
        .where((d) => d.artifact.startsWith(prefix))
        .firstOrNull;
    if (dep != null) {
      final version = dep.artifact.substring(prefix.length);
      final group = isV3 ? groovy3Group : groovy4Group;
      return '$group:$_groovydocs:$version';
    }
  }
  return null;
}
