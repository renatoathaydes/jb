import 'package:schemake/schemake.dart';

import 'jb_config_schema.dart';

const dependencyLicense = Objects('DependencyLicense', {
  'name': Property(Strings()),
  'url': Property(Strings()),
});

const versionConflict = Objects('VersionConflict', {
  'version': Property(Strings()),
  'requestedBy': Property(Arrays(Strings())),
});

const dependencyWarning = Objects('DependencyWarning', {
  'artifact': Property(Strings()),
  'versionConflicts': Property(Arrays(versionConflict)),
});

const resolvedDependency = Objects('ResolvedDependency', {
  'artifact': Property(Strings()),
  'spec': Property(dependency),
  'sha1': Property(Strings()),
  'licenses': Property(Nullable(Arrays(dependencyLicense))),
  'isDirect': Property(Bools()),
  'dependencies': Property(Arrays(Strings())),
});

const resolvedDependencies = Objects('ResolvedDependencies', {
  'dependencies': Property(Arrays(resolvedDependency)),
  'warnings': Property(Arrays(dependencyWarning)),
});
