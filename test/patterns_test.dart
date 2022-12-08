import 'dart:io';

import 'package:collection/collection.dart';
import 'package:dartle/dartle.dart';
import 'package:jb/src/patterns.dart';
import 'package:test/test.dart';

void main() {
  group('patternFileCollection', () {
    test('empty', () {
      expect(patternFileCollection(const []), hasContents());
    });

    test('simple file', () {
      expect(patternFileCollection(const ['abc']), hasContents(files: {'abc'}));
    });

    test('simple files', () {
      expect(patternFileCollection(const ['abc', 'foo/bar', 'a/b/c']),
          hasContents(files: {'abc', 'foo/bar', 'a/b/c'}));
    });

    test('simple dir', () {
      expect(
          patternFileCollection(const ['abc/']),
          hasContents(dirs: [
            DirectoryEntry(path: 'abc', recurse: false),
          ]));

      expect(
          patternFileCollection(const ['/a/b/c/']),
          hasContents(dirs: [
            DirectoryEntry(path: 'a/b/c', recurse: false),
          ]));
    });

    test('all files matching extension', () {
      expect(
          patternFileCollection(const ['*.txt']),
          hasContents(dirs: [
            DirectoryEntry(path: '.', recurse: false, fileExtensions: {'.txt'})
          ]));

      expect(
          patternFileCollection(const ['foo/*.txt']),
          hasContents(dirs: [
            DirectoryEntry(
                path: 'foo', recurse: false, fileExtensions: {'.txt'})
          ]));

      expect(
          patternFileCollection(const ['foo/bar/zort/*.txt']),
          hasContents(dirs: [
            DirectoryEntry(
                path: 'foo/bar/zort', recurse: false, fileExtensions: {'.txt'})
          ]));
    });

    test('all files matching extension recursive', () {
      expect(
          patternFileCollection(const ['**/*.txt']),
          hasContents(dirs: [
            DirectoryEntry(path: '.', recurse: true, fileExtensions: {'.txt'})
          ]));

      expect(
          patternFileCollection(const ['/foo/**/*.txt']),
          hasContents(dirs: [
            DirectoryEntry(path: 'foo', recurse: true, fileExtensions: {'.txt'})
          ]));
    });

    test('match anything', () {
      expect(patternFileCollection(const ['*']),
          hasContents(dirs: [DirectoryEntry(path: '.', recurse: false)]));

      expect(patternFileCollection(const ['/*']),
          hasContents(dirs: [DirectoryEntry(path: '.', recurse: false)]));
    });

    test('match anything recursive', () {
      expect(patternFileCollection(const ['**']),
          hasContents(dirs: [DirectoryEntry(path: '.', recurse: true)]));

      expect(patternFileCollection(const ['/**']),
          hasContents(dirs: [DirectoryEntry(path: '.', recurse: true)]));

      expect(patternFileCollection(const ['a/b/c/**']),
          hasContents(dirs: [DirectoryEntry(path: 'a/b/c', recurse: true)]));
    });

    test('bad pattern', () {
      expect(() => patternFileCollection(const ['**/foo']),
          throwsA(isA<DartleException>()));
      expect(() => patternFileCollection(const ['/a/**/foo/*.txt']),
          throwsA(isA<DartleException>()));
      expect(() => patternFileCollection(const ['/**/**/*.txt']),
          throwsA(isA<DartleException>()));
    });
  });
}

FileCollectionMatcher hasContents({
  Set<String> files = const {},
  List<DirectoryEntry> dirs = const [],
}) =>
    FileCollectionMatcher(files, dirs);

class FileCollectionMatcher extends Matcher {
  final Set<String> files;
  final List<DirectoryEntry> dirs;

  const FileCollectionMatcher(this.files, this.dirs);

  @override
  Description describe(Description description) =>
      description.add('has files $files and dirs $dirs');

  @override
  bool matches(item, Map matchState) {
    if (item is FileCollection) {
      final entities = item.includedEntities();
      final files = entities.whereType<File>().map((f) => f.path).toSet();
      final dirs = item.directories.map((e) => e.toString()).toList();
      if (!const SetEquality().equals(files, this.files)) {
        matchState[#files] = files;
      }
      if (!const ListEquality()
          .equals(dirs, this.dirs.map((e) => e.toString()).toList())) {
        matchState[#dirs] = dirs;
      }
      return matchState.isEmpty;
    }
    matchState[#item] = item;
    return false;
  }

  @override
  Description describeMismatch(dynamic item, Description mismatchDescription,
      Map matchState, bool verbose) {
    final files = matchState[#files];
    final dirs = matchState[#dirs];
    final item = matchState[#item];
    if (files != null) {
      mismatchDescription.add('contains files $files ');
    }
    if (dirs != null) {
      mismatchDescription.add('contains dirs $dirs ');
    }
    if (item != null) {
      mismatchDescription.add('is $item ');
    }
    return mismatchDescription;
  }
}
