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
        r'    * jbuild.maven.Maven',
        r'  - jbuild.artifact.Version (Version.java):',
        r'    * jbuild.artifact.VersionRange',
        r'  - jbuild.artifact.VersionRange (VersionRange.java):',
        r'  - jbuild.maven.Maven (Maven.java):',
      ]));

      expect(tree.transitiveDeps('jbuild/api/CustomTaskPhase.java'),
          equals(const []));

      expect(tree.transitiveDeps('jbuild/artifact/Version.java'),
          equals(const ['jbuild/artifact/VersionRange.java']));

      expect(
          tree.transitiveDeps('jbuild/artifact/Artifact.java'),
          equals(const [
            'jbuild/artifact/Version.java',
            'jbuild/errors/JBuildException.java',
            'jbuild/artifact/VersionRange.java',
            'jbuild/errors/Error.java',
            'jbuild/maven/Maven.java',
          ]));
    });
  });
}
