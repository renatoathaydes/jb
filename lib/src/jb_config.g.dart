import 'package:collection/collection.dart';
import 'dart:convert';
import 'package:schemake/schemake.dart';

/// jb configuration model.

final class JbConfiguration {
  /// Name of the Maven group of this project
  final String? group;

  /// Module name (Maven artifactId)
  final String? module;

  /// Human readable name of this project
  final String? name;

  /// Version of this project
  final String? version;

  /// Description of this project
  final String? description;

  /// Project URL
  final String? url;

  /// Main Java class qualified name
  final String? mainClass;

  /// Manifest file to pass to the jar tool. Use "-" to generate no manifest
  final String? manifest;

  /// Path to a jb extension
  final String? extensionProject;

  /// Java Source directories
  final List<String> sourceDirs;

  /// Class files output directory (mutual exclusive with output-jar)
  final String? outputDir;

  /// Output jar path (mutual exclusive with output-dir)
  final String? outputJar;

  /// Java Resource directories
  final List<String> resourceDirs;

  /// Maven repositories to use for obtaining dependencies
  final List<String> repositories;

  /// Main dependencies of the project.
  final Map<String, DependencySpec?> dependencies;

  /// Java annotation processor dependencies of the project.
  final Map<String, DependencySpec?> processorDependencies;

  /// Transitive dependencies exclusion patterns
  final List<String> dependencyExclusionPatterns;

  /// Transitive annotation processor dependencies exclusion patterns
  final List<String> processorDependencyExclusionPatterns;

  /// Directory to save compile-time dependencies on
  final String compileLibsDir;

  /// Directory to save runtime-only dependencies on
  final String runtimeLibsDir;

  /// Directory to save test reports on
  final String testReportsDir;

  /// Arguments to pass directly to "javac" when compiling Java code
  final List<String> javacArgs;

  /// Arguments to pass directly to "java" when running Java code
  final List<String> runJavaArgs;

  /// Arguments to pass to the test runner
  final List<String> testJavaArgs;

  /// Environment variables to use when running "javac"
  final Map<String, String> javacEnv;

  /// Environment variables to use when running "java"
  final Map<String, String> runJavaEnv;

  /// Environment variables to use when running tests
  final Map<String, String> testJavaEnv;

  /// Source Control Management
  final SourceControlManagement? scm;

  /// List of developers contributing to this project
  final List<Developer> developers;

  /// List of licenses used by this project
  final List<String> licenses;

  /// Configuration properties (can be used in String interpolation on most config values)
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
    this.manifest,
    this.extensionProject,
    this.sourceDirs = const [],
    this.outputDir,
    this.outputJar,
    this.resourceDirs = const [],
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
  String toString() =>
      'JbConfiguration{'
      'group: ${group == null ? "null" : '"$group"'}, '
      'module: ${module == null ? "null" : '"$module"'}, '
      'name: ${name == null ? "null" : '"$name"'}, '
      'version: ${version == null ? "null" : '"$version"'}, '
      'description: ${description == null ? "null" : '"$description"'}, '
      'url: ${url == null ? "null" : '"$url"'}, '
      'mainClass: ${mainClass == null ? "null" : '"$mainClass"'}, '
      'manifest: ${manifest == null ? "null" : '"$manifest"'}, '
      'extensionProject: ${extensionProject == null ? "null" : '"$extensionProject"'}, '
      'sourceDirs: $sourceDirs, '
      'outputDir: ${outputDir == null ? "null" : '"$outputDir"'}, '
      'outputJar: ${outputJar == null ? "null" : '"$outputJar"'}, '
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
          manifest == other.manifest &&
          extensionProject == other.extensionProject &&
          const ListEquality<String>().equals(sourceDirs, other.sourceDirs) &&
          outputDir == other.outputDir &&
          outputJar == other.outputJar &&
          const ListEquality<String>().equals(
            resourceDirs,
            other.resourceDirs,
          ) &&
          const ListEquality<String>().equals(
            repositories,
            other.repositories,
          ) &&
          const MapEquality<String, DependencySpec?>().equals(
            dependencies,
            other.dependencies,
          ) &&
          const MapEquality<String, DependencySpec?>().equals(
            processorDependencies,
            other.processorDependencies,
          ) &&
          const ListEquality<String>().equals(
            dependencyExclusionPatterns,
            other.dependencyExclusionPatterns,
          ) &&
          const ListEquality<String>().equals(
            processorDependencyExclusionPatterns,
            other.processorDependencyExclusionPatterns,
          ) &&
          compileLibsDir == other.compileLibsDir &&
          runtimeLibsDir == other.runtimeLibsDir &&
          testReportsDir == other.testReportsDir &&
          const ListEquality<String>().equals(javacArgs, other.javacArgs) &&
          const ListEquality<String>().equals(runJavaArgs, other.runJavaArgs) &&
          const ListEquality<String>().equals(
            testJavaArgs,
            other.testJavaArgs,
          ) &&
          const MapEquality<String, String>().equals(
            javacEnv,
            other.javacEnv,
          ) &&
          const MapEquality<String, String>().equals(
            runJavaEnv,
            other.runJavaEnv,
          ) &&
          const MapEquality<String, String>().equals(
            testJavaEnv,
            other.testJavaEnv,
          ) &&
          scm == other.scm &&
          const ListEquality<Developer>().equals(
            developers,
            other.developers,
          ) &&
          const ListEquality<String>().equals(licenses, other.licenses) &&
          const MapEquality<String, Object?>().equals(
            properties,
            other.properties,
          ) &&
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
      manifest.hashCode ^
      extensionProject.hashCode ^
      const ListEquality<String>().hash(sourceDirs) ^
      outputDir.hashCode ^
      outputJar.hashCode ^
      const ListEquality<String>().hash(resourceDirs) ^
      const ListEquality<String>().hash(repositories) ^
      const MapEquality<String, DependencySpec?>().hash(dependencies) ^
      const MapEquality<String, DependencySpec?>().hash(processorDependencies) ^
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
  JbConfiguration copyWith({
    String? group,
    String? module,
    String? name,
    String? version,
    String? description,
    String? url,
    String? mainClass,
    String? manifest,
    String? extensionProject,
    List<String>? sourceDirs,
    String? outputDir,
    String? outputJar,
    List<String>? resourceDirs,
    List<String>? repositories,
    Map<String, DependencySpec?>? dependencies,
    Map<String, DependencySpec?>? processorDependencies,
    List<String>? dependencyExclusionPatterns,
    List<String>? processorDependencyExclusionPatterns,
    String? compileLibsDir,
    String? runtimeLibsDir,
    String? testReportsDir,
    List<String>? javacArgs,
    List<String>? runJavaArgs,
    List<String>? testJavaArgs,
    Map<String, String>? javacEnv,
    Map<String, String>? runJavaEnv,
    Map<String, String>? testJavaEnv,
    SourceControlManagement? scm,
    List<Developer>? developers,
    List<String>? licenses,
    Map<String, Object?>? properties,
    Map<String, Object?>? extras,
    bool unsetGroup = false,
    bool unsetModule = false,
    bool unsetName = false,
    bool unsetVersion = false,
    bool unsetDescription = false,
    bool unsetUrl = false,
    bool unsetMainClass = false,
    bool unsetManifest = false,
    bool unsetExtensionProject = false,
    bool unsetOutputDir = false,
    bool unsetOutputJar = false,
    bool unsetScm = false,
  }) {
    return JbConfiguration(
      group: unsetGroup ? null : group ?? this.group,
      module: unsetModule ? null : module ?? this.module,
      name: unsetName ? null : name ?? this.name,
      version: unsetVersion ? null : version ?? this.version,
      description: unsetDescription ? null : description ?? this.description,
      url: unsetUrl ? null : url ?? this.url,
      mainClass: unsetMainClass ? null : mainClass ?? this.mainClass,
      manifest: unsetManifest ? null : manifest ?? this.manifest,
      extensionProject: unsetExtensionProject
          ? null
          : extensionProject ?? this.extensionProject,
      sourceDirs: sourceDirs ?? [...this.sourceDirs],
      outputDir: unsetOutputDir ? null : outputDir ?? this.outputDir,
      outputJar: unsetOutputJar ? null : outputJar ?? this.outputJar,
      resourceDirs: resourceDirs ?? [...this.resourceDirs],
      repositories: repositories ?? [...this.repositories],
      dependencies: dependencies ?? {...this.dependencies},
      processorDependencies:
          processorDependencies ?? {...this.processorDependencies},
      dependencyExclusionPatterns:
          dependencyExclusionPatterns ?? [...this.dependencyExclusionPatterns],
      processorDependencyExclusionPatterns:
          processorDependencyExclusionPatterns ??
          [...this.processorDependencyExclusionPatterns],
      compileLibsDir: compileLibsDir ?? this.compileLibsDir,
      runtimeLibsDir: runtimeLibsDir ?? this.runtimeLibsDir,
      testReportsDir: testReportsDir ?? this.testReportsDir,
      javacArgs: javacArgs ?? [...this.javacArgs],
      runJavaArgs: runJavaArgs ?? [...this.runJavaArgs],
      testJavaArgs: testJavaArgs ?? [...this.testJavaArgs],
      javacEnv: javacEnv ?? {...this.javacEnv},
      runJavaEnv: runJavaEnv ?? {...this.runJavaEnv},
      testJavaEnv: testJavaEnv ?? {...this.testJavaEnv},
      scm: unsetScm ? null : scm ?? this.scm?.copyWith(),
      developers: developers ?? [...this.developers],
      licenses: licenses ?? [...this.licenses],
      properties: properties ?? {...this.properties},
      extras: extras ?? {...this.extras},
    );
  }

  static JbConfiguration fromJson(Object? value) =>
      const _JbConfigurationJsonReviver().convert(switch (value) {
        String() => jsonDecode(value),
        List<int>() => jsonDecode(utf8.decode(value)),
        _ => value,
      });
  Map<String, Object?> toJson() => {
    if (group != null) 'group': group,
    if (module != null) 'module': module,
    if (name != null) 'name': name,
    if (version != null) 'version': version,
    if (description != null) 'description': description,
    if (url != null) 'url': url,
    if (mainClass != null) 'main-class': mainClass,
    if (manifest != null) 'manifest': manifest,
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
}

/// The extra config for a jb task obtained by instantiating the Java task and calling getSummary().

final class ExtensionTaskExtra {
  final List<String> inputs;
  final List<String> outputs;
  final List<String> dependsOn;
  final List<String> dependents;
  const ExtensionTaskExtra({
    required this.inputs,
    required this.outputs,
    required this.dependsOn,
    required this.dependents,
  });
  @override
  String toString() =>
      'ExtensionTaskExtra{'
      'inputs: $inputs, '
      'outputs: $outputs, '
      'dependsOn: $dependsOn, '
      'dependents: $dependents'
      '}';
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExtensionTaskExtra &&
          runtimeType == other.runtimeType &&
          const ListEquality<String>().equals(inputs, other.inputs) &&
          const ListEquality<String>().equals(outputs, other.outputs) &&
          const ListEquality<String>().equals(dependsOn, other.dependsOn) &&
          const ListEquality<String>().equals(dependents, other.dependents);
  @override
  int get hashCode =>
      const ListEquality<String>().hash(inputs) ^
      const ListEquality<String>().hash(outputs) ^
      const ListEquality<String>().hash(dependsOn) ^
      const ListEquality<String>().hash(dependents);
  ExtensionTaskExtra copyWith({
    List<String>? inputs,
    List<String>? outputs,
    List<String>? dependsOn,
    List<String>? dependents,
  }) {
    return ExtensionTaskExtra(
      inputs: inputs ?? [...this.inputs],
      outputs: outputs ?? [...this.outputs],
      dependsOn: dependsOn ?? [...this.dependsOn],
      dependents: dependents ?? [...this.dependents],
    );
  }

  static ExtensionTaskExtra fromJson(Object? value) =>
      const _ExtensionTaskExtraJsonReviver().convert(switch (value) {
        String() => jsonDecode(value),
        List<int>() => jsonDecode(utf8.decode(value)),
        _ => value,
      });
  Map<String, Object?> toJson() => {
    'inputs': inputs,
    'outputs': outputs,
    'dependsOn': dependsOn,
    'dependents': dependents,
  };
}

final class ResolvedDependencies {
  final List<ResolvedDependency> dependencies;
  final List<DependencyWarning> warnings;
  const ResolvedDependencies({
    required this.dependencies,
    required this.warnings,
  });
  @override
  String toString() =>
      'ResolvedDependencies{'
      'dependencies: $dependencies, '
      'warnings: $warnings'
      '}';
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ResolvedDependencies &&
          runtimeType == other.runtimeType &&
          const ListEquality<ResolvedDependency>().equals(
            dependencies,
            other.dependencies,
          ) &&
          const ListEquality<DependencyWarning>().equals(
            warnings,
            other.warnings,
          );
  @override
  int get hashCode =>
      const ListEquality<ResolvedDependency>().hash(dependencies) ^
      const ListEquality<DependencyWarning>().hash(warnings);
  ResolvedDependencies copyWith({
    List<ResolvedDependency>? dependencies,
    List<DependencyWarning>? warnings,
  }) {
    return ResolvedDependencies(
      dependencies: dependencies ?? [...this.dependencies],
      warnings: warnings ?? [...this.warnings],
    );
  }

  static ResolvedDependencies fromJson(Object? value) =>
      const _ResolvedDependenciesJsonReviver().convert(switch (value) {
        String() => jsonDecode(value),
        List<int>() => jsonDecode(utf8.decode(value)),
        _ => value,
      });
  Map<String, Object?> toJson() => {
    'dependencies': dependencies,
    'warnings': warnings,
  };
}

/// Specification of a dependency.

final class DependencySpec {
  final bool transitive;

  /// Scope of a dependency.
  final DependencyScope scope;
  final String? path;
  final List<String> exclusions;
  const DependencySpec({
    this.transitive = true,
    this.scope = DependencyScope.all,
    this.path,
    this.exclusions = const [],
  });
  @override
  String toString() =>
      'DependencySpec{'
      'transitive: $transitive, '
      'scope: $scope, '
      'path: ${path == null ? "null" : '"$path"'}, '
      'exclusions: $exclusions'
      '}';
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DependencySpec &&
          runtimeType == other.runtimeType &&
          transitive == other.transitive &&
          scope == other.scope &&
          path == other.path &&
          const ListEquality<String>().equals(exclusions, other.exclusions);
  @override
  int get hashCode =>
      transitive.hashCode ^
      scope.hashCode ^
      path.hashCode ^
      const ListEquality<String>().hash(exclusions);
  DependencySpec copyWith({
    bool? transitive,
    DependencyScope? scope,
    String? path,
    List<String>? exclusions,
    bool unsetPath = false,
  }) {
    return DependencySpec(
      transitive: transitive ?? this.transitive,
      scope: scope ?? this.scope,
      path: unsetPath ? null : path ?? this.path,
      exclusions: exclusions ?? [...this.exclusions],
    );
  }

  static DependencySpec fromJson(Object? value) =>
      const _DependencySpecJsonReviver().convert(switch (value) {
        String() => jsonDecode(value),
        List<int>() => jsonDecode(utf8.decode(value)),
        _ => value,
      });
  Map<String, Object?> toJson() => {
    'transitive': transitive,
    'scope': scope.name,
    if (path != null) 'path': path,
    'exclusions': exclusions,
  };
}

/// Source control Management settings.

final class SourceControlManagement {
  final String connection;
  final String developerConnection;
  final String url;
  const SourceControlManagement({
    required this.connection,
    required this.developerConnection,
    required this.url,
  });
  @override
  String toString() =>
      'SourceControlManagement{'
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
  SourceControlManagement copyWith({
    String? connection,
    String? developerConnection,
    String? url,
  }) {
    return SourceControlManagement(
      connection: connection ?? this.connection,
      developerConnection: developerConnection ?? this.developerConnection,
      url: url ?? this.url,
    );
  }

  static SourceControlManagement fromJson(Object? value) =>
      const _SourceControlManagementJsonReviver().convert(switch (value) {
        String() => jsonDecode(value),
        List<int>() => jsonDecode(utf8.decode(value)),
        _ => value,
      });
  Map<String, Object?> toJson() => {
    'connection': connection,
    'developer-connection': developerConnection,
    'url': url,
  };
}

/// Developers that have contributed to this project.

final class Developer {
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
  String toString() =>
      'Developer{'
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
  Developer copyWith({
    String? name,
    String? email,
    String? organization,
    String? organizationUrl,
  }) {
    return Developer(
      name: name ?? this.name,
      email: email ?? this.email,
      organization: organization ?? this.organization,
      organizationUrl: organizationUrl ?? this.organizationUrl,
    );
  }

  static Developer fromJson(Object? value) =>
      const _DeveloperJsonReviver().convert(switch (value) {
        String() => jsonDecode(value),
        List<int>() => jsonDecode(utf8.decode(value)),
        _ => value,
      });
  Map<String, Object?> toJson() => {
    'name': name,
    'email': email,
    'organization': organization,
    'organization-url': organizationUrl,
  };
}

class _JbConfigurationJsonReviver extends ObjectsBase<JbConfiguration> {
  const _JbConfigurationJsonReviver()
    : super(
        "JbConfiguration",
        unknownPropertiesStrategy: UnknownPropertiesStrategy.keep,
      );

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
        const Nullable<String, Strings>(Strings()),
        'group',
        value,
      ),
      module: convertProperty(
        const Nullable<String, Strings>(Strings()),
        'module',
        value,
      ),
      name: convertProperty(
        const Nullable<String, Strings>(Strings()),
        'name',
        value,
      ),
      version: convertProperty(
        const Nullable<String, Strings>(Strings()),
        'version',
        value,
      ),
      description: convertProperty(
        const Nullable<String, Strings>(Strings()),
        'description',
        value,
      ),
      url: convertProperty(
        const Nullable<String, Strings>(Strings()),
        'url',
        value,
      ),
      mainClass: convertProperty(
        const Nullable<String, Strings>(Strings()),
        'main-class',
        value,
      ),
      manifest: convertProperty(
        const Nullable<String, Strings>(Strings()),
        'manifest',
        value,
      ),
      extensionProject: convertProperty(
        const Nullable<String, Strings>(Strings()),
        'extension-project',
        value,
      ),
      sourceDirs: convertPropertyOrDefault(
        const Arrays<String, Strings>(Strings()),
        'source-dirs',
        value,
        const [],
      ),
      outputDir: convertProperty(
        const Nullable<String, Strings>(Strings()),
        'output-dir',
        value,
      ),
      outputJar: convertProperty(
        const Nullable<String, Strings>(Strings()),
        'output-jar',
        value,
      ),
      resourceDirs: convertPropertyOrDefault(
        const Arrays<String, Strings>(Strings()),
        'resource-dirs',
        value,
        const [],
      ),
      repositories: convertPropertyOrDefault(
        const Arrays<String, Strings>(Strings()),
        'repositories',
        value,
        const [],
      ),
      dependencies: convertPropertyOrDefault(
        const Maps(
          'Map',
          valueType: Nullable<DependencySpec, _DependencySpecJsonReviver>(
            _DependencySpecJsonReviver(),
          ),
        ),
        'dependencies',
        value,
        const {},
      ),
      processorDependencies: convertPropertyOrDefault(
        const Maps(
          'Map',
          valueType: Nullable<DependencySpec, _DependencySpecJsonReviver>(
            _DependencySpecJsonReviver(),
          ),
        ),
        'processor-dependencies',
        value,
        const {},
      ),
      dependencyExclusionPatterns: convertPropertyOrDefault(
        const Arrays<String, Strings>(Strings()),
        'dependency-exclusion-patterns',
        value,
        const [],
      ),
      processorDependencyExclusionPatterns: convertPropertyOrDefault(
        const Arrays<String, Strings>(Strings()),
        'processor-dependency-exclusion-patterns',
        value,
        const [],
      ),
      compileLibsDir: convertPropertyOrDefault(
        const Strings(),
        'compile-libs-dir',
        value,
        'build/compile-libs',
      ),
      runtimeLibsDir: convertPropertyOrDefault(
        const Strings(),
        'runtime-libs-dir',
        value,
        'build/runtime-libs',
      ),
      testReportsDir: convertPropertyOrDefault(
        const Strings(),
        'test-reports-dir',
        value,
        'build/test-reports',
      ),
      javacArgs: convertPropertyOrDefault(
        const Arrays<String, Strings>(Strings()),
        'javac-args',
        value,
        const [],
      ),
      runJavaArgs: convertPropertyOrDefault(
        const Arrays<String, Strings>(Strings()),
        'run-java-args',
        value,
        const [],
      ),
      testJavaArgs: convertPropertyOrDefault(
        const Arrays<String, Strings>(Strings()),
        'test-java-args',
        value,
        const [],
      ),
      javacEnv: convertPropertyOrDefault(
        const Maps('Map', valueType: Strings()),
        'javac-env',
        value,
        const {},
      ),
      runJavaEnv: convertPropertyOrDefault(
        const Maps('Map', valueType: Strings()),
        'run-java-env',
        value,
        const {},
      ),
      testJavaEnv: convertPropertyOrDefault(
        const Maps('Map', valueType: Strings()),
        'test-java-env',
        value,
        const {},
      ),
      scm: convertProperty(
        const Nullable<
          SourceControlManagement,
          _SourceControlManagementJsonReviver
        >(_SourceControlManagementJsonReviver()),
        'scm',
        value,
      ),
      developers: convertPropertyOrDefault(
        const Arrays<Developer, _DeveloperJsonReviver>(_DeveloperJsonReviver()),
        'developers',
        value,
        const [],
      ),
      licenses: convertPropertyOrDefault(
        const Arrays<String, Strings>(Strings()),
        'licenses',
        value,
        const [],
      ),
      properties: convertPropertyOrDefault(
        const Objects(
          'Map',
          {},
          unknownPropertiesStrategy: UnknownPropertiesStrategy.keep,
        ),
        'properties',
        value,
        const {},
      ),
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
      case 'manifest':
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
        return const Maps(
          'Map',
          valueType: Nullable<DependencySpec, _DependencySpecJsonReviver>(
            _DependencySpecJsonReviver(),
          ),
        );
      case 'processor-dependencies':
        return const Maps(
          'Map',
          valueType: Nullable<DependencySpec, _DependencySpecJsonReviver>(
            _DependencySpecJsonReviver(),
          ),
        );
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
        return const Nullable<
          SourceControlManagement,
          _SourceControlManagementJsonReviver
        >(_SourceControlManagementJsonReviver());
      case 'developers':
        return const Arrays<Developer, _DeveloperJsonReviver>(
          _DeveloperJsonReviver(),
        );
      case 'licenses':
        return const Arrays<String, Strings>(Strings());
      case 'properties':
        return const Objects(
          'Map',
          {},
          unknownPropertiesStrategy: UnknownPropertiesStrategy.keep,
        );
      default:
        return null;
    }
  }

  @override
  Iterable<String> getRequiredProperties() {
    return const {};
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
      'manifest',
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
      'properties',
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

class _ExtensionTaskExtraJsonReviver extends ObjectsBase<ExtensionTaskExtra> {
  const _ExtensionTaskExtraJsonReviver()
    : super(
        "ExtensionTaskExtra",
        unknownPropertiesStrategy: UnknownPropertiesStrategy.forbid,
      );

  @override
  ExtensionTaskExtra convert(Object? value) {
    if (value is! Map) throw TypeException(ExtensionTaskExtra, value);
    final keys = value.keys.map((key) {
      if (key is! String) {
        throw TypeException(String, key, "object key is not a String");
      }
      return key;
    }).toSet();
    checkRequiredProperties(keys);
    const knownProperties = {'inputs', 'outputs', 'dependsOn', 'dependents'};
    final unknownKey = keys
        .where((k) => !knownProperties.contains(k))
        .firstOrNull;
    if (unknownKey != null) {
      throw UnknownPropertyException([unknownKey], ExtensionTaskExtra);
    }
    return ExtensionTaskExtra(
      inputs: convertProperty(
        const Arrays<String, Strings>(Strings()),
        'inputs',
        value,
      ),
      outputs: convertProperty(
        const Arrays<String, Strings>(Strings()),
        'outputs',
        value,
      ),
      dependsOn: convertProperty(
        const Arrays<String, Strings>(Strings()),
        'dependsOn',
        value,
      ),
      dependents: convertProperty(
        const Arrays<String, Strings>(Strings()),
        'dependents',
        value,
      ),
    );
  }

  @override
  Converter<Object?, Object?>? getPropertyConverter(String property) {
    switch (property) {
      case 'inputs':
        return const Arrays<String, Strings>(Strings());
      case 'outputs':
        return const Arrays<String, Strings>(Strings());
      case 'dependsOn':
        return const Arrays<String, Strings>(Strings());
      case 'dependents':
        return const Arrays<String, Strings>(Strings());
      default:
        return null;
    }
  }

  @override
  Iterable<String> getRequiredProperties() {
    return const {'inputs', 'outputs', 'dependsOn', 'dependents'};
  }

  @override
  String toString() => 'ExtensionTaskExtra';
}

final class ResolvedDependency {
  final String artifact;
  final DependencySpec spec;
  final String sha1;
  final List<DependencyLicense>? licenses;
  final DependencyKind kind;
  final bool isDirect;
  final List<String> dependencies;
  const ResolvedDependency({
    required this.artifact,
    required this.spec,
    required this.sha1,
    this.licenses,
    required this.kind,
    required this.isDirect,
    required this.dependencies,
  });
  @override
  String toString() =>
      'ResolvedDependency{'
      'artifact: "$artifact", '
      'spec: $spec, '
      'sha1: "$sha1", '
      'licenses: $licenses, '
      'kind: $kind, '
      'isDirect: $isDirect, '
      'dependencies: $dependencies'
      '}';
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ResolvedDependency &&
          runtimeType == other.runtimeType &&
          artifact == other.artifact &&
          spec == other.spec &&
          sha1 == other.sha1 &&
          const ListEquality<DependencyLicense>().equals(
            licenses,
            other.licenses,
          ) &&
          kind == other.kind &&
          isDirect == other.isDirect &&
          const ListEquality<String>().equals(dependencies, other.dependencies);
  @override
  int get hashCode =>
      artifact.hashCode ^
      spec.hashCode ^
      sha1.hashCode ^
      const ListEquality<DependencyLicense>().hash(licenses) ^
      kind.hashCode ^
      isDirect.hashCode ^
      const ListEquality<String>().hash(dependencies);
  ResolvedDependency copyWith({
    String? artifact,
    DependencySpec? spec,
    String? sha1,
    List<DependencyLicense>? licenses,
    DependencyKind? kind,
    bool? isDirect,
    List<String>? dependencies,
    bool unsetLicenses = false,
  }) {
    return ResolvedDependency(
      artifact: artifact ?? this.artifact,
      spec: spec ?? this.spec.copyWith(),
      sha1: sha1 ?? this.sha1,
      licenses: unsetLicenses
          ? null
          : licenses ?? (this.licenses == null ? null : [...this.licenses!]),
      kind: kind ?? this.kind,
      isDirect: isDirect ?? this.isDirect,
      dependencies: dependencies ?? [...this.dependencies],
    );
  }

  static ResolvedDependency fromJson(Object? value) =>
      const _ResolvedDependencyJsonReviver().convert(switch (value) {
        String() => jsonDecode(value),
        List<int>() => jsonDecode(utf8.decode(value)),
        _ => value,
      });
  Map<String, Object?> toJson() => {
    'artifact': artifact,
    'spec': spec,
    'sha1': sha1,
    if (licenses != null) 'licenses': licenses,
    'kind': kind.name,
    'isDirect': isDirect,
    'dependencies': dependencies,
  };
}

final class DependencyWarning {
  final String artifact;
  final List<VersionConflict> versionConflicts;
  const DependencyWarning({
    required this.artifact,
    required this.versionConflicts,
  });
  @override
  String toString() =>
      'DependencyWarning{'
      'artifact: "$artifact", '
      'versionConflicts: $versionConflicts'
      '}';
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DependencyWarning &&
          runtimeType == other.runtimeType &&
          artifact == other.artifact &&
          const ListEquality<VersionConflict>().equals(
            versionConflicts,
            other.versionConflicts,
          );
  @override
  int get hashCode =>
      artifact.hashCode ^
      const ListEquality<VersionConflict>().hash(versionConflicts);
  DependencyWarning copyWith({
    String? artifact,
    List<VersionConflict>? versionConflicts,
  }) {
    return DependencyWarning(
      artifact: artifact ?? this.artifact,
      versionConflicts: versionConflicts ?? [...this.versionConflicts],
    );
  }

  static DependencyWarning fromJson(Object? value) =>
      const _DependencyWarningJsonReviver().convert(switch (value) {
        String() => jsonDecode(value),
        List<int>() => jsonDecode(utf8.decode(value)),
        _ => value,
      });
  Map<String, Object?> toJson() => {
    'artifact': artifact,
    'versionConflicts': versionConflicts,
  };
}

class _ResolvedDependenciesJsonReviver
    extends ObjectsBase<ResolvedDependencies> {
  const _ResolvedDependenciesJsonReviver()
    : super(
        "ResolvedDependencies",
        unknownPropertiesStrategy: UnknownPropertiesStrategy.forbid,
      );

  @override
  ResolvedDependencies convert(Object? value) {
    if (value is! Map) throw TypeException(ResolvedDependencies, value);
    final keys = value.keys.map((key) {
      if (key is! String) {
        throw TypeException(String, key, "object key is not a String");
      }
      return key;
    }).toSet();
    checkRequiredProperties(keys);
    const knownProperties = {'dependencies', 'warnings'};
    final unknownKey = keys
        .where((k) => !knownProperties.contains(k))
        .firstOrNull;
    if (unknownKey != null) {
      throw UnknownPropertyException([unknownKey], ResolvedDependencies);
    }
    return ResolvedDependencies(
      dependencies: convertProperty(
        const Arrays<ResolvedDependency, _ResolvedDependencyJsonReviver>(
          _ResolvedDependencyJsonReviver(),
        ),
        'dependencies',
        value,
      ),
      warnings: convertProperty(
        const Arrays<DependencyWarning, _DependencyWarningJsonReviver>(
          _DependencyWarningJsonReviver(),
        ),
        'warnings',
        value,
      ),
    );
  }

  @override
  Converter<Object?, Object?>? getPropertyConverter(String property) {
    switch (property) {
      case 'dependencies':
        return const Arrays<ResolvedDependency, _ResolvedDependencyJsonReviver>(
          _ResolvedDependencyJsonReviver(),
        );
      case 'warnings':
        return const Arrays<DependencyWarning, _DependencyWarningJsonReviver>(
          _DependencyWarningJsonReviver(),
        );
      default:
        return null;
    }
  }

  @override
  Iterable<String> getRequiredProperties() {
    return const {'dependencies', 'warnings'};
  }

  @override
  String toString() => 'ResolvedDependencies';
}

enum DependencyScope {
  /// dependency is required both at compile-time and runtime.
  all,

  /// dependency is required at compile-time, but not runtime.
  compileOnly,

  /// dependency is required at runtime, but not compile-time.
  runtimeOnly;

  String get name => switch (this) {
    all => 'all',
    compileOnly => 'compile-only',
    runtimeOnly => 'runtime-only',
  };
  static DependencyScope from(String s) => switch (s) {
    'all' => all,
    'compile-only' => compileOnly,
    'runtime-only' => runtimeOnly,
    _ => throw ValidationException([
      'value not allowed for DependencyScope: "$s" - should be one of {all, compile-only, runtime-only}',
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
    : super(
        "DependencySpec",
        unknownPropertiesStrategy: UnknownPropertiesStrategy.forbid,
      );

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
    const knownProperties = {'transitive', 'scope', 'path', 'exclusions'};
    final unknownKey = keys
        .where((k) => !knownProperties.contains(k))
        .firstOrNull;
    if (unknownKey != null) {
      throw UnknownPropertyException([unknownKey], DependencySpec);
    }
    return DependencySpec(
      transitive: convertPropertyOrDefault(
        const Bools(),
        'transitive',
        value,
        true,
      ),
      scope: convertPropertyOrDefault(
        const _DependencyScopeConverter(),
        'scope',
        value,
        DependencyScope.all,
      ),
      path: convertProperty(
        const Nullable<String, Strings>(Strings()),
        'path',
        value,
      ),
      exclusions: convertPropertyOrDefault(
        const Arrays<String, Strings>(Strings()),
        'exclusions',
        value,
        const [],
      ),
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
      case 'exclusions':
        return const Arrays<String, Strings>(Strings());
      default:
        return null;
    }
  }

  @override
  Iterable<String> getRequiredProperties() {
    return const {};
  }

  @override
  String toString() => 'DependencySpec';
}

class _SourceControlManagementJsonReviver
    extends ObjectsBase<SourceControlManagement> {
  const _SourceControlManagementJsonReviver()
    : super(
        "SourceControlManagement",
        unknownPropertiesStrategy: UnknownPropertiesStrategy.forbid,
      );

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
    const knownProperties = {'connection', 'developer-connection', 'url'};
    final unknownKey = keys
        .where((k) => !knownProperties.contains(k))
        .firstOrNull;
    if (unknownKey != null) {
      throw UnknownPropertyException([unknownKey], SourceControlManagement);
    }
    return SourceControlManagement(
      connection: convertProperty(const Strings(), 'connection', value),
      developerConnection: convertProperty(
        const Strings(),
        'developer-connection',
        value,
      ),
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
    : super(
        "Developer",
        unknownPropertiesStrategy: UnknownPropertiesStrategy.forbid,
      );

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
    const knownProperties = {
      'name',
      'email',
      'organization',
      'organization-url',
    };
    final unknownKey = keys
        .where((k) => !knownProperties.contains(k))
        .firstOrNull;
    if (unknownKey != null) {
      throw UnknownPropertyException([unknownKey], Developer);
    }
    return Developer(
      name: convertProperty(const Strings(), 'name', value),
      email: convertProperty(const Strings(), 'email', value),
      organization: convertProperty(const Strings(), 'organization', value),
      organizationUrl: convertProperty(
        const Strings(),
        'organization-url',
        value,
      ),
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

final class DependencyLicense {
  final String name;
  final String url;
  const DependencyLicense({required this.name, required this.url});
  @override
  String toString() =>
      'DependencyLicense{'
      'name: "$name", '
      'url: "$url"'
      '}';
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DependencyLicense &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          url == other.url;
  @override
  int get hashCode => name.hashCode ^ url.hashCode;
  DependencyLicense copyWith({String? name, String? url}) {
    return DependencyLicense(name: name ?? this.name, url: url ?? this.url);
  }

  static DependencyLicense fromJson(Object? value) =>
      const _DependencyLicenseJsonReviver().convert(switch (value) {
        String() => jsonDecode(value),
        List<int>() => jsonDecode(utf8.decode(value)),
        _ => value,
      });
  Map<String, Object?> toJson() => {'name': name, 'url': url};
}

enum DependencyKind {
  localJar,
  localProject,
  maven;

  String get name => switch (this) {
    localJar => 'localJar',
    localProject => 'localProject',
    maven => 'maven',
  };
  static DependencyKind from(String s) => switch (s) {
    'localJar' => localJar,
    'localProject' => localProject,
    'maven' => maven,
    _ => throw ValidationException([
      'value not allowed for DependencyKind: "$s" - should be one of {localJar, localProject, maven}',
    ]),
  };
}

class _DependencyKindConverter extends Converter<Object?, DependencyKind> {
  const _DependencyKindConverter();
  @override
  DependencyKind convert(Object? input) {
    return DependencyKind.from(const Strings().convert(input));
  }
}

class _ResolvedDependencyJsonReviver extends ObjectsBase<ResolvedDependency> {
  const _ResolvedDependencyJsonReviver()
    : super(
        "ResolvedDependency",
        unknownPropertiesStrategy: UnknownPropertiesStrategy.forbid,
      );

  @override
  ResolvedDependency convert(Object? value) {
    if (value is! Map) throw TypeException(ResolvedDependency, value);
    final keys = value.keys.map((key) {
      if (key is! String) {
        throw TypeException(String, key, "object key is not a String");
      }
      return key;
    }).toSet();
    checkRequiredProperties(keys);
    const knownProperties = {
      'artifact',
      'spec',
      'sha1',
      'licenses',
      'kind',
      'isDirect',
      'dependencies',
    };
    final unknownKey = keys
        .where((k) => !knownProperties.contains(k))
        .firstOrNull;
    if (unknownKey != null) {
      throw UnknownPropertyException([unknownKey], ResolvedDependency);
    }
    return ResolvedDependency(
      artifact: convertProperty(const Strings(), 'artifact', value),
      spec: convertProperty(const _DependencySpecJsonReviver(), 'spec', value),
      sha1: convertProperty(const Strings(), 'sha1', value),
      licenses: convertProperty(
        const Nullable<
          List<DependencyLicense>,
          Arrays<DependencyLicense, _DependencyLicenseJsonReviver>
        >(
          Arrays<DependencyLicense, _DependencyLicenseJsonReviver>(
            _DependencyLicenseJsonReviver(),
          ),
        ),
        'licenses',
        value,
      ),
      kind: convertProperty(const _DependencyKindConverter(), 'kind', value),
      isDirect: convertProperty(const Bools(), 'isDirect', value),
      dependencies: convertProperty(
        const Arrays<String, Strings>(Strings()),
        'dependencies',
        value,
      ),
    );
  }

  @override
  Converter<Object?, Object?>? getPropertyConverter(String property) {
    switch (property) {
      case 'artifact':
        return const Strings();
      case 'spec':
        return const _DependencySpecJsonReviver();
      case 'sha1':
        return const Strings();
      case 'licenses':
        return const Nullable<
          List<DependencyLicense>,
          Arrays<DependencyLicense, _DependencyLicenseJsonReviver>
        >(
          Arrays<DependencyLicense, _DependencyLicenseJsonReviver>(
            _DependencyLicenseJsonReviver(),
          ),
        );
      case 'kind':
        return const _DependencyKindConverter();
      case 'isDirect':
        return const Bools();
      case 'dependencies':
        return const Arrays<String, Strings>(Strings());
      default:
        return null;
    }
  }

  @override
  Iterable<String> getRequiredProperties() {
    return const {
      'artifact',
      'spec',
      'sha1',
      'kind',
      'isDirect',
      'dependencies',
    };
  }

  @override
  String toString() => 'ResolvedDependency';
}

final class VersionConflict {
  final String version;
  final List<String> requestedBy;
  const VersionConflict({required this.version, required this.requestedBy});
  @override
  String toString() =>
      'VersionConflict{'
      'version: "$version", '
      'requestedBy: $requestedBy'
      '}';
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VersionConflict &&
          runtimeType == other.runtimeType &&
          version == other.version &&
          const ListEquality<String>().equals(requestedBy, other.requestedBy);
  @override
  int get hashCode =>
      version.hashCode ^ const ListEquality<String>().hash(requestedBy);
  VersionConflict copyWith({String? version, List<String>? requestedBy}) {
    return VersionConflict(
      version: version ?? this.version,
      requestedBy: requestedBy ?? [...this.requestedBy],
    );
  }

  static VersionConflict fromJson(Object? value) =>
      const _VersionConflictJsonReviver().convert(switch (value) {
        String() => jsonDecode(value),
        List<int>() => jsonDecode(utf8.decode(value)),
        _ => value,
      });
  Map<String, Object?> toJson() => {
    'version': version,
    'requestedBy': requestedBy,
  };
}

class _DependencyWarningJsonReviver extends ObjectsBase<DependencyWarning> {
  const _DependencyWarningJsonReviver()
    : super(
        "DependencyWarning",
        unknownPropertiesStrategy: UnknownPropertiesStrategy.forbid,
      );

  @override
  DependencyWarning convert(Object? value) {
    if (value is! Map) throw TypeException(DependencyWarning, value);
    final keys = value.keys.map((key) {
      if (key is! String) {
        throw TypeException(String, key, "object key is not a String");
      }
      return key;
    }).toSet();
    checkRequiredProperties(keys);
    const knownProperties = {'artifact', 'versionConflicts'};
    final unknownKey = keys
        .where((k) => !knownProperties.contains(k))
        .firstOrNull;
    if (unknownKey != null) {
      throw UnknownPropertyException([unknownKey], DependencyWarning);
    }
    return DependencyWarning(
      artifact: convertProperty(const Strings(), 'artifact', value),
      versionConflicts: convertProperty(
        const Arrays<VersionConflict, _VersionConflictJsonReviver>(
          _VersionConflictJsonReviver(),
        ),
        'versionConflicts',
        value,
      ),
    );
  }

  @override
  Converter<Object?, Object?>? getPropertyConverter(String property) {
    switch (property) {
      case 'artifact':
        return const Strings();
      case 'versionConflicts':
        return const Arrays<VersionConflict, _VersionConflictJsonReviver>(
          _VersionConflictJsonReviver(),
        );
      default:
        return null;
    }
  }

  @override
  Iterable<String> getRequiredProperties() {
    return const {'artifact', 'versionConflicts'};
  }

  @override
  String toString() => 'DependencyWarning';
}

class _DependencyLicenseJsonReviver extends ObjectsBase<DependencyLicense> {
  const _DependencyLicenseJsonReviver()
    : super(
        "DependencyLicense",
        unknownPropertiesStrategy: UnknownPropertiesStrategy.forbid,
      );

  @override
  DependencyLicense convert(Object? value) {
    if (value is! Map) throw TypeException(DependencyLicense, value);
    final keys = value.keys.map((key) {
      if (key is! String) {
        throw TypeException(String, key, "object key is not a String");
      }
      return key;
    }).toSet();
    checkRequiredProperties(keys);
    const knownProperties = {'name', 'url'};
    final unknownKey = keys
        .where((k) => !knownProperties.contains(k))
        .firstOrNull;
    if (unknownKey != null) {
      throw UnknownPropertyException([unknownKey], DependencyLicense);
    }
    return DependencyLicense(
      name: convertProperty(const Strings(), 'name', value),
      url: convertProperty(const Strings(), 'url', value),
    );
  }

  @override
  Converter<Object?, Object?>? getPropertyConverter(String property) {
    switch (property) {
      case 'name':
        return const Strings();
      case 'url':
        return const Strings();
      default:
        return null;
    }
  }

  @override
  Iterable<String> getRequiredProperties() {
    return const {'name', 'url'};
  }

  @override
  String toString() => 'DependencyLicense';
}

class _VersionConflictJsonReviver extends ObjectsBase<VersionConflict> {
  const _VersionConflictJsonReviver()
    : super(
        "VersionConflict",
        unknownPropertiesStrategy: UnknownPropertiesStrategy.forbid,
      );

  @override
  VersionConflict convert(Object? value) {
    if (value is! Map) throw TypeException(VersionConflict, value);
    final keys = value.keys.map((key) {
      if (key is! String) {
        throw TypeException(String, key, "object key is not a String");
      }
      return key;
    }).toSet();
    checkRequiredProperties(keys);
    const knownProperties = {'version', 'requestedBy'};
    final unknownKey = keys
        .where((k) => !knownProperties.contains(k))
        .firstOrNull;
    if (unknownKey != null) {
      throw UnknownPropertyException([unknownKey], VersionConflict);
    }
    return VersionConflict(
      version: convertProperty(const Strings(), 'version', value),
      requestedBy: convertProperty(
        const Arrays<String, Strings>(Strings()),
        'requestedBy',
        value,
      ),
    );
  }

  @override
  Converter<Object?, Object?>? getPropertyConverter(String property) {
    switch (property) {
      case 'version':
        return const Strings();
      case 'requestedBy':
        return const Arrays<String, Strings>(Strings());
      default:
        return null;
    }
  }

  @override
  Iterable<String> getRequiredProperties() {
    return const {'version', 'requestedBy'};
  }

  @override
  String toString() => 'VersionConflict';
}
