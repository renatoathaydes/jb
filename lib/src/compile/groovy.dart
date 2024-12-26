import 'dart:io';

import 'package:dartle/dartle.dart';
import 'package:jb/src/jvm_executor.dart';

import '../config.dart';

const _groovyCompiler = 'org.codehaus.groovy.tools.FileSystemCompiler';

final _groovyJarPattern = RegExp(r'groovy-\d+\.\d+\.\d+\.jar');

bool hasGroovyDependency(JbConfiguration config) {
  const groovy3Prefix = '$groovy3:';
  const groovy4Prefix = '$groovy4:';
  const spockPrefix = '$spockCore:';
  return config.dependencies.keys.any((k) =>
      k.startsWith(groovy3Prefix) ||
      k.startsWith(groovy4Prefix) ||
      k.startsWith(spockPrefix));
}

Future<String> findGroovyJar(JbConfiguration config) async {
  final jar = await Directory(config.compileLibsDir).list().firstWhere(
      (f) => f is File && _groovyJarPattern.matchAsPrefix(f.path) != null,
      orElse: () => failBuild(
          reason:
              'Project has a Groovy dependency but Groovy jar was not found in '
              '${config.compileLibsDir}'));
  return jar.path;
}

Future<JavaCommand> groovyCommand(
    JbConfiguration config, String workingDir, List<String> args) async {
  final groovyJar = await findGroovyJar(config);
  // TODO
  // return RunJava('compileGroovy',
  //     classpath, className,
  //     methodName, args, constructorData);
  return RunJava(
      'compileGroovy', groovyJar, _groovyCompiler, 'commandLineCompile', [
    // ...config.preArgs(workingDir),
    args,
    true
  ], const []);
}
