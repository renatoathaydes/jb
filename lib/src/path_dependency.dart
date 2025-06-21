import 'config.dart' show DependencySpec;

/// A dependency that refers to a local path.
sealed class PathDependency {
  DependencySpec get spec;

  String get path;

  const PathDependency();

  static PathDependency jar(DependencySpec spec, String path) {
    return JarDependency(spec, path);
  }

  static PathDependency jbuildProject(DependencySpec spec, String path) {
    return ProjectDependency(spec, path);
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

  const ProjectDependency(this.spec, this.path);

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

  const JarDependency(this.spec, this.path);

  @override
  T when<T>({
    required T Function(JarDependency) jar,
    required T Function(ProjectDependency) jbuildProject,
  }) => jar(this);
}
