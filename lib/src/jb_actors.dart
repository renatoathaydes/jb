import 'package:actors/actors.dart';

import 'compilation_path.g.dart';
import 'compute_compilation_path.dart';
import 'config.dart';
import 'dependencies/deps_cache.dart';
import 'jvm_executor.dart';

/// Group of Actors used throughout jb.
final class JbActors {
  final Sendable<JvmExecutorMessage, Object?> jvmExecutor;
  final Sendable<DepsCacheMessage, ResolvedDependencies> depsCache;
  final Sendable<CompilationPathMessage, CompilationPath?> compPath;

  JbActors(this.jvmExecutor, this.depsCache, this.compPath);
}

/// Type adapter required due to lack of covariance in Dart.
final class _JavaCommandSendable implements Sendable<JavaCommand, Object?> {
  final Sendable<JvmExecutorMessage, Object?> _delegate;

  _JavaCommandSendable(this._delegate);

  @override
  Future<Object?> send(JavaCommand message) {
    return _delegate.send(message);
  }
}

extension JvmExecutorExtension on Sendable<JvmExecutorMessage, Object?> {
  Sendable<JavaCommand, Object?> takingJavaCommands() =>
      _JavaCommandSendable(this);
}
