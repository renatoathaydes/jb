import 'package:schemake/schemake.dart';

const extensionTask = Objects(
  'ExtensionTaskExtra',
  {
    'inputs': Property(Arrays(Strings())),
    'outputs': Property(Arrays(Strings())),
    'dependsOn': Property(Arrays(Strings())),
    'dependents': Property(Arrays(Strings())),
  },
  description:
      'The extra config for a jb task obtained by '
      'instantiating the Java task and calling getSummary().',
);
