import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:conveniently/conveniently.dart';
import 'package:dartle/dartle.dart';
import 'package:io/ansi.dart' as ansi;
import 'package:logging/logging.dart';

import '../jb.dart';
import 'version.g.dart';

void printHelp() {
  logger.log(
      Level.SHOUT,
      const AnsiMessage([
        AnsiMessagePart.code(ansi.styleBold),
        AnsiMessagePart.code(ansi.blue),
        AnsiMessagePart.text(r'''
                 _ ___      _ _    _ 
              _ | | _ )_  _(_) |__| |
             | || | _ \ || | | / _` |
'''),
        AnsiMessagePart.code(ansi.yellow),
        AnsiMessagePart.text(r'''
              \__/|___/\_,_|_|_\__,_|
                Java Build System'''),
      ]));
  print('''
                  Version: $jbVersion

Usage:
    jb <task [args...]...> <options...>
    
To create a new project, run `jb create`.
To see available tasks, run 'jb -s' (list of tasks) or 'jb -g' (task graph).

Options:''');
  print(optionsDescription);
  print('\nFor Documentation, visit '
      'https://github.com/renatoathaydes/jb');
}

Future<void> printVersion(File jbuildJar) async {
  print('jb version: $jbVersion');
  print('JBuild version: ${await getJBuildVersion(jbuildJar)}');
}

Future<String> getJBuildVersion(File jbuildJar) async {
  const implVersionPrefix = 'Implementation-Version: ';
  final stream = InputFileStream(jbuildJar.path);
  try {
    final buffer = ZipDecoder().decodeBuffer(stream);
    final manifestEntry = 'META-INF/MANIFEST.MF';
    final archiveFile = buffer.findFile(manifestEntry).orThrow(() => failBuild(
        reason: 'JBuild jar at ${jbuildJar.path} '
            'is missing Manifest file: $manifestEntry'));

    final versionLines = await Stream.value((archiveFile.content as List<int>))
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .where((line) => line.startsWith(implVersionPrefix))
        .map((ver) => ver.substring(implVersionPrefix.length))
        .take(1)
        .toList();
    return versionLines.firstOrNull ?? 'unknown';
  } finally {
    await stream.close();
  }
}
