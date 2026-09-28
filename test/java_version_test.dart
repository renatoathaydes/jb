import 'package:jb/src/java_version.dart';
import 'package:test/test.dart';

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
}
