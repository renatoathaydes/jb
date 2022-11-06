import 'package:jb/src/utils.dart';
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
}
