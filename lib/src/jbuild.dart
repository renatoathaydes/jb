import 'dart:io';

import 'package:dartle/dartle.dart';
import 'package:dartle/dartle_cache.dart';
import 'package:dartle/dartle_dart.dart';
import 'package:yaml/yaml.dart';
import 'package:logging/logging.dart' as log;

import 'config.dart';
import 'utils.dart';
import 'tasks.dart';

class JBuildFiles {
  final File jbuildJar;
  final File configFile;

  const JBuildFiles(this.jbuildJar, this.configFile);
}

class JBuildCli {
  final JBuildFiles files;

  JBuildCli(File jbuildJar, File configFile)
      : files = JBuildFiles(jbuildJar, configFile);

  Future<void> start(List<String> args) async {
    final cache = DartleCache('.jbuild-cache');

    final config =
        (await createConfig()).orThrow('${files.configFile.path} not found.'
            '\nRun with the --help option to see usage.');
    final compile = await compileTask(files.jbuildJar, config, cache);

    activateLogging(log.Level.FINE);

    await runBasic({compile}, const {},
        Options(tasksInvocation: const ['-q', 'compile']), cache);
  }

  Future<CompileConfiguration?> createConfig() async {
    if (await files.configFile.exists()) {
      final config = asJsonMap(loadYaml(await files.configFile.readAsString()));
      return CompileConfiguration.fromJson(config);
    } else {
      return null;
    }
  }
}
