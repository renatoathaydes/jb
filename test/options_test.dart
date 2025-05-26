import 'package:dartle/dartle.dart';
import 'package:jb/jb.dart';
import 'package:test/test.dart';

Future<void> main() async {
  group('CLI Options', () {
    test('Can parse empty', () {
      final options = JbCliOptions.parseArgs(const []);
      expect(options.createOptions, isNull);
      expect(options.dartleArgs, isEmpty);
      expect(options.rootDirectory, isNull);
    });

    test('Can parse basic Dartle options', () {
      final options = JbCliOptions.parseArgs(const ['-l', 'debug', 'run']);
      expect(options.createOptions, isNull);
      expect(options.dartleArgs, equals(const ['-l', 'debug', 'run']));
      expect(options.rootDirectory, isNull);
    });

    test('Can parse Dartle options with custom rootDir', () {
      final options = JbCliOptions.parseArgs(
          const ['-l', 'debug', 'run', '-p', 'root', 'test']);
      expect(options.createOptions, isNull);
      expect(options.dartleArgs, equals(const ['-l', 'debug', 'run', 'test']));
      expect(options.rootDirectory, 'root');
    });

    test('Can parse create command', () {
      final options = JbCliOptions.parseArgs(const ['create']);
      expect(options.createOptions?.arguments, equals(const []));
      expect(options.dartleArgs, isEmpty);
      expect(options.rootDirectory, isNull);
    });

    test('Can parse create command with custom rootDir (create -p mydir)', () {
      final options = JbCliOptions.parseArgs(const ['create', '-p', 'mydir']);
      expect(options.createOptions?.arguments, equals(const []));
      expect(options.dartleArgs, isEmpty);
      expect(options.rootDirectory, 'mydir');
    });

    test('Do not mix project name "create" with command "create"', () {
      final options = JbCliOptions.parseArgs(const ['-p', 'create']);
      expect(options.createOptions, isNull);
      expect(options.dartleArgs, isEmpty);
      expect(options.rootDirectory, 'create');
    });

    test('Can parse create command with custom rootDir (-p mydir create)', () {
      final options = JbCliOptions.parseArgs(const ['-p', 'mydir', 'create']);
      expect(options.createOptions?.arguments, equals(const []));
      expect(options.dartleArgs, isEmpty);
      expect(options.rootDirectory, 'mydir');
    });
  });

  group('CLI Options errors', () {
    test('missing -p argument', () {
      expect(
          () => JbCliOptions.parseArgs(const ['-p']),
          throwsA(isA<DartleException>().having((e) => e.message, 'message',
              equals('-p option requires an argument.'))));
      expect(
          () => JbCliOptions.parseArgs(const ['-l', 'debug', '-p']),
          throwsA(isA<DartleException>().having((e) => e.message, 'message',
              equals('-p option requires an argument.'))));
    });

    test('create command cannot be used with other tasks', () {
      expect(
          () => JbCliOptions.parseArgs(const ['run', 'test', 'create']),
          throwsA(isA<DartleException>().having(
              (e) => e.message,
              'message',
              equals(
                  'The "create" command cannot be used with other tasks or arguments.'))));
    });
  });
}
