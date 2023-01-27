import 'package:jb/src/file_tree.dart';
import 'package:test/test.dart';

void main() {
  group('FileTree', () {
    test('can load simple file tree', () async {
      final tree = await loadFileTree(Stream.fromIterable([
        r'Required type(s) for build/jbuild.jar:',
        r'  - jbuild.api.CustomTaskPhase (CustomTaskPhase.java):',
        r'  - jbuild.artifact.Artifact (Artifact.java):',
        r'    * jbuild.artifact.Version',
        r'    * jbuild.errors.JBuildException',
        r'  - jbuild.errors.JBuildException$ErrorCause (JBuildException.java):',
        r'    * jbuild.errors.JBuildException$ErrorCause',
        r'    * jbuild.errors.JBuildException',
        r'  - jbuild.errors.JBuildException (JBuildException.java):',
        r'    * jbuild.errors.JBuildException$ErrorCause',
        r'    * jbuild.errors.Error',
        r'  - jbuild.errors.JBuildException$ErrorCause (JBuildException.java):',
        r'  - jbuild.errors.Error (Error.java):',
        r'    * jbuild.artifact.Version',
        r'    * jbuild.artifact.Maven',
        r'  - jbuild.artifact.Version (Version.java):',
        r'    * jbuild.artifact.VersionRange',
        r'  - jbuild.artifact.VersionRange (VersionRange.java):',
        r'  - jbuild.artifact.Maven (Maven.java):',
      ]));

      print(tree);

      expect(tree.transitiveDeps('CustomTaskPhase.java'), equals(const []));

      expect(tree.transitiveDeps('Version.java'),
          equals(const ['VersionRange.java']));

      expect(
          tree.transitiveDeps('Artifact.java'),
          equals(const [
            'Version.java',
            'JBuildException.java',
            'VersionRange.java',
            'Error.java',
            'Maven.java',
          ]));
    });
  });
}
