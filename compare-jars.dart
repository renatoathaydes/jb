import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';

final class Jar {
  final String path;

  const Jar(this.path);

  Future<String> sha() async {
    final bytes = await File(path).readAsBytes();
    return sha1.convert(bytes).toString();
  }

  Stream<ArchiveFile> entries() async* {
    final bytes = await File(path).readAsBytes();
    final decoder = ZipDecoder();
    final archive = decoder.decodeBytes(bytes);
    for (final file in archive) {
      if (file.isFile) {
        yield file;
      }
    }
  }
}

void main(List<String> args) async {
  if (args.length != 2) {
    throw Exception('Expected 2 arguments - the files to compare');
  }
  final jar1 = Jar(args[0]);
  final jar2 = Jar(args[1]);

  final shaFile1 = await jar1.sha();
  final shaFile2 = await jar2.sha();

  if (shaFile1 == shaFile2) {
    print('Files are identical!');
    return;
  }

  print('File SHA1 differs: $shaFile1 != $shaFile2');

  final jar1Entries = await jar1.entries().toList();
  final jar2Entries = await jar2.entries().toList();

  var ok = compareNames(jar1Entries, jar2Entries);
  ok &= await compareEntries(jar1Entries, jar2Entries);
  if (ok) {
    print('Files have different hashes but all entries seem identical!');
  }
  // should have returned already if files had the same hash!
  exit(1);
}

bool compareNames(
  List<ArchiveFile> jar1Entries,
  List<ArchiveFile> jar2Entries,
) {
  final jar1Names = jar1Entries.map((e) => e.name).toList();
  final jar2Names = jar2Entries.map((e) => e.name).toList();
  if (jar1Names.length != jar2Names.length) {
    throw Exception(
      'Jars have different number of entries: ${jar1Names.length} != ${jar2Names.length}',
    );
  }
  for (var i = 0; i < jar1Names.length; i++) {
    final name1 = jar1Names[i];
    final name2 = jar2Names[i];
    if (name1 != name2) {
      print('Found different entries [$i]: $name1 != $name2');
      return false;
    }
  }
  return true;
}

Future<bool> compareEntries(
  List<ArchiveFile> jar1Entries,
  List<ArchiveFile> jar2Entries,
) async {
  var shasOk = true, attrsOk = true;

  // jars already asserted to have the same number of entries
  for (var i = 0; i < jar1Entries.length; i++) {
    final (entry1, entry2) = (jar1Entries[i], jar2Entries[i]);
    assert(entry1.name == entry2.name);
    final s1 = sha1.convert(entry1.content).toString();
    final s2 = sha1.convert(entry2.content).toString();
    if (s1 != s2) {
      print('Entry ${entry1.name} SHA1 differs: $s1 != $s2');
      shasOk = false;
    }
    if (entry1.creationTime != entry2.creationTime) {
      print(
        'Entry ${entry1.name} creation time differs: ${entry1.creationTime} != ${entry2.creationTime}',
      );
      attrsOk = false;
    }
    if (entry1.lastModTime != entry2.lastModTime) {
      print(
        'Entry ${entry1.name} last modification time differs: ${entry1.lastModTime} != ${entry2.lastModTime}',
      );
      attrsOk = false;
    }
    if (entry1.isCompressed != entry2.isCompressed) {
      print(
        'Entry ${entry1.name} compression differs: ${entry1.isCompressed} != ${entry2.isCompressed}',
      );
      attrsOk = false;
    }
    if (entry1.comment != entry2.comment) {
      print(
        'Entry ${entry1.name} comment differs: ${entry1.comment} != ${entry2.comment}',
      );
      attrsOk = false;
    }
  }
  if (!shasOk) {
    print('Not all jars entries have the same contents');
  }
  if (!attrsOk) {
    print('Jars have identical content but with different attributes');
  }
  return shasOk && attrsOk;
}
