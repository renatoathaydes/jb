import 'package:jb/src/utils.dart';
import 'package:jb/src/config.dart';
import 'package:test/test.dart';

void main() {
  test('String?.removeFromEnd', () {
    expect(null.removeFromEnd(const {}), isNull);
    expect(null.removeFromEnd(const {'foo'}), isNull);
    expect(''.removeFromEnd(const {}), equals(''));
    expect(''.removeFromEnd(const {'foo'}), equals(''));
    expect('foo'.removeFromEnd(const {'foo'}), equals(''));
    expect('abcfoo'.removeFromEnd(const {'foo'}), equals('abc'));
    expect('abcfooabc'.removeFromEnd(const {'foo'}), equals('abcfooabc'));
    expect('abcfooabc'.removeFromEnd(const {'abc', 'foo'}), equals('abcfoo'));
    expect('dir/'.removeFromEnd(const {'/', '\\'}), equals('dir'));
    expect('dir\\'.removeFromEnd(const {'/', '\\'}), equals('dir'));
    expect('dir\\bar'.removeFromEnd(const {'/', '\\'}), equals('dir\\bar'));
    expect('dir\\bar/'.removeFromEnd(const {'/', '\\'}), equals('dir\\bar'));
    expect('dir\\bar//'.removeFromEnd(const {'/', '\\'}), equals('dir\\bar/'));
  });

  group('DependencyMapExtension', () {
    test('can merge dependencies', () {
      final deps1 = {'foo:bar:1.0': defaultSpec};
      final deps2 = {'bar:foo:2.0': defaultSpec};
      expect(
          deps1.merge(deps2, const {}),
          equals({
            'foo:bar:1.0': defaultSpec,
            'bar:foo:2.0': defaultSpec,
          }));
    });

    test('can merge dependencies when properties are used', () {
      final deps1 = {'foo:bar:{{fooVersion}}': defaultSpec};
      final deps2 = {'bar:foo:{{barVersion}}': defaultSpec};
      expect(
          deps1.merge(deps2, const {'fooVersion': '1.0', 'barVersion': '2.0'}),
          equals({
            'foo:bar:1.0': defaultSpec,
            'bar:foo:2.0': defaultSpec,
          }));
    });

    test('can merge dependencies when properties are used (this empty)', () {
      final deps1 = <String, DependencySpec>{};
      final deps2 = {'bar:foo:{{barVersion}}': defaultSpec};
      expect(
          deps1.merge(deps2, const {'fooVersion': '1.0', 'barVersion': '2.0'}),
          equals({
            'bar:foo:2.0': defaultSpec,
          }));
    });

    test('can merge dependencies when properties are used (that empty)', () {
      final deps1 = {'foo:bar:{{fooVersion}}': defaultSpec};
      final deps2 = <String, DependencySpec>{};
      expect(
          deps1.merge(deps2, const {'fooVersion': '1.0', 'barVersion': '2.0'}),
          equals({
            'foo:bar:1.0': defaultSpec,
          }));
    });
  });
}
