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
        r'  - jbuild.errors.Error (Error.java):',
        r'    * jbuild.artifact.Version',
        r'    * jbuild.maven.Maven',
        r'  - jbuild.artifact.Version (Version.java):',
        r'    * jbuild.artifact.VersionRange',
        r'  - jbuild.artifact.VersionRange (VersionRange.java):',
        r'  - jbuild.maven.Maven (Maven.java):',
      ]));
    });

    test('can compute transitive dependencies of a file', () async {
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

    test('can compute transitive dependents of a file', () async {
      expect(tree.dependentsOf('jbuild/artifact/Artifact.java'),
          equals(const {'jbuild/artifact/Artifact.java'}));

      expect(
          tree.dependentsOf('jbuild/errors/Error.java'),
          equals(const {
            'jbuild/errors/Error.java',
            'jbuild/errors/JBuildException.java',
            'jbuild/artifact/Artifact.java',
          }));
    });

    test('can compute transitive changes from file changes', () async {
      var changes = tree.computeTransitiveChanges([
        FileChange(File('jbuild/artifact/Artifact.java'), ChangeKind.modified),
      ]);

      expect(
          changes.modified,
          equals(const {
            'jbuild/artifact/Artifact.java',
          }));
      expect(changes.deletions, isEmpty);

      changes = tree.computeTransitiveChanges([
        FileChange(File('jbuild/artifact/Version.java'), ChangeKind.modified),
        FileChange(
            File('jbuild/api/CustomTaskPhase.java'), ChangeKind.modified),
      ]);

      expect(
          changes.modified,
          equals(const {
            'jbuild/artifact/Version.java',
            'jbuild/errors/Error.java',
            'jbuild/errors/JBuildException.java',
            'jbuild/artifact/Artifact.java',
            'jbuild/api/CustomTaskPhase.java',
          }));
      expect(changes.deletions, isEmpty);
    });

    test('can compute transitive changes from file changes and deletions',
        () async {
          var changes = tree.computeTransitiveChanges([
        FileChange(File('jbuild/artifact/Artifact.java'), ChangeKind.modified),
        FileChange(
            File('jbuild/artifact/VersionRange.java'), ChangeKind.deleted),
      ]);

      expect(
          changes.modified,
          equals(const {
            'jbuild/artifact/Artifact.java',
            'jbuild/artifact/Version.java',
            'jbuild/errors/JBuildException.java',
            'jbuild/errors/Error.java',
          }));
      expect(
          changes.deletions,
          equals(const {
            'jbuild/artifact/VersionRange.java',
          }));

      changes = tree.computeTransitiveChanges([
        FileChange(File('jbuild/artifact/Artifact.java'), ChangeKind.deleted),
      ]);

      expect(changes.modified, isEmpty);
      expect(
          changes.deletions, equals(const {'jbuild/artifact/Artifact.java'}));
    });
  });
}
