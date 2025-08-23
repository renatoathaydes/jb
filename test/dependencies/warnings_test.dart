import 'package:dartle/dartle.dart' show activateLogging;
import 'package:jb/src/config.dart'
    show DependencyWarning, VersionConflict, ResolvedDependency, DependencySpec;
import 'package:jb/src/dependencies/warnings.dart';
import 'package:logging/logging.dart';
import 'package:test/test.dart';

void main() {
  activateLogging(Level.FINER);

  test('No warnings found', () {
    expect(computeWarnings([]), isEmpty);
    expect(computeWarnings([_dep('a:b:1')]), isEmpty);
    expect(computeWarnings([_dep('a:b:1'), _dep('a:c:1')]), isEmpty);
  });

  test('Find warnings in direct dependencies', () {
    expect(
      computeWarnings([_dep('a:b:1.0'), _dep('a:b:2.1')]).toList(),
      equals([
        DependencyWarning(
          artifact: 'a:b',
          versionConflicts: [
            VersionConflict(version: '1.0', requestedBy: []),
            VersionConflict(version: '2.1', requestedBy: []),
          ],
        ),
      ]),
    );
  });

  test('Find warnings in direct+transitive dependencies', () {
    expect(
      computeWarnings([
        _dep('a:b:1.0'),
        _dep('b:c:1.1', true, ['a:b:2.1']),
        _dep('a:b:2.1', false),
      ]).toList(),
      equals([
        DependencyWarning(
          artifact: 'a:b',
          versionConflicts: [
            VersionConflict(version: '1.0', requestedBy: []),
            VersionConflict(version: '2.1', requestedBy: ['b:c:1.1']),
          ],
        ),
      ]),
    );
  });

  test('Find warnings in transitive+transitive dependencies', () {
    expect(
      computeWarnings([
        _dep('b:c:1.0', true, ['c:d:2.0']),
        _dep('b:d:1.1', true, ['a:b:2.1']),
        _dep('a:b:2.1', false),
        _dep('c:d:2.0', false, ['a:b:1.4']),
        _dep('a:b:1.4', false),
      ]).toList(),
      equals([
        DependencyWarning(
          artifact: 'a:b',
          versionConflicts: [
            VersionConflict(
              version: '1.4',
              requestedBy: ['b:c:1.0', 'c:d:2.0'],
            ),
            VersionConflict(version: '2.1', requestedBy: ['b:d:1.1']),
          ],
        ),
      ]),
    );
  });
}

ResolvedDependency _dep(
  String artifact, [
  bool isDirect = true,
  List<String> deps = const [],
]) {
  return ResolvedDependency(
    artifact: artifact,
    spec: const DependencySpec(),
    sha1: '',
    isDirect: isDirect,
    dependencies: deps,
  );
}
