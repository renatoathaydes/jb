import 'package:dartle/dartle.dart' show DartleException;
import 'package:jb/src/config.dart'
    show ConfigType, JbConfiguration, loadConfigString, JavaConstructor;
import 'package:jb/src/extension/constructors.dart' show resolveConstructorData;
import 'package:test/expect.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('jb extension', () {
    late JbConfiguration emptyJbConfig;
    setUpAll(() async {
      emptyJbConfig = await loadConfigString('module: test');
    });

    test('can match empty constructor', () {
      expect(
        resolveConstructorData('task-name', {}, [{}], emptyJbConfig),
        equals(const []),
      );
    });

    test('can match empty constructor when more constructors available', () {
      expect(
        resolveConstructorData('task-name', {}, [
          {'foo': ConfigType.string},
          {},
        ], emptyJbConfig),
        equals(const []),
      );
    });

    test(
      'when both empty and JBuildLog constructor available, prefer the latter',
      () {
        expect(
          resolveConstructorData('task-name', {}, [
            {'logger': ConfigType.jbuildLogger},
            {},
          ], emptyJbConfig),
          equals(const [null]),
        );
        expect(
          resolveConstructorData('task-name', {}, [
            {},
            {'logger': ConfigType.jbuildLogger},
          ], emptyJbConfig),
          equals(const [null]),
        );
      },
    );

    test('can match string parameter with null or string value', () {
      expect(
        resolveConstructorData(
          'task-name',
          {'foo': null},
          [
            {'foo': ConfigType.string},
            {},
          ],
          emptyJbConfig,
        ),
        equals(const [null]),
      );
      expect(
        resolveConstructorData(
          'task-name',
          {'foo': 'bar'},
          [
            {'foo': ConfigType.string},
            {},
          ],
          emptyJbConfig,
        ),
        equals(const ['bar']),
      );
    });

    test('can match JBuildLogger parameter with null or missing value', () {
      expect(
        resolveConstructorData(
          'task-name',
          {'log': null},
          [
            {'log': ConfigType.jbuildLogger},
          ],
          emptyJbConfig,
        ),
        equals(const [null]),
      );
      expect(
        resolveConstructorData('task-name', const {}, [
          {'log': ConfigType.jbuildLogger},
        ], emptyJbConfig),
        equals(const [null]),
      );
    });

    test('matches expected constructor when multiple available', () {
      expect(
        resolveConstructorData(
          'task-name',
          {'integer': 10, 'bool': true},
          [
            {},
            {'foo': ConfigType.string},
            {'integer': ConfigType.int, 'bool': ConfigType.boolean},
          ],
          emptyJbConfig,
        ),
        equals(const [10, true]),
      );

      expect(
        resolveConstructorData(
          'task-name',
          {'log': null, 'bool': true},
          [
            {'bool': ConfigType.boolean, 'log': ConfigType.jbuildLogger},
            {'foo': ConfigType.string},
          ],
          emptyJbConfig,
        ),
        equals(const [true, null]),
      );

      expect(
        resolveConstructorData(
          'task-name',
          {'bool': true},
          [
            {'bool': ConfigType.boolean, 'log': ConfigType.jbuildLogger},
            {'foo': ConfigType.string},
          ],
          emptyJbConfig,
        ),
        equals(const [true, null]),
      );
    });

    test('can match parameters of all types', () {
      expect(
        resolveConstructorData(
          'task-name',
          {
            'g': ['foo'],
            'f': ['a', 'b'],
            'e': 'hi',
            'd': 3.1415,
            'c': 2,
            'b': false,
            'a': null,
          },
          [
            {
              'a': ConfigType.jbuildLogger,
              'b': ConfigType.boolean,
              'c': ConfigType.int,
              'd': ConfigType.float,
              'e': ConfigType.string,
              'f': ConfigType.arrayOfStrings,
              'g': ConfigType.listOfStrings,
            },
          ],
          emptyJbConfig,
        ),
        equals([
          null,
          false,
          2,
          3.1415,
          'hi',
          ['a', 'b'],
          ['foo'],
        ]),
      );
    });

    test('String arrays match with empty List', () {
      expect(
        resolveConstructorData(
          'task-name',
          {'array': []},
          [
            {'array': ConfigType.arrayOfStrings},
          ],
          emptyJbConfig,
        ),
        equals(const [[]]),
      );
    });

    test('String Lists match with empty List', () {
      expect(
        resolveConstructorData(
          'task-name',
          {'array': []},
          [
            {'array': ConfigType.listOfStrings},
          ],
          emptyJbConfig,
        ),
        equals(const [[]]),
      );
    });

    test('String Lists match with dynamic List', () {
      dynamic myList = ['foo'];
      final otherList = <dynamic>['bar'];
      expect(
        resolveConstructorData(
          'task-name',
          {'l1': myList, 'l2': otherList},
          [
            {'l1': ConfigType.listOfStrings, 'l2': ConfigType.listOfStrings},
          ],
          emptyJbConfig,
        ),
        equals([
          ['foo'],
          ['bar'],
        ]),
      );
    });
  });

  group('jb extension errors', () {
    late JbConfiguration emptyJbConfig;
    setUpAll(() async {
      emptyJbConfig = await loadConfigString('module: test');
    });

    test('cannot provide value for non-configurable type', () {
      for (final type in ConfigType.values.where((t) => !t.mayBeConfigured())) {
        expect(
          () => resolveConstructorData(
            'task',
            {'foo': Object()},
            [
              {'foo': type},
            ],
            emptyJbConfig,
          ),
          throwsA(
            isA<DartleException>().having(
              (e) => e.message,
              'message',
              equals(
                'Cannot create jb extension task \'task\' because '
                'its configuration is trying to provide a value for a '
                'non-configurable property \'foo\'! Please remove this '
                'property from configuration.',
              ),
            ),
          ),
        );
      }
    });

    for (final type in ConfigType.values) {
      if (!type.mayBeConfigured()) continue;
      final value = type == ConfigType.string ? 10 : 'bar';
      test('recognizes type mismatch for $type', () {
        expect(
          () => resolveConstructorData(
            'task',
            {'foo': value},
            [
              {'foo': type},
            ],
            emptyJbConfig,
          ),
          throwsA(
            isA<DartleException>().having(
              (e) => e.message,
              'message',
              contains(
                "Cannot create jb extension task 'task' because "
                "the provided configuration for this task does not match any of "
                "the acceptable schemas.",
              ),
            ),
          ),
        );
      });
    }

    for (final schema in <JavaConstructor>[
      {},
      {'log': ConfigType.jbuildLogger},
      {'l1': ConfigType.jbuildLogger, 'l2': ConfigType.jbuildLogger},
    ]) {
      test(
        'schemas are displayed properly on type error (no config expected: ${schema.keys})',
        () {
          expect(
            () => resolveConstructorData(
              'task',
              {'num': 10},
              [schema],
              emptyJbConfig,
            ),
            throwsA(
              isA<DartleException>().having(
                (e) => e.message,
                'message',
                equals(
                  "Cannot create jb extension task 'task' because "
                  "configuration was provided for this task when none was "
                  "expected. Please remove it from your jb configuration.",
                ),
              ),
            ),
          );
        },
      );
    }

    test('null value is not allowed on non-String', () {
      expect(
        () => resolveConstructorData(
          'task',
          {'num': null},
          [
            {'num': ConfigType.float},
          ],
          emptyJbConfig,
        ),
        throwsA(
          isA<DartleException>().having(
            (e) => e.message,
            'message',
            endsWith(
              "Please use one of the following schemas:\n"
              "  - option1:\n"
              "    num: float\n",
            ),
          ),
        ),
      );
    });

    test('schemas are displayed properly on type error (single option)', () {
      expect(
        () => resolveConstructorData(
          'task',
          {'num': 10, 'str': 24},
          [
            {'num': ConfigType.float, 'str': ConfigType.string},
          ],
          emptyJbConfig,
        ),
        throwsA(
          isA<DartleException>().having(
            (e) => e.message,
            'message',
            endsWith(
              "Please use one of the following schemas:\n"
              "  - option1:\n"
              "    num: float\n"
              "    str: String\n",
            ),
          ),
        ),
      );
    });

    test('schemas are displayed properly on type error (multiple options)', () {
      expect(
        () => resolveConstructorData(
          'task',
          {'num': 10, 'str': 24},
          [
            {},
            {'num': ConfigType.float},
            {'num': ConfigType.float, 'str': ConfigType.string},
          ],
          emptyJbConfig,
        ),
        throwsA(
          isA<DartleException>().having(
            (e) => e.message,
            'message',
            endsWith(
              "Please use one of the following schemas:\n"
              "  - option1:\n"
              "    <no configuration>\n"
              "  - option2:\n"
              "    num: float\n"
              "  - option3:\n"
              "    num: float\n"
              "    str: String\n",
            ),
          ),
        ),
      );
    });
  });
}
