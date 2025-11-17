import 'package:actors/actors.dart';

import 'compilation_path.g.dart';
import 'compute_compilation_path.dart';
import 'config.dart';
import 'dependencies/deps_cache.dart';
import 'jvm_executor.dart';

/// Group of Actors used throughout jb.
final class JbActors {
  final Sendable<JavaCommand, Object?> jvmExecutor;
  final Sendable<DepsCacheMessage, ResolvedDependencies> depsCache;
  final Sendable<CompilationPathMessage, CompilationPath?> compPath;

  JbActors(this.jvmExecutor, this.depsCache, this.compPath);
}
