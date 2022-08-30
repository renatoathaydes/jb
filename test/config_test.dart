import 'package:jbuild_cli/src/config.dart';
import 'package:test/test.dart';

void main() {
  group('CompileConfiguration', () {
    test('can load', () {
      final config = JBuildConfiguration(
          sourceDirs: {'src'},
          classpath: const {},
          output: CompileOutput.jar('lib.jar'),
          resourceDirs: const {},
          mainClass: '',
          dependencies: const {},
          exclusions: const {},
          repositories: const {},
          javacArgs: const []);

      expect(config.output.when(dir: (d) => 'dir', jar: (j) => j), 'lib.jar');
    });
  });
}
