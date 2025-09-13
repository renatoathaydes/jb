import 'package:schemake/schemake.dart';

const _requirement = Objects('Requirement', {
  'module': Property(Strings()),
  'version': Property(Strings()),
  'flags': Property(Strings()),
}, description: 'A Java module requirement.');

const _module = Objects('Module', {
  'javaVersion': Property(Strings()),
  'path': Property(Strings()),
  'name': Property(Strings()),
  'automatic': Property(Bools()),
  'version': Property(Strings()),
  'flags': Property(Strings()),
  'requires': Property(Arrays(_requirement)),
}, description: 'Java Module information.');

const _jar = Objects('Jar', {
  'javaVersion': Property(Strings()),
  'path': Property(Strings()),
}, description: 'Java Module information.');

const compilationPath = Objects('CompilationPath', {
  'modules': Property(
    Arrays(_module),
    description: 'Java modules to be included the --module-path.',
  ),
  'jars': Property(
    Arrays(_jar),
    description: 'Java jars to be included in the --class-path.',
  ),
}, description: 'Java compilation path.');
