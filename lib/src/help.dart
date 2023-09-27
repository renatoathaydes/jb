import 'dart:io';

import 'package:dartle/dartle.dart';
import 'package:io/ansi.dart' as ansi;
import 'package:jb/jb.dart';
import 'package:logging/logging.dart';

import 'output_consumer.dart';
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
  await execJBuild('version', jbuildJar, const [], 'version', const [],
      onStdout: const _Printer());
}

class _Printer with ProcessOutputConsumer {
  const _Printer();

  @override
  void call(String line) => print('JBuild version: $line');

  @override
  set pid(int pid) {
    // ignore
  }
}
