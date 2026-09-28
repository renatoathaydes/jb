import 'dart:io' show File;

import 'package:crypto/crypto.dart' show sha1, md5, Hash;

Future<String> computeSha1(String filePath) {
  return _hash(sha1, filePath);
}

Future<String> computeMd5(String filePath) {
  return _hash(md5, filePath);
}

Future<String> _hash(Hash hash, String filePath) async {
  final file = File(filePath);
  final digest = await hash.bind(file.openRead()).first;
  return digest.toString();
}
