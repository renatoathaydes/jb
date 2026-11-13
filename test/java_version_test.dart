import 'package:actors/actors.dart' show Sendable;
import 'package:dartle/dartle.dart' show DartleException;
import 'package:jb/src/compilation_path.g.dart';
import 'package:jb/src/compute_compilation_path.dart';
import 'package:jb/src/java_version.dart';
import 'package:jb/src/jvm_executor.dart';
import 'package:jb/src/tasks.dart' show checkDepsJavaVersion;
import 'package:test/test.dart';

/// Answers the current Java version and nothing else.
final class _FakeJvm with Sendable<JvmExecutorMessage, Object?> {
  final String version;

  _FakeJvm(this.version);

  @override
  Future<Object?> send(JvmExecutorMessage message) async {
    if (message is CurrentJavaVersion) return version;
    throw UnsupportedError('unexpected message: $message');
  }
}

/// Answers the given compilation path for any request.
final class _FakeCompPath
    with Sendable<CompilationPathMessage, CompilationPath?> {
  final CompilationPath path;

  _FakeCompPath(this.path);

  @override
  Future<CompilationPath?> send(CompilationPathMessage message) async => path;
}

void main() {
  group('JavaVersion', () {
    test('can parse number', () {
      expect(JavaVersion.parse('1'), JavaVersion(1, 0, 0));
    });
    test('can parse 2 numbers', () {
      expect(JavaVersion.parse('1.2'), JavaVersion(1, 2, 0));
    });
    test('can parse 3 numbers', () {
      expect(JavaVersion.parse('1.2.3'), JavaVersion(1, 2, 3));
    });
    test('can parse 4 numbers', () {
      expect(JavaVersion.parse('1.2.3.4'), JavaVersion(1, 2, 3));
    });
    test('can parse even with invalid part', () {
      expect(JavaVersion.parse('1.2-patch2'), JavaVersion(1, 2, 0));
      expect(JavaVersion.parse('beta-1.2.AC'), JavaVersion(0, 2, 0));
    });
    test('can parse completely invalid', () {
      expect(JavaVersion.parse('foo bar 2'), JavaVersion(0, 0, 0));
    });
  });

  group('checkDepsJavaVersion', () {
    final compPath = CompilationPath(
      modules: const [],
      jars: [Jar(javaVersion: '17', path: '/libs/needs-17.jar')],
    );

    test('fails when a jar requires a newer Java version', () {
      expect(
        checkDepsJavaVersion(
          _FakeJvm('11'),
          _FakeCompPath(compPath),
          'artifact',
          '/libs',
          'compilation-path.json',
        ),
        throwsA(
          isA<DartleException>().having(
            (e) => e.message,
            'message',
            allOf(
              contains('Current Java version is 11'),
              contains('/libs/needs-17.jar (needs 17)'),
            ),
          ),
        ),
      );
    });

    test('succeeds when the current Java version is compatible', () async {
      await checkDepsJavaVersion(
        _FakeJvm('21'),
        _FakeCompPath(compPath),
        'artifact',
        '/libs',
        'compilation-path.json',
      );
    });
  });
}
