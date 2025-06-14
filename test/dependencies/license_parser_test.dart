import 'package:jb/src/dependencies/parse.dart';
import 'package:test/test.dart';

void main() {
  const parser = LicenseParser();

  test('can parse simple license line', () {
    final licenses = parser.parseLicenses('{MIT}');
    expect(licenses, hasLength(1));
    expect(licenses[0].name, equals('MIT'));
    expect(licenses[0].url, equals(''));
  });

  test('can parse two simple licenses line', () {
    final licenses = parser.parseLicenses('{MIT}, {Apache-2.0}');
    expect(licenses, hasLength(2));
    expect(licenses[0].name, equals('MIT'));
    expect(licenses[0].url, equals(''));
    expect(licenses[1].name, equals('Apache-2.0'));
    expect(licenses[1].url, equals(''));
  });

  test('can parse single, full license line', () {
    final licenses = parser.parseLicenses(
      '{name=Apache Software License - Version 2.0, url=https://www.apache.org/licenses/LICENSE-2.0}',
    );
    expect(licenses, hasLength(1));
    expect(licenses[0].name, equals('Apache Software License - Version 2.0'));
    expect(
      licenses[0].url,
      equals('https://www.apache.org/licenses/LICENSE-2.0'),
    );
  });

  test('can parse simple license followed by full license line', () {
    final licenses = parser.parseLicenses(
      '{MIT}, {name=Apache Software License - Version 2.0, url=https://www.apache.org/licenses/LICENSE-2.0}',
    );
    expect(licenses, hasLength(2));
    expect(licenses[0].name, equals('MIT'));
    expect(licenses[0].url, equals(''));
    expect(licenses[1].name, equals('Apache Software License - Version 2.0'));
    expect(
      licenses[1].url,
      equals('https://www.apache.org/licenses/LICENSE-2.0'),
    );
  });

  test('can parse two full licenses line', () {
    final licenses = parser.parseLicenses(
      '{name=Apache Software License - Version 2.0, url=https://www.apache.org/licenses/LICENSE-2.0}, '
      '{name=Eclipse Public License - Version 2.0, url=https://www.eclipse.org/legal/epl-2.0}',
    );
    expect(licenses, hasLength(2));
    expect(licenses[0].name, equals('Apache Software License - Version 2.0'));
    expect(
      licenses[0].url,
      equals('https://www.apache.org/licenses/LICENSE-2.0'),
    );
    expect(licenses[1].name, equals('Eclipse Public License - Version 2.0'));
    expect(licenses[1].url, equals('https://www.eclipse.org/legal/epl-2.0'));
  });

  test('can parse full license followed by simple license line', () {
    final licenses = parser.parseLicenses(
      '{name=Apache Software License - Version 2.0, url=https://www.apache.org/licenses/LICENSE-2.0}, {MIT}',
    );
    expect(licenses, hasLength(2));
    expect(licenses[0].name, equals('Apache Software License - Version 2.0'));
    expect(
      licenses[0].url,
      equals('https://www.apache.org/licenses/LICENSE-2.0'),
    );
    expect(licenses[1].name, equals('MIT'));
    expect(licenses[1].url, equals(''));
  });

  test('can parse license containing curly brackets', () {
    final licenses = parser.parseLicenses('{name=custom{license}, url=foo}');
    expect(licenses, hasLength(1));
    expect(licenses[0].name, equals('custom{license}'));
    expect(licenses[0].url, equals('foo'));
  });

  test('can parse license containing comma', () {
    final licenses = parser.parseLicenses('{name=Foo,Bar, url=foo}');
    expect(licenses, hasLength(1));
    expect(licenses[0].name, equals('Foo,Bar'));
    expect(licenses[0].url, equals('foo'));
  });
}
