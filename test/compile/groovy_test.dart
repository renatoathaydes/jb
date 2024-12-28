import 'package:jb/src/compile/groovy.dart';
import 'package:test/test.dart';

void main() {
  test('can recognize the groovy jar', () {
    expect(groovyJarPattern.matchAsPrefix('groovy.jar'), isNull);
    expect(groovyJarPattern.matchAsPrefix('groovy-3.0.0'), isNull);
    expect(groovyJarPattern.matchAsPrefix('groovy-3.0.0-foo.jar'), isNotNull);
    expect(groovyJarPattern.matchAsPrefix('groovy-3.0.0.jar'), isNotNull);
    expect(groovyJarPattern.matchAsPrefix('groovy-4.0.24.jar'), isNotNull);
    expect(
        groovyJarPattern.matchAsPrefix('groovy-5.0.0-alpha-9.jar'), isNotNull);
  });
}
