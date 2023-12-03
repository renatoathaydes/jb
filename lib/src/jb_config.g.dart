import 'package:collection/collection.dart';
import 'dart:convert';
import 'package:schemake/schemake.dart';

/// jb configuration model.

class JbConfiguration {
  final String? group;
  final String? module;
  final String? name;
  final String? version;
  final String? description;
  final String? url;
  final String? mainClass;
  final String? extensionProject;
  final List<String> sourceDirs;
  final String? outputDir;
  final String? outputJar;
  final List<String> resourceDirs;
  final List<String> repositories;
  final Map<String, DependencySpec> dependencies;
  final Map<String, DependencySpec> processorDependencies;
  final List<String> dependencyExclusionPatterns;
  final List<String> processorDependencyExclusionPatterns;
  final String compileLibsDir;
  final String runtimeLibsDir;
  final String testReportsDir;
  final List<String> javacArgs;
  final List<String> runJavaArgs;
  final List<String> testJavaArgs;
  final Map<String, String> javacEnv;
  final Map<String, String> runJavaEnv;
  final Map<String, String> testJavaEnv;
  final SourceControlManagement? scm;
  final List<Developer> developers;
  final List<String> licenses;
  final Map<String, Object?> properties;
  final Map<String, Object?> extras;
  const JbConfiguration({
    this.group,
    this.module,
    this.name,
    this.version,
    this.description,
    this.url,
    this.mainClass,
    this.extensionProject,
    this.sourceDirs = const ['src'],
    this.outputDir,
    this.outputJar,
    this.resourceDirs = const ['resources'],
    this.repositories = const [],
    this.dependencies = const {},
    this.processorDependencies = const {},
    this.dependencyExclusionPatterns = const [],
    this.processorDependencyExclusionPatterns = const [],
    this.compileLibsDir = 'build/compile-libs',
    this.runtimeLibsDir = 'build/runtime-libs',
    this.testReportsDir = 'build/test-reports',
    this.javacArgs = const [],
    this.runJavaArgs = const [],
    this.testJavaArgs = const [],
    this.javacEnv = const {},
    this.runJavaEnv = const {},
    this.testJavaEnv = const {},
    this.scm,
    this.developers = const [],
    this.licenses = const [],
    this.properties = const {},
    this.extras = const {},
  });
  @override
  String toString() => 'JbConfiguration{'
      'group: "$group", '
      'module: "$module", '
      'name: "$name", '
      'version: "$version", '
      'description: "$description", '
      'url: "$url", '
      'mainClass: "$mainClass", '
      'extensionProject: "$extensionProject", '
      'sourceDirs: $sourceDirs, '
      'outputDir: "$outputDir", '
      'outputJar: "$outputJar", '
      'resourceDirs: $resourceDirs, '
      'repositories: $repositories, '
      'dependencies: $dependencies, '
      'processorDependencies: $processorDependencies, '
      'dependencyExclusionPatterns: $dependencyExclusionPatterns, '
      'processorDependencyExclusionPatterns: $processorDependencyExclusionPatterns, '
      'compileLibsDir: "$compileLibsDir", '
      'runtimeLibsDir: "$runtimeLibsDir", '
      'testReportsDir: "$testReportsDir", '
      'javacArgs: $javacArgs, '
      'runJavaArgs: $runJavaArgs, '
      'testJavaArgs: $testJavaArgs, '
      'javacEnv: $javacEnv, '
      'runJavaEnv: $runJavaEnv, '
      'testJavaEnv: $testJavaEnv, '
      'scm: $scm, '
      'developers: $developers, '
      'licenses: $licenses, '
      'properties: $properties, '
      'extras: $extras'
      '}';
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is JbConfiguration &&
          runtimeType == other.runtimeType &&
          group == other.group &&
          module == other.module &&
          name == other.name &&
          version == other.version &&
          description == other.description &&
          url == other.url &&
          mainClass == other.mainClass &&
          extensionProject == other.extensionProject &&
          const ListEquality<String>().equals(sourceDirs, other.sourceDirs) &&
          outputDir == other.outputDir &&
          outputJar == other.outputJar &&
          const ListEquality<String>()
              .equals(resourceDirs, other.resourceDirs) &&
          const ListEquality<String>()
              .equals(repositories, other.repositories) &&
          const MapEquality<String, DependencySpec>()
              .equals(dependencies, other.dependencies) &&
          const MapEquality<String, DependencySpec>()
              .equals(processorDependencies, other.processorDependencies) &&
          const ListEquality<String>().equals(
              dependencyExclusionPatterns, other.dependencyExclusionPatterns) &&
          const ListEquality<String>().equals(
              processorDependencyExclusionPatterns,
              other.processorDependencyExclusionPatterns) &&
          compileLibsDir == other.compileLibsDir &&
          runtimeLibsDir == other.runtimeLibsDir &&
          testReportsDir == other.testReportsDir &&
          const ListEquality<String>().equals(javacArgs, other.javacArgs) &&
          const ListEquality<String>().equals(runJavaArgs, other.runJavaArgs) &&
          const ListEquality<String>()
              .equals(testJavaArgs, other.testJavaArgs) &&
          const MapEquality<String, String>()
              .equals(javacEnv, other.javacEnv) &&
          const MapEquality<String, String>()
              .equals(runJavaEnv, other.runJavaEnv) &&
          const MapEquality<String, String>()
              .equals(testJavaEnv, other.testJavaEnv) &&
          scm == other.scm &&
          const ListEquality<Developer>()
              .equals(developers, other.developers) &&
          const ListEquality<String>().equals(licenses, other.licenses) &&
          const MapEquality<String, Object?>()
              .equals(properties, other.properties) &&
          const MapEquality<String, Object?>().equals(extras, other.extras);
  @override
  int get hashCode =>
      group.hashCode ^
      module.hashCode ^
      name.hashCode ^
      version.hashCode ^
      description.hashCode ^
      url.hashCode ^
      mainClass.hashCode ^
      extensionProject.hashCode ^
      const ListEquality<String>().hash(sourceDirs) ^
      outputDir.hashCode ^
      outputJar.hashCode ^
      const ListEquality<String>().hash(resourceDirs) ^
      const ListEquality<String>().hash(repositories) ^
      const MapEquality<String, DependencySpec>().hash(dependencies) ^
      const MapEquality<String, DependencySpec>().hash(processorDependencies) ^
      const ListEquality<String>().hash(dependencyExclusionPatterns) ^
      const ListEquality<String>().hash(processorDependencyExclusionPatterns) ^
      compileLibsDir.hashCode ^
      runtimeLibsDir.hashCode ^
      testReportsDir.hashCode ^
      const ListEquality<String>().hash(javacArgs) ^
      const ListEquality<String>().hash(runJavaArgs) ^
      const ListEquality<String>().hash(testJavaArgs) ^
      const MapEquality<String, String>().hash(javacEnv) ^
      const MapEquality<String, String>().hash(runJavaEnv) ^
      const MapEquality<String, String>().hash(testJavaEnv) ^
      scm.hashCode ^
      const ListEquality<Developer>().hash(developers) ^
      const ListEquality<String>().hash(licenses) ^
      const MapEquality<String, Object?>().hash(properties) ^
      const MapEquality<String, Object?>().hash(extras);
  Map<String, Object?> toJson() => {
        if (group != null) 'group': group,
        if (module != null) 'module': module,
        if (name != null) 'name': name,
        if (version != null) 'version': version,
        if (description != null) 'description': description,
        if (url != null) 'url': url,
        if (mainClass != null) 'main-class': mainClass,
        if (extensionProject != null) 'extension-project': extensionProject,
        'source-dirs': sourceDirs,
        if (outputDir != null) 'output-dir': outputDir,
        if (outputJar != null) 'output-jar': outputJar,
        'resource-dirs': resourceDirs,
        'repositories': repositories,
        'dependencies': dependencies,
        'processor-dependencies': processorDependencies,
        'dependency-exclusion-patterns': dependencyExclusionPatterns,
        'processor-dependency-exclusion-patterns':
            processorDependencyExclusionPatterns,
        'compile-libs-dir': compileLibsDir,
        'runtime-libs-dir': runtimeLibsDir,
        'test-reports-dir': testReportsDir,
        'javac-args': javacArgs,
        'run-java-args': runJavaArgs,
        'test-java-args': testJavaArgs,
        'javac-env': javacEnv,
        'run-java-env': runJavaEnv,
        'test-java-env': testJavaEnv,
        if (scm != null) 'scm': scm,
        'developers': developers,
        'licenses': licenses,
        'properties': properties,
        ...extras,
      };
  static JbConfiguration fromJson(Object? value) =>
      const _JbConfigurationJsonReviver().convert(switch (value) {
        String() => jsonDecode(value),
        List<int>() => jsonDecode(utf8.decode(value)),
        _ => value,
      });
}

/// Specification of a dependency.

class DependencySpec {
  final bool transitive;

  /// Scope of a dependency.
  final DependencyScope scope;
  final String? path;
  const DependencySpec({
    this.transitive = true,
    required this.scope,
    this.path,
  });
  @override
  String toString() => 'DependencySpec{'
      'transitive: $transitive, '
      'scope: $scope, '
      'path: "$path"'
      '}';
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DependencySpec &&
          runtimeType == other.runtimeType &&
          transitive == other.transitive &&
          scope == other.scope &&
          path == other.path;
  @override
  int get hashCode => transitive.hashCode ^ scope.hashCode ^ path.hashCode;
  Map<String, Object?> toJson() => {
        'transitive': transitive,
        'scope': scope,
        if (path != null) 'path': path,
      };
  static DependencySpec fromJson(Object? value) =>
      const _DependencySpecJsonReviver().convert(switch (value) {
        String() => jsonDecode(value),
        List<int>() => jsonDecode(utf8.decode(value)),
        _ => value,
      });
}

/// Source control Management settings.

class SourceControlManagement {
  final String connection;
  final String developerConnection;
  final String url;
  const SourceControlManagement({
    required this.connection,
    required this.developerConnection,
    required this.url,
  });
  @override
  String toString() => 'SourceControlManagement{'
      'connection: "$connection", '
      'developerConnection: "$developerConnection", '
      'url: "$url"'
      '}';
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SourceControlManagement &&
          runtimeType == other.runtimeType &&
          connection == other.connection &&
          developerConnection == other.developerConnection &&
          url == other.url;
  @override
  int get hashCode =>
      connection.hashCode ^ developerConnection.hashCode ^ url.hashCode;
  Map<String, Object?> toJson() => {
        'connection': connection,
        'developer-connection': developerConnection,
        'url': url,
      };
  static SourceControlManagement fromJson(Object? value) =>
      const _SourceControlManagementJsonReviver().convert(switch (value) {
        String() => jsonDecode(value),
        List<int>() => jsonDecode(utf8.decode(value)),
        _ => value,
      });
}

/// Developers that have contributed to this project.

class Developer {
  final String name;
  final String email;
  final String organization;
  final String organizationUrl;
  const Developer({
    required this.name,
    required this.email,
    required this.organization,
    required this.organizationUrl,
  });
  @override
  String toString() => 'Developer{'
      'name: "$name", '
      'email: "$email", '
      'organization: "$organization", '
      'organizationUrl: "$organizationUrl"'
      '}';
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Developer &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          email == other.email &&
          organization == other.organization &&
          organizationUrl == other.organizationUrl;
  @override
  int get hashCode =>
      name.hashCode ^
      email.hashCode ^
      organization.hashCode ^
      organizationUrl.hashCode;
  Map<String, Object?> toJson() => {
        'name': name,
        'email': email,
        'organization': organization,
        'organization-url': organizationUrl,
      };
  static Developer fromJson(Object? value) =>
      const _DeveloperJsonReviver().convert(switch (value) {
        String() => jsonDecode(value),
        List<int>() => jsonDecode(utf8.decode(value)),
        _ => value,
      });
}

class _JbConfigurationJsonReviver extends ObjectsBase<JbConfiguration> {
  const _JbConfigurationJsonReviver()
      : super("JbConfiguration",
            unknownPropertiesStrategy: UnknownPropertiesStrategy.keep,
            location: const []);

  @override
  JbConfiguration convert(Object? value) {
    if (value is! Map) throw TypeException(JbConfiguration, value);
    final keys = value.keys.map((key) {
      if (key is! String) {
        throw TypeException(String, key, "object key is not a String");
      }
      return key;
    }).toSet();
    checkRequiredProperties(keys);
    return JbConfiguration(
      group: convertProperty(
          const Nullable<String, Strings>(Strings()), 'group', value),
      module: convertProperty(
          const Nullable<String, Strings>(Strings()), 'module', value),
      name: convertProperty(
          const Nullable<String, Strings>(Strings()), 'name', value),
      version: convertProperty(
          const Nullable<String, Strings>(Strings()), 'version', value),
      description: convertProperty(
          const Nullable<String, Strings>(Strings()), 'description', value),
      url: convertProperty(
          const Nullable<String, Strings>(Strings()), 'url', value),
      mainClass: convertProperty(
          const Nullable<String, Strings>(Strings()), 'main-class', value),
      extensionProject: convertProperty(
          const Nullable<String, Strings>(Strings()),
          'extension-project',
          value),
      sourceDirs: convertProperty(
          const Arrays<String, Strings>(Strings()), 'source-dirs', value),
      outputDir: convertProperty(
          const Nullable<String, Strings>(Strings()), 'output-dir', value),
      outputJar: convertProperty(
          const Nullable<String, Strings>(Strings()), 'output-jar', value),
      resourceDirs: convertProperty(
          const Arrays<String, Strings>(Strings()), 'resource-dirs', value),
      repositories: convertProperty(
          const Arrays<String, Strings>(Strings()), 'repositories', value),
      dependencies: convertProperty(
          const Maps('Map', valueType: _DependencySpecJsonReviver()),
          'dependencies',
          value),
      processorDependencies: convertProperty(
          const Maps('Map', valueType: _DependencySpecJsonReviver()),
          'processor-dependencies',
          value),
      dependencyExclusionPatterns: convertProperty(
          const Arrays<String, Strings>(Strings()),
          'dependency-exclusion-patterns',
          value),
      processorDependencyExclusionPatterns: convertProperty(
          const Arrays<String, Strings>(Strings()),
          'processor-dependency-exclusion-patterns',
          value),
      compileLibsDir:
          convertProperty(const Strings(), 'compile-libs-dir', value),
      runtimeLibsDir:
          convertProperty(const Strings(), 'runtime-libs-dir', value),
      testReportsDir:
          convertProperty(const Strings(), 'test-reports-dir', value),
      javacArgs: convertProperty(
          const Arrays<String, Strings>(Strings()), 'javac-args', value),
      runJavaArgs: convertProperty(
          const Arrays<String, Strings>(Strings()), 'run-java-args', value),
      testJavaArgs: convertProperty(
          const Arrays<String, Strings>(Strings()), 'test-java-args', value),
      javacEnv: convertProperty(
          const Maps('Map', valueType: Strings()), 'javac-env', value),
      runJavaEnv: convertProperty(
          const Maps('Map', valueType: Strings()), 'run-java-env', value),
      testJavaEnv: convertProperty(
          const Maps('Map', valueType: Strings()), 'test-java-env', value),
      scm: convertProperty(
          const Nullable<SourceControlManagement,
                  _SourceControlManagementJsonReviver>(
              _SourceControlManagementJsonReviver()),
          'scm',
          value),
      developers: convertProperty(
          const Arrays<Developer, _DeveloperJsonReviver>(
              _DeveloperJsonReviver()),
          'developers',
          value),
      licenses: convertProperty(
          const Arrays<String, Strings>(Strings()), 'licenses', value),
      properties: convertProperty(
          const Objects('Map', {},
              unknownPropertiesStrategy: UnknownPropertiesStrategy.keep),
          'properties',
          value),
      extras: _unknownPropertiesMap(value),
    );
  }

  @override
  Converter<Object?, Object?>? getPropertyConverter(String property) {
    switch (property) {
      case 'group':
        return const Nullable<String, Strings>(Strings());
      case 'module':
        return const Nullable<String, Strings>(Strings());
      case 'name':
        return const Nullable<String, Strings>(Strings());
      case 'version':
        return const Nullable<String, Strings>(Strings());
      case 'description':
        return const Nullable<String, Strings>(Strings());
      case 'url':
        return const Nullable<String, Strings>(Strings());
      case 'main-class':
        return const Nullable<String, Strings>(Strings());
      case 'extension-project':
        return const Nullable<String, Strings>(Strings());
      case 'source-dirs':
        return const Arrays<String, Strings>(Strings());
      case 'output-dir':
        return const Nullable<String, Strings>(Strings());
      case 'output-jar':
        return const Nullable<String, Strings>(Strings());
      case 'resource-dirs':
        return const Arrays<String, Strings>(Strings());
      case 'repositories':
        return const Arrays<String, Strings>(Strings());
      case 'dependencies':
        return const Maps('Map', valueType: _DependencySpecJsonReviver());
      case 'processor-dependencies':
        return const Maps('Map', valueType: _DependencySpecJsonReviver());
      case 'dependency-exclusion-patterns':
        return const Arrays<String, Strings>(Strings());
      case 'processor-dependency-exclusion-patterns':
        return const Arrays<String, Strings>(Strings());
      case 'compile-libs-dir':
        return const Strings();
      case 'runtime-libs-dir':
        return const Strings();
      case 'test-reports-dir':
        return const Strings();
      case 'javac-args':
        return const Arrays<String, Strings>(Strings());
      case 'run-java-args':
        return const Arrays<String, Strings>(Strings());
      case 'test-java-args':
        return const Arrays<String, Strings>(Strings());
      case 'javac-env':
        return const Maps('Map', valueType: Strings());
      case 'run-java-env':
        return const Maps('Map', valueType: Strings());
      case 'test-java-env':
        return const Maps('Map', valueType: Strings());
      case 'scm':
        return const Nullable<SourceControlManagement,
                _SourceControlManagementJsonReviver>(
            _SourceControlManagementJsonReviver());
      case 'developers':
        return const Arrays<Developer, _DeveloperJsonReviver>(
            _DeveloperJsonReviver());
      case 'licenses':
        return const Arrays<String, Strings>(Strings());
      case 'properties':
        return const Objects('Map', {},
            unknownPropertiesStrategy: UnknownPropertiesStrategy.keep);
      default:
        return null;
    }
  }

  @override
  Iterable<String> getRequiredProperties() {
    return const {
      'source-dirs',
      'resource-dirs',
      'repositories',
      'dependencies',
      'processor-dependencies',
      'dependency-exclusion-patterns',
      'processor-dependency-exclusion-patterns',
      'compile-libs-dir',
      'runtime-libs-dir',
      'test-reports-dir',
      'javac-args',
      'run-java-args',
      'test-java-args',
      'javac-env',
      'run-java-env',
      'test-java-env',
      'developers',
      'licenses',
      'properties'
    };
  }

  @override
  String toString() => 'JbConfiguration';
  Map<String, Object?> _unknownPropertiesMap(Map<Object?, Object?> value) {
    final result = <String, Object?>{};
    const knownProperties = {
      'group',
      'module',
      'name',
      'version',
      'description',
      'url',
      'main-class',
      'extension-project',
      'source-dirs',
      'output-dir',
      'output-jar',
      'resource-dirs',
      'repositories',
      'dependencies',
      'processor-dependencies',
      'dependency-exclusion-patterns',
      'processor-dependency-exclusion-patterns',
      'compile-libs-dir',
      'runtime-libs-dir',
      'test-reports-dir',
      'javac-args',
      'run-java-args',
      'test-java-args',
      'javac-env',
      'run-java-env',
      'test-java-env',
      'scm',
      'developers',
      'licenses',
      'properties'
    };
    for (final entry in value.entries) {
      final key = entry.key;
      if (!knownProperties.contains(key)) {
        if (key is! String) {
          throw TypeException(String, key, "object key is not a String");
        }
        result[key] = entry.value;
      }
    }
    return result;
  }
}

enum DependencyScope {
  /// dependency is required both at compile-time and runtime.
  all,

  /// dependency is required at compile-time, but not runtime.
  compileOnly,

  /// dependency is required at runtime, but not compile-time.
  runtimeOnly,
  ;

  static DependencyScope from(String s) => switch (s) {
        'all' => all,
        'compile-only' => compileOnly,
        'runtime-only' => runtimeOnly,
        _ => throw ValidationException([
            'value not allowed for DependencyScope: "$s" - should be one of {all, compile-only, runtime-only}'
          ]),
      };
}

class _DependencyScopeConverter extends Converter<Object?, DependencyScope> {
  const _DependencyScopeConverter();
  @override
  DependencyScope convert(Object? input) {
    return DependencyScope.from(const Strings().convert(input));
  }
}

class _DependencySpecJsonReviver extends ObjectsBase<DependencySpec> {
  const _DependencySpecJsonReviver()
      : super("DependencySpec",
            unknownPropertiesStrategy: UnknownPropertiesStrategy.forbid,
            location: const []);

  @override
  DependencySpec convert(Object? value) {
    if (value is! Map) throw TypeException(DependencySpec, value);
    final keys = value.keys.map((key) {
      if (key is! String) {
        throw TypeException(String, key, "object key is not a String");
      }
      return key;
    }).toSet();
    checkRequiredProperties(keys);
    return DependencySpec(
      transitive: convertProperty(const Bools(), 'transitive', value),
      scope: convertProperty(const _DependencyScopeConverter(), 'scope', value),
      path: convertProperty(
          const Nullable<String, Strings>(Strings()), 'path', value),
    );
  }

  @override
  Converter<Object?, Object?>? getPropertyConverter(String property) {
    switch (property) {
      case 'transitive':
        return const Bools();
      case 'scope':
        return const _DependencyScopeConverter();
      case 'path':
        return const Nullable<String, Strings>(Strings());
      default:
        return null;
    }
  }

  @override
  Iterable<String> getRequiredProperties() {
    return const {'transitive', 'scope'};
  }

  @override
  String toString() => 'DependencySpec';
}

class _SourceControlManagementJsonReviver
    extends ObjectsBase<SourceControlManagement> {
  const _SourceControlManagementJsonReviver()
      : super("SourceControlManagement",
            unknownPropertiesStrategy: UnknownPropertiesStrategy.forbid,
            location: const []);

  @override
  SourceControlManagement convert(Object? value) {
    if (value is! Map) throw TypeException(SourceControlManagement, value);
    final keys = value.keys.map((key) {
      if (key is! String) {
        throw TypeException(String, key, "object key is not a String");
      }
      return key;
    }).toSet();
    checkRequiredProperties(keys);
    return SourceControlManagement(
      connection: convertProperty(const Strings(), 'connection', value),
      developerConnection:
          convertProperty(const Strings(), 'developer-connection', value),
      url: convertProperty(const Strings(), 'url', value),
    );
  }

  @override
  Converter<Object?, Object?>? getPropertyConverter(String property) {
    switch (property) {
      case 'connection':
        return const Strings();
      case 'developer-connection':
        return const Strings();
      case 'url':
        return const Strings();
      default:
        return null;
    }
  }

  @override
  Iterable<String> getRequiredProperties() {
    return const {'connection', 'developer-connection', 'url'};
  }

  @override
  String toString() => 'SourceControlManagement';
}

class _DeveloperJsonReviver extends ObjectsBase<Developer> {
  const _DeveloperJsonReviver()
      : super("Developer",
            unknownPropertiesStrategy: UnknownPropertiesStrategy.forbid,
            location: const []);

  @override
  Developer convert(Object? value) {
    if (value is! Map) throw TypeException(Developer, value);
    final keys = value.keys.map((key) {
      if (key is! String) {
        throw TypeException(String, key, "object key is not a String");
      }
      return key;
    }).toSet();
    checkRequiredProperties(keys);
    return Developer(
      name: convertProperty(const Strings(), 'name', value),
      email: convertProperty(const Strings(), 'email', value),
      organization: convertProperty(const Strings(), 'organization', value),
      organizationUrl:
          convertProperty(const Strings(), 'organization-url', value),
    );
  }

  @override
  Converter<Object?, Object?>? getPropertyConverter(String property) {
    switch (property) {
      case 'name':
        return const Strings();
      case 'email':
        return const Strings();
      case 'organization':
        return const Strings();
      case 'organization-url':
        return const Strings();
      default:
        return null;
    }
  }

  @override
  Iterable<String> getRequiredProperties() {
    return const {'name', 'email', 'organization', 'organization-url'};
  }

  @override
  String toString() => 'Developer';
}
