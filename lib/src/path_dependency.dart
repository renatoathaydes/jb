import 'config.dart' show DependencySpec;

/// A dependency that refers to a local path.
mixin PathDependency {
  DependencySpec get spec;

  String get path;

  static PathDependency jar(DependencySpec spec, String path) {
    return JarDependency(spec, path);
  }

  static PathDependency jbuildProject(DependencySpec spec, String path) {
    return ProjectDependency(spec, path);
  }

  T when<T>(
      {required T Function(JarDependency) jar,
      required T Function(ProjectDependency) jbuildProject});
}

class ProjectDependency with PathDependency {
  @override
  final DependencySpec spec;
  @override
  final String path;

  const ProjectDependency(this.spec, this.path);

  @override
  T when<T>(
          {required T Function(JarDependency) jar,
          required T Function(ProjectDependency) jbuildProject}) =>
      jbuildProject(this);
}

class JarDependency with PathDependency {
  @override
  final DependencySpec spec;
  @override
  final String path;

  const JarDependency(this.spec, this.path);

  @override
  T when<T>(
          {required T Function(JarDependency) jar,
          required T Function(ProjectDependency) jbuildProject}) =>
      jar(this);
}
