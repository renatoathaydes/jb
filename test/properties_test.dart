import 'package:jb/src/properties.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

void main() {
  group('Raw values tests', () {
    test('does not resolve raw strings', () {
      expect(resolveProperties({}, {}), equals(<String, Object?>{}));
      expect(resolveProperties({'foo': 'bar'}, {'bar': 'zort'}),
          equals({'foo': 'bar'}));
    });

    test('does not resolve missing keys', () {
      expect(resolveProperties({'foo': '{{bar}}'}, {}),
          equals({'foo': '{{bar}}'}));
      expect(resolveProperties({'foo': 'a{{bar}}b'}, {'foo': 'bar'}),
          equals({'foo': 'a{{bar}}b'}));
    });

    test('does not bomb on nulls', () {
      expect(resolveProperties({'foo': null}, {}), equals({'foo': null}));
      expect(resolveProperties({'foo': '{{bar}}'}, {'bar': null}),
          equals({'foo': '{{bar}}'}));
    });

    test('can resolve string properties', () {
      expect(resolveProperties({'foo': '{{bar}}'}, {'bar': 'zort'}),
          equals({'foo': 'zort'}));
      expect(resolveProperties({'foo': 'XY{{bar}}Z'}, {'bar': 'zort'}),
          equals({'foo': 'XYzortZ'}));
      expect(resolveProperties({'foo': 'XY{{bar}}{{bar}}'}, {'bar': 'zort'}),
          equals({'foo': 'XYzortzort'}));
      expect(resolveProperties({'foo': 'XY{{bar}}Z{{bar}}W'}, {'bar': '?'}),
          equals({'foo': 'XY?Z?W'}));
      expect(
          resolveProperties(
              {'a': '{{a}}{{b}}{{c}}', 'b': '{{b}}{{c}}', 'c': '{{c}}'},
              {'a': 1, 'b': 2, 'c': 3, 'd': 4, 'e': 5}),
          equals({'a': '123', 'b': '23', 'c': '3'}));
    });

    test('can resolve list properties', () {
      expect(
          resolveProperties({
            'foo': ['{{bar}}']
          }, {
            'bar': 'zort'
          }),
          equals({
            'foo': ['zort']
          }));
      expect(
          resolveProperties({
            'foo': [
              ['{{bar}}', null],
              '{{zort}}'
            ]
          }, {
            'bar': 'zort',
            'zort': 'beta',
          }),
          equals({
            'foo': [
              ['zort', null],
              'beta'
            ]
          }));
    });

    test('can resolve Map properties', () {
      expect(
          resolveProperties({
            'a': {
              'b': '{{x}}',
              'c': ['{{y}}']
            }
          }, {
            'x': 'foo',
            'y': 'bar',
            'z': 'zort'
          }),
          equals({
            'a': {
              'b': 'foo',
              'c': ['bar']
            }
          }));
    });

    test('can resolve nested Map properties', () {
      expect(
          resolveProperties({
            'a': ['{{x.y.z}}'],
            'b': 'x is {{x}}'
          }, {
            'x': {
              'y': {'z': '!!'}
            },
          }),
          equals({
            'a': ['!!'],
            'b': 'x is ${{
              'y': {'z': '!!'}
            }}',
          }));
    });
  });

  group('YAML Tests', () {
    test('can resolve properties in YAML Map', () {
      final yaml = '''
      properties: {'a': 'X', 'b': 'Y', 'c': 'Z', 'd': {'e': 'W'}}
      string: "{{a}}"
      map:
        k: "{{b}}"
        "{{a}}": "{{c}}"
        list:
          - foo
          - "{{c}}{{d.e}}"
      ''';

      final resolvedMap = resolvePropertiesFromMap(loadYaml(yaml));

      expect(
          resolvedMap.properties,
          equals(const {
            'a': 'X',
            'b': 'Y',
            'c': 'Z',
            'd': {'e': 'W'},
          }));

      expect(
          resolvedMap.map,
          equals(const {
            'string': 'X',
            'map': {
              'k': 'Y',
              'X': 'Z',
              'list': ['foo', 'ZW'],
            },
            'properties': {
              'a': 'X',
              'b': 'Y',
              'c': 'Z',
              'd': {'e': 'W'}
            },
          }));
    });
  });
}
