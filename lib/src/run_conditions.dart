import 'package:dartle/dartle.dart';

/// A [RunCondition] that always fails the build if checked.
///
/// This allows forbidding tasks to run if certain conditions are not met.
class CannotRun with RunCondition {
  final String because;

  const CannotRun(this.because);

  @override
  void postRun(TaskResult result) {}

  @override
  bool shouldRun(TaskInvocation invocation) {
    failBuild(reason: because);
  }

  @override
  String toString() {
    return 'CannotRun{because: $because}';
  }
}
