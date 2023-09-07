import 'dart:io';

import 'package:path/path.dart' as p;

import 'config_source.dart';

/// Files and directories used by jb.
class JbFiles {
  final String jbCache;
  final File jbuildJar;
  final ConfigSource configSource;
  final String processorLibsDir;

  File get dependenciesFile => File(p.join(jbCache, 'dependencies.txt'));

  File get javaSrcFileTreeFile =>
      File(p.join(jbCache, 'java-src-file-tree.txt'));

  Directory get jbExtensionProjectDir => Directory('jb-extension');

  File get processorDependenciesFile =>
      File(p.join(jbCache, 'processor-dependencies.txt'));

  JbFiles(this.jbuildJar,
      {required this.configSource, this.jbCache = '.jb-cache'})
      : processorLibsDir = p.join(jbCache, 'processor-dependencies');
}
