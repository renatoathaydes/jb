import 'package:conveniently/conveniently.dart';
import 'package:dartle/dartle.dart' show failBuild;
import 'package:jb/jb.dart';
import 'package:xml/xml.dart' show XmlBuilder;

import 'utils.dart';

const _errorPrefix = 'Cannot generate POM, ';

const _pomHeaderAttributes = {
  'xmlns': 'http://maven.apache.org/POM/4.0.0',
  'xmlns:xsi': 'http://www.w3.org/2001/XMLSchema-instance',
  'xsi:schemaLocation':
      'http://maven.apache.org/POM/4.0.0 '
      'http://maven.apache.org/xsd/maven-4.0.0.xsd',
};

/// Maven artifact.
typedef Artifact = ({
  String group,
  String module,
  String name,
  String version,
  String? description,
  List<Developer> developers,
  SourceControlManagement? scm,
  String? url,
  List<License> licenses,
});

Result<Artifact> createArtifact(JbConfiguration config) {
  Never Function() mandatory(String what) =>
      () => _fail('"$what" must be provided in the jb configuration file.');
  return catching$(
    () => (
      group: config.group.ifBlank(mandatory('group')),
      module: config.module.ifBlank(mandatory('module')),
      name: config.name.ifBlank(mandatory('name')),
      version: config.version.ifBlank(mandatory('version')),
      description: config.description,
      developers: config.developers,
      scm: config.scm,
      url: config.url,
      licenses: config.licenses
          .map((id) => allLicenses[id].orThrow(() => invalidLicense([id])))
          .toList(),
    ),
  );
}

/// Create a Maven POM for publishing purposes.
///
/// The resulting POM is not meant to be used as a build file with the Maven
/// tool because it does not contain non-published POM data, such as
/// source locations, Maven plugins for tests/compilation etc.
String createPom(
  Artifact artifact,
  Iterable<MapEntry<String, DependencySpec>> dependencies,
  ResolvedLocalDependencies localDependencies,
) {
  final xml = XmlBuilder();
  xml
    ..processing('xml', 'version="1.0" encoding="UTF-8"')
    ..element(
      'project',
      attributes: _pomHeaderAttributes,
      nest: () {
        xml
          ..tag('modelVersion', '4.0.0') //
          ..tag('groupId', artifact.group) //
          ..tag('artifactId', artifact.module) //
          ..tag('version', artifact.version) //
          ..tag('name', artifact.name);
        artifact.description.ifNonBlank((d) => xml.tag('description', d));
        artifact.url.ifNonBlank((url) => xml.tag('url', url));
        artifact.scm?.vmap(xml.scm);
        xml.addAll(artifact.licenses, 'licenses', xml.license);
        xml.addAll(artifact.developers, 'developers', xml.developer);
        if (dependencies.isNotEmpty) {
          xml.element(
            'dependencies',
            nest: () {
              for (final dep in dependencies) {
                final spec = dep.value;
                if (spec.path == null) xml.dependency(dep.key, spec);
              }
              for (final localDep in localDependencies.projectDependencies) {
                xml.projectDependency(localDep);
              }
              for (final localDep in localDependencies.jars) {
                xml.jarDependency(localDep);
              }
            },
          );
        }
      },
    );
  return xml.buildDocument().toXmlString(pretty: true);
}

Never _fail(String message) => failBuild(reason: '$_errorPrefix$message');

(String, String, String) _parseDependency(String spec) {
  return switch (spec.split(':')) {
    [var group, var module, var version, ...] => (group, module, version),
    [var group, var module] => (group, module, 'latest'),
    _ => _fail(
      'invalid dependency specification '
      '(expected "group:module:version"): "$spec".',
    ),
  };
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

extension on XmlBuilder {
  void tag(String tagName, String value) {
    element(tagName, nest: () => text(value));
  }

  void dependencyOn(
    String group,
    String module,
    String version,
    DependencySpec dep,
  ) {
    element(
      'dependency',
      nest: () {
        tag('groupId', group);
        tag('artifactId', module);
        tag('version', version);
        tag('scope', dep.scope.toMaven());
        if (!dep.transitive) {
          element(
            'exclusions',
            nest: () {
              element(
                'exclusion',
                nest: () {
                  tag('groupId', '*');
                  tag('artifactId', '*');
                },
              );
            },
          );
        } else if (dep.exclusions.isNotEmpty) {
          // TODO resolve the transitive dependencies, then exclude anything
          // that matches the exclusion patterns.
        }
      },
    );
  }

  void dependency(String name, DependencySpec dep) {
    final (group, module, version) = _parseDependency(name);
    dependencyOn(group, module, version, dep);
  }

  void projectDependency(ResolvedProjectDependency dep) {
    final group = dep.group.orThrow(
      () => _fail('at project dependency "${dep.path}": "group" is mandatory.'),
    );
    final module = dep.module.orThrow(
      () =>
          _fail('at project dependency "${dep.path}": "module" is mandatory.'),
    );
    final version = dep.version.orThrow(
      () =>
          _fail('at project dependency "${dep.path}": "version" is mandatory.'),
    );
    dependencyOn(group, module, version, dep.spec);
  }

  void jarDependency(JarDependency jar) {
    _fail(
      'jar dependency is not supported when publishing Maven projects.\n'
      'Replace jar dependency "${jar.path}" with a Maven dependency.',
    );
  }

  void addAll<T>(List<T> items, String tagName, void Function(T) fun) {
    if (items.isEmpty) return;
    element(
      tagName,
      nest: () {
        for (final item in items) {
          fun(item);
        }
      },
    );
  }

  void developer(Developer dev) {
    element(
      'developer',
      nest: () {
        tag('name', dev.name);
        tag('email', dev.email);
        tag('organization', dev.organization);
        tag('organizationUrl', dev.organizationUrl);
      },
    );
  }

  void license(License license) {
    element(
      'license',
      nest: () {
        tag('name', license.name);
        tag('url', license.uri);
      },
    );
  }

  void scm(SourceControlManagement scm) {
    element(
      'scm',
      nest: () {
        tag('connection', scm.connection);
        tag('developerConnection', scm.developerConnection);
        tag('url', scm.url);
      },
    );
  }
}
