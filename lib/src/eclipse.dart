import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:xml/xml.dart' as xml;

/// Generate Eclipse IDE files for the project.
///
/// Eclipse IDE files can be used by most other IDEs to import a project.
Future<void> generateEclipseFiles(
  Iterable<String> sourceDirs,
  Iterable<String> resourceDirs,
  String? module,
  String compileLibsDir, {
  String classpathFile = '.classpath',
  String projectFile = '.project',
}) async {
  final classpath =
      await generateClasspath(sourceDirs, resourceDirs, compileLibsDir);
  await File(classpathFile)
      .writeAsString(classpath.toXmlString(pretty: true, indent: '    '));
  final project = generateProject(module);
  await File(projectFile)
      .writeAsString(project.toXmlString(pretty: true, indent: '    '));
}

Future<xml.XmlDocument> generateClasspath(Iterable<String> sourceDirs,
    Iterable<String> resourceDirs, String compileLibsDir) async {
  final builder = xml.XmlBuilder();
  builder.processing('xml', 'version="1.0" encoding="UTF-8"');
  final jars = await Directory(compileLibsDir)
      .list()
      .where((f) => p.extension(f.path) == '.jar')
      .toList();
  builder.element('classpath', nest: () {
    builder.generatedClasspathEntry(
        kind: 'con',
        path: 'org.eclipse.jdt.launching.JRE_CONTAINER',
        attributes: {'module': 'true'});
    for (final src in sourceDirs) {
      builder.generatedClasspathEntry(kind: 'src', path: src);
    }
    for (final src in resourceDirs) {
      builder.generatedClasspathEntry(kind: 'src', path: src);
    }
    for (final dep in jars) {
      builder.generatedClasspathEntry(kind: 'lib', path: dep.path);
    }
  });
  return builder.buildDocument();
}

xml.XmlDocument generateProject(String? module) {
  final builder = xml.XmlBuilder();
  builder.processing('xml', 'version="1.0" encoding="UTF-8"');
  builder.element('projectDescription', nest: () {
    builder.element('name', nest: () {
      builder.text(module ?? 'project');
    });
    builder.element('buildSpec', nest: () {
      builder.element('buildCommand', nest: () {
        builder.element('name', nest: () {
          builder.text('org.eclipse.jdt.core.javabuilder');
        });
        builder.element('arguments', isSelfClosing: false);
      });
    });
    builder.element('natures', nest: () {
      builder.element('nature', nest: () {
        builder.text('org.eclipse.jdt.core.javanature');
      });
    });
  });
  return builder.buildDocument();
}

extension _XmlBuilderExt on xml.XmlBuilder {
  void generatedClasspathEntry(
      {String? kind,
      String? path,
      String? output,
      Map<String, String> attributes = const {}}) {
    element('classpathentry',
        attributes: {
          if (kind != null) 'kind': kind,
          if (path != null) 'path': path,
          if (output != null) 'output': output,
        },
        nest: attributes.isEmpty
            ? null
            : () {
                element('attributes', nest: () {
                  attributes.forEach((key, value) {
                    element('attribute',
                        attributes: {'name': key, 'value': value});
                  });
                });
              });
  }
}
