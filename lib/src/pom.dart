import 'package:conveniently/conveniently.dart';
import 'package:dartle/dartle.dart';

import 'config.dart';
import 'path_dependency.dart';
import 'resolved_dependency.dart';

const _errorPrefix = 'Cannot generate POM, ';

const pomHeader = '''\
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>
''';

const nonTransitiveDependency = '''\
            <exclusions>
                <exclusion>
                    <groupId>*</groupId>
                    <artifactId>*</artifactId>
                </exclusion>
            </exclusions>''';

/// Create a Maven POM for publishing purposes.
///
/// The resulting POM is not meant to be used as a build file with the Maven
/// tool because it does not contain non-published POM data, such as
/// source locations, Maven plugins for tests/compilation etc.
Object createPom(
    JbConfiguration config, ResolvedLocalDependencies localDependencies) {
  final group = config.group.orThrow(() => _fail('"group" is mandatory.'));
  final module = config.module.orThrow(() => _fail('"module" is mandatory.'));
  final version =
      config.version.orThrow(() => _fail('"version" is mandatory.'));
  final builder = StringBuffer('''\
$pomHeader
    <groupId>$group</groupId>
    <artifactId>$module</artifactId>
    <version>$version</version>
    <dependencies>
''');
  // add only non-local deps first
  for (final dep in config.dependencies.entries) {
    final spec = dep.value;
    if (spec.path == null) builder.addDependency(dep.key, spec);
  }
  // add local deps
  for (final localDep in localDependencies.projectDependencies) {
    builder.addProjectDependency(localDep);
  }
  for (final localDep in localDependencies.jars) {
    builder.addJarDependency(localDep);
  }
  builder.writeln('''\
    </dependencies>
</project>''');
  return builder;
}

Never _fail(String message) =>
    throw DartleException(message: '$_errorPrefix$message');

(String, String, String) _parseDependency(String spec) {
  return switch (spec.split(':')) {
    [var group, var module, var version, ...] => (group, module, version),
    [var group, var module] => (group, module, 'latest'),
    _ => _fail('invalid dependency specification '
        '(expected "group:module:version"): "$spec".'),
  };
}

extension on StringBuffer {
  void addDependency(String name, DependencySpec dep) {
    final (group, module, version) = _parseDependency(name);
    write('''\
        <dependency>
            <groupId>$group</groupId>
            <artifactId>$module</artifactId>
            <version>$version</version>
            <scope>${dep.scope.toMaven()}</scope>
''');
    if (!dep.transitive) {
      writeln(nonTransitiveDependency);
    }
    writeln('        </dependency>');
  }

  void addProjectDependency(ResolvedProjectDependency dep) {
    final group = dep.group.orThrow(() =>
        _fail('at project dependency "${dep.path}": "group" is mandatory.'));
    final module = dep.module.orThrow(() =>
        _fail('at project dependency "${dep.path}": "module" is mandatory.'));
    final version = dep.version.orThrow(() =>
        _fail('at project dependency "${dep.path}": "version" is mandatory.'));
    write('''\
        <dependency>
            <groupId>$group</groupId>
            <artifactId>$module</artifactId>
            <version>$version</version>
            <scope>${dep.scope.toMaven()}</scope>
        </dependency>
''');
  }

  void addJarDependency(JarDependency jar) {
    _fail('jar dependency is not supported when publishing Maven projects.\n'
        'Replace jar dependency "${jar.path}" with a Maven dependency.');
  }
}

extension on DependencyScope {
  String toMaven() {
    return switch (this) {
      DependencyScope.all => 'compile',
      DependencyScope.compileOnly => 'provided',
      DependencyScope.runtimeOnly => 'runtime',
    };
  }
}
