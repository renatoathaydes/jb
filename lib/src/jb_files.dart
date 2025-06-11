import 'dart:io';

import 'package:path/path.dart' as p;

import 'config_source.dart';

const jbExtension = 'jb-extension';

/// Files and directories used by jb.
class JbFiles {
  final String jbCache;
  final File jbuildJar;
  final ConfigSource configSource;
  final String processorLibsDir;

  File get dependenciesFile => File(p.join(jbCache, 'dependencies.json'));

  File get processorDependenciesFile =>
      File(p.join(jbCache, 'processor-dependencies.json'));

  File get testDependenciesFile =>
      File(p.join(jbCache, 'test-dependencies.json'));

  File get javaSrcFileTreeFile =>
      File(p.join(jbCache, 'java-src-file-tree.txt'));

  File get jvmCdsFile => File(p.join(jbCache, 'jvm.cds'));

  JbFiles(this.jbuildJar,
      {required this.configSource, this.jbCache = '.jb-cache'})
      : processorLibsDir = p.join(jbCache, 'processor-dependencies');
}
