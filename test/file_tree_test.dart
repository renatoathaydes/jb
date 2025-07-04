import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dartle/dartle_cache.dart';
import 'package:jb/src/file_tree.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

const exampleFileTree = [
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
];

void main() {
  group('FileTree', () {
    late FileTree tree;

    setUpAll(() async {
      tree = await loadFileTree(Stream.fromIterable(exampleFileTree));
    });

    test('can compute transitive dependents of a file', () async {
      expect(
        tree.dependentsOf(p.join('jbuild', 'artifact', 'Artifact.java')),
        equals(const <String>{}),
      );

      expect(
        tree.dependentsOf(p.join('jbuild', 'errors', 'Error.java')),
        equals({
          p.join('jbuild', 'errors', 'JBuildException.java'),
          p.join('jbuild', 'artifact', 'Artifact.java'),
        }),
      );
    });

    test('can compute transitive changes from file changes', () async {
      var changes = tree.computeTransitiveChanges([
        FileChange(
          File(p.join('jbuild', 'artifact', 'Artifact.java')),
          ChangeKind.modified,
        ),
      ]);

      expect(
        changes.modified,
        equals({p.join('jbuild', 'artifact', 'Artifact.java')}),
      );
      expect(changes.deletions, isEmpty);

      changes = tree.computeTransitiveChanges([
        FileChange(
          File(p.join('jbuild', 'artifact', 'Version.java')),
          ChangeKind.modified,
        ),
        FileChange(
          File(p.join('jbuild', 'api', 'CustomTaskPhase.java')),
          ChangeKind.modified,
        ),
      ]);

      expect(
        changes.modified,
        equals({
          p.join('jbuild', 'artifact', 'Version.java'),
          p.join('jbuild', 'errors', 'Error.java'),
          p.join('jbuild', 'errors', 'JBuildException.java'),
          p.join('jbuild', 'artifact', 'Artifact.java'),
          p.join('jbuild', 'api', 'CustomTaskPhase.java'),
        }),
      );
      expect(changes.deletions, isEmpty);
    });

    test(
      'can compute transitive changes from file changes and deletions',
      () async {
        var changes = tree.computeTransitiveChanges([
          FileChange(
            File(p.join('jbuild', 'artifact', 'Artifact.java')),
            ChangeKind.modified,
          ),
          FileChange(
            File(p.join('jbuild', 'artifact', 'VersionRange.java')),
            ChangeKind.deleted,
          ),
        ]);

        expect(
          changes.modified,
          equals({
            p.join('jbuild', 'artifact', 'Artifact.java'),
            p.join('jbuild', 'artifact', 'Version.java'),
            p.join('jbuild', 'errors', 'JBuildException.java'),
            p.join('jbuild', 'errors', 'Error.java'),
          }),
        );
        expect(
          changes.deletions,
          equals({p.join('jbuild', 'artifact', 'VersionRange.java')}),
        );

        changes = tree.computeTransitiveChanges([
          FileChange(
            File(p.join('jbuild', 'artifact', 'Artifact.java')),
            ChangeKind.deleted,
          ),
        ]);

        expect(changes.modified, isEmpty);
        expect(
          changes.deletions,
          equals({p.join('jbuild', 'artifact', 'Artifact.java')}),
        );
      },
    );

    test('can compute class files from Java files', () {
      expect(
        tree
            .classFilesOf(p.join('jbuild', 'errors', 'JBuildException.java'))
            .toSet(),
        equals({
          r'jbuild/errors/JBuildException$ErrorCause.class',
          r'jbuild/errors/JBuildException.class',
        }),
      );
    });

    test('can merge with another tree', () async {
      final changesTree = await loadFileTree(
        Stream.fromIterable(const [
          // JBuildException was changed to not depend on Error anymore
          r'  - jbuild.errors.JBuildException (JBuildException.java):',
          r'    * some.NewType',
          // and a new type was added
          r'  - some.NewType (NewType.java):',
          r'    * jbuild.artifact.Version',
        ]),
      );

      final mergedTree = tree.merge(changesTree, {
        p.join('jbuild', 'errors', 'Error.java'),
      });

      const expectedTree = [
        r'  - jbuild.api.CustomTaskPhase (CustomTaskPhase.java):',
        r'  - jbuild.artifact.Artifact (Artifact.java):',
        r'    * jbuild.artifact.Version',
        r'    * jbuild.errors.JBuildException',
        r'  - jbuild.errors.JBuildException$ErrorCause (JBuildException.java):',
        r'    * jbuild.errors.JBuildException$ErrorCause',
        r'    * jbuild.errors.JBuildException',
        r'  - jbuild.errors.JBuildException (JBuildException.java):',
        r'    * some.NewType',
        r'  - jbuild.artifact.Version (Version.java):',
        r'    * jbuild.artifact.VersionRange',
        r'  - jbuild.artifact.VersionRange (VersionRange.java):',
        r'  - jbuild.maven.Maven (Maven.java):',
        r'  - some.NewType (NewType.java):',
        r'    * jbuild.artifact.Version',
      ];

      expect(await _serializedTree(mergedTree), equals(expectedTree));
    });

    test('can be serialized', () async {
      final serializedLines = await _serializedTree(tree);
      expect(serializedLines, equals(exampleFileTree.sublist(1)));
    });
  });
}

Future<List<String>> _serializedTree(FileTree tree) async {
  final sc = StreamController<List<int>>();
  tree.serialize(sc.sink);
  return await sc.stream
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .toList();
}
