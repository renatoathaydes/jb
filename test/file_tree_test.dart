import 'dart:io';

import 'package:dartle/dartle_cache.dart';
import 'package:jb/src/file_tree.dart';
import 'package:test/test.dart';

void main() {
  group('FileTree', () {
    late FileTree tree;

    setUpAll(() async {
      tree = await loadFileTree(Stream.fromIterable([
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
    });

    test('can load simple file tree', () async {
      expect(tree.transitiveDeps('jbuild/api/CustomTaskPhase.java'),
          equals(const {'jbuild/api/CustomTaskPhase.java'}));

      expect(
          tree.transitiveDeps('jbuild/artifact/Version.java'),
          equals(const {
            'jbuild/artifact/Version.java',
            'jbuild/artifact/VersionRange.java'
          }));

      expect(
          tree.transitiveDeps('jbuild/artifact/Artifact.java'),
          equals(const {
            'jbuild/artifact/Artifact.java',
            'jbuild/artifact/Version.java',
            'jbuild/errors/JBuildException.java',
            'jbuild/artifact/VersionRange.java',
            'jbuild/errors/Error.java',
            'jbuild/maven/Maven.java',
          }));
    });

    test('can compute all transitive changes from ChangeSet', () async {
      final changes = tree.computeTransitiveChanges([
        FileChange(File('jbuild/artifact/Version.java'), ChangeKind.modified),
        FileChange(
            File('jbuild/api/CustomTaskPhase.java'), ChangeKind.modified),
      ]);

      expect(
          changes,
          equals(const {
            'jbuild/artifact/Version.java',
            'jbuild/artifact/VersionRange.java',
            'jbuild/api/CustomTaskPhase.java',
          }));
    });

    test('removes deletions from transitive changes from ChangeSet', () async {
      final changes = tree.computeTransitiveChanges([
        FileChange(File('jbuild/artifact/Artifact.java'), ChangeKind.modified),
        FileChange(
            File('jbuild/errors/JBuildException.java'), ChangeKind.deleted),
      ]);

      expect(
          changes,
          equals(const {
            'jbuild/artifact/Artifact.java',
          }));
    });
  });
}
