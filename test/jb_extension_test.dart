import 'package:dartle/dartle.dart' show DartleException;
import 'package:jb/src/config.dart' show JavaConfigType;
import 'package:jb/src/jb_extension.dart' show resolveConstructor;
import 'package:test/expect.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('jb extension', () {
    test('can match empty constructor', () {
      expect(resolveConstructor('task-name', {}, [{}]), equals(const []));
    });

    test('can match empty constructor when more constructors available', () {
      expect(
          resolveConstructor('task-name', {}, [
            {'foo': JavaConfigType.string},
            {},
          ]),
          equals(const []));
    });

    test(
        'when both empty and JBuildLog constructor available, prefer the latter',
        () {
      expect(
          resolveConstructor('task-name', {}, [
            {'logger': JavaConfigType.jbuildLogger},
            {},
          ]),
          equals(const [null]));
      expect(
          resolveConstructor('task-name', {}, [
            {},
            {'logger': JavaConfigType.jbuildLogger},
          ]),
          equals(const [null]));
    });

    test('can match string parameter with null or string value', () {
      expect(
          resolveConstructor('task-name', {
            'foo': null
          }, [
            {'foo': JavaConfigType.string},
            {},
          ]),
          equals(const [null]));
      expect(
          resolveConstructor('task-name', {
            'foo': 'bar'
          }, [
            {'foo': JavaConfigType.string},
            {},
          ]),
          equals(const ['bar']));
    });

    test('can match JBuildLogger parameter with null or missing value', () {
      expect(
          resolveConstructor('task-name', {
            'log': null
          }, [
            {'log': JavaConfigType.jbuildLogger},
          ]),
          equals(const [null]));
      expect(
          resolveConstructor('task-name', const {}, [
            {'log': JavaConfigType.jbuildLogger},
          ]),
          equals(const [null]));
    });

    test('matches expected constructor when multiple available', () {
      expect(
          resolveConstructor('task-name', {
            'integer': 10,
            'bool': true,
          }, [
            {},
            {'foo': JavaConfigType.string},
            {'integer': JavaConfigType.int, 'bool': JavaConfigType.boolean},
          ]),
          equals(const [10, true]));

      expect(
          resolveConstructor('task-name', {
            'log': null,
            'bool': true,
          }, [
            {
              'bool': JavaConfigType.boolean,
              'log': JavaConfigType.jbuildLogger
            },
            {'foo': JavaConfigType.string},
          ]),
          equals(const [true, null]));

      expect(
          resolveConstructor('task-name', {
            'bool': true,
          }, [
            {
              'bool': JavaConfigType.boolean,
              'log': JavaConfigType.jbuildLogger
            },
            {'foo': JavaConfigType.string},
          ]),
          equals(const [true, null]));
    });

    test('can match parameters of all types', () {
      expect(
          resolveConstructor('task-name', {
            'g': ['foo'],
            'f': ['a', 'b'],
            'e': 'hi',
            'd': 3.1415,
            'c': 2,
            'b': false,
            'a': null,
          }, [
            {
              'a': JavaConfigType.jbuildLogger,
              'b': JavaConfigType.boolean,
              'c': JavaConfigType.int,
              'd': JavaConfigType.float,
              'e': JavaConfigType.string,
              'f': JavaConfigType.arrayOfStrings,
              'g': JavaConfigType.listOfStrings,
            },
          ]),
          equals([
            null,
            false,
            2,
            3.1415,
            'hi',
            ['a', 'b'],
            ['foo'],
          ]));
    });

    test('String arrays match with empty List', () {
      expect(
          resolveConstructor('task-name', {
            'array': []
          }, [
            {'array': JavaConfigType.arrayOfStrings},
          ]),
          equals(const [[]]));
    });

    test('String Lists match with empty List', () {
      expect(
          resolveConstructor('task-name', {
            'array': []
          }, [
            {'array': JavaConfigType.listOfStrings},
          ]),
          equals(const [[]]));
    });

    test('String Lists match with dynamic List', () {
      dynamic myList = ['foo'];
      final otherList = <dynamic>['bar'];
      expect(
          resolveConstructor('task-name', {
            'l1': myList,
            'l2': otherList,
          }, [
            {
              'l1': JavaConfigType.listOfStrings,
              'l2': JavaConfigType.listOfStrings,
            },
          ]),
          equals([
            ['foo'],
            ['bar'],
          ]));
    });
  });

  group('jb extension errors', () {
    test('cannot provide value for JBuildLogger', () {
      expect(
          () => resolveConstructor('task', {
                'foo': Object()
              }, [
                {'foo': JavaConfigType.jbuildLogger}
              ]),
          throwsA(isA<DartleException>().having(
              (e) => e.message,
              'message',
              equals("Cannot create jb extension task 'task' "
                  "because property 'foo' is invalid: "
                  "property of type JBuildLogger cannot be configured"))));
    });

    for (final type in JavaConfigType.values) {
      if (type == JavaConfigType.jbuildLogger) continue;
      final value = type == JavaConfigType.string ? 10 : 'bar';
      test('recognizes type mismatch for $type', () {
        expect(
            () => resolveConstructor('task', {
                  'foo': value
                }, [
                  {'foo': type}
                ]),
            throwsA(isA<DartleException>().having(
                (e) => e.message,
                'message',
                contains("Cannot create jb extension task 'task' because "
                    "the provided configuration for this task does not match any of "
                    "the acceptable schemas."))));
      });
    }

    for (final schema in <Map<String, JavaConfigType>>[
      {},
      {'log': JavaConfigType.jbuildLogger},
      {'l1': JavaConfigType.jbuildLogger, 'l2': JavaConfigType.jbuildLogger},
    ]) {
      test(
          'schemas are displayed properly on type error (no config expected: ${schema.keys})',
          () {
        expect(
            () => resolveConstructor('task', {'num': 10}, [schema]),
            throwsA(isA<DartleException>().having(
                (e) => e.message,
                'message',
                equals("Cannot create jb extension task 'task' because "
                    "configuration was provided for this task when none was "
                    "expected. Please remove it from your jb configuration."))));
      });
    }

    test('null value is not allowed on non-String', () {
      expect(
          () => resolveConstructor('task', {
                'num': null,
              }, [
                {'num': JavaConfigType.float}
              ]),
          throwsA(isA<DartleException>().having(
              (e) => e.message,
              'message',
              endsWith("Please use one of the following schemas:\n"
                  "  - option1:\n"
                  "    num: float\n"))));
    });

    test('schemas are displayed properly on type error (single option)', () {
      expect(
          () => resolveConstructor('task', {
                'num': 10,
                'str': 24
              }, [
                {'num': JavaConfigType.float, 'str': JavaConfigType.string}
              ]),
          throwsA(isA<DartleException>().having(
              (e) => e.message,
              'message',
              endsWith("Please use one of the following schemas:\n"
                  "  - option1:\n"
                  "    num: float\n"
                  "    str: String\n"))));
    });

    test('schemas are displayed properly on type error (multiple options)', () {
      expect(
          () => resolveConstructor('task', {
                'num': 10,
                'str': 24
              }, [
                {},
                {'num': JavaConfigType.float},
                {'num': JavaConfigType.float, 'str': JavaConfigType.string},
              ]),
          throwsA(isA<DartleException>().having(
              (e) => e.message,
              'message',
              endsWith("Please use one of the following schemas:\n"
                  "  - option1:\n"
                  "    <no configuration>\n"
                  "  - option2:\n"
                  "    num: float\n"
                  "  - option3:\n"
                  "    num: float\n"
                  "    str: String\n"))));
    });
  });
}
