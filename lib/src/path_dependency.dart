import 'config.dart' show DependencySpec;

/// A dependency that refers to a local path.
sealed class PathDependency {
  final String artifact;
  DependencySpec get spec;

  String get path;

  const PathDependency(this.artifact);

  static PathDependency jar(String artifact, DependencySpec spec, String path) {
    return JarDependency(artifact, spec, path);
  }

  static PathDependency jbuildProject(
    String artifact,
    DependencySpec spec,
    String path,
  ) {
    return ProjectDependency(artifact, spec, path);
  }

  T when<T>({
    required T Function(JarDependency) jar,
    required T Function(ProjectDependency) jbuildProject,
  });
}

final class ProjectDependency extends PathDependency {
  @override
  final DependencySpec spec;
  @override
  final String path;

  const ProjectDependency(super.artifact, this.spec, this.path);

  @override
  T when<T>({
    required T Function(JarDependency) jar,
    required T Function(ProjectDependency) jbuildProject,
  }) => jbuildProject(this);
}

final class JarDependency extends PathDependency {
  @override
  final DependencySpec spec;
  @override
  final String path;

  const JarDependency(super.artifact, this.spec, this.path);

  @override
  T when<T>({
    required T Function(JarDependency) jar,
    required T Function(ProjectDependency) jbuildProject,
  }) => jar(this);
}
