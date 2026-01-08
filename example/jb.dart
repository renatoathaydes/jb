import 'package:dartle/dartle.dart';
import 'package:jb/jb.dart';

/// jb is meant to be used directly as a CLI tool to build Java projects.
/// However, it is possible to use it also as a Dart library.
///
/// This example shows how a [JbDartle] object can be created, which can
/// then be used to integrate it with a standard Dartle project.
///
/// As a configuration object is created from a const Map, this program can be
/// executed in any directory without the `jbuild.yaml` file, unlike the
/// "official" CLI utility. It looks for Java source code to compile in the
/// `src` directory. As the config object does not specify anything else,
/// the default options are used, which means a jar file is created with the
/// name of the working directory.
Future<void> main(List<String> args) async {
  final stopwatch = Stopwatch()..start();

  final config = await loadConfigString('''
    source-dirs: [ src ]
    resource-dirs: [ res ]
  ''');

  final jbOptions = JbCliOptions.parseArgs(args);
  final dartleOptions = parseOptions(jbOptions.dartleArgs);

  activateLogging(
    dartleOptions.logLevel,
    colorfulLog: dartleOptions.colorfulLog,
    logName: 'jbuild',
  );

  final buildRan = await runJb(
    jbOptions,
    dartleOptions,
    InstanceConfigSource(config),
  );
  if (buildRan) {
    logger.info(
      ColoredLogMessage(
        'jb completed successfully in ${stopwatch.elapsed}!',
        LogColor.green,
      ),
    );
  }
}
