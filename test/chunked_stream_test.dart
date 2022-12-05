import 'dart:convert';
import 'dart:typed_data';

import 'package:jb/src/chunked_stream.dart';
import 'package:test/expect.dart';
import 'package:test/scaffolding.dart';

void main() {
  const decoder = ChunkDecoder();

  group('ChunkedStream', () {
    test('can read empty chunk', () {
      expect(decoder.convert(Uint8List.fromList(const [0, 0, 0, 0])),
          equals(const []));
    });

    test('can read single byte chunk', () {
      expect(decoder.convert(Uint8List.fromList(const [0, 0, 0, 1, 0xab])),
          equals(const [0xab]));
    });

    test('can read multi-byte chunk', () {
      expect(
          decoder.convert(Uint8List.fromList([
            0, 0, 1, 1, ...List.generate(0x101, (i) => i & 0xff), // chunk 1
            0, 0, 0, 2, 0x0a, 0xbb, // chunk 2
            0, 0, 0, 1, 0xff, // final chunk
          ])),
          equals([...List.generate(0x101, (i) => i & 0xff), 0x0a, 0xbb, 0xff]));
    });

    test('can be used in pipeline', () {
      final chunk1 = 'abcdefghijklmnopqrstuvxzwy'.codeUnits;
      final chunk2 = '0123456789'.codeUnits;
      final len = ByteData(4);
      len.setInt32(0, chunk1.length);
      final len2 = ByteData(4);
      len2.setInt32(0, chunk2.length);

      final result = Stream.fromIterable([
        len.buffer.asUint8List(),
        chunk1,
        [...len2.buffer.asUint8List(), ...chunk2]
      ]).transform(decoder).transform(utf8.decoder);

      expect(
          result,
          emitsInOrder(
              [equals('abcdefghijklmnopqrstuvxzwy'), equals('0123456789')]));
    });
  });
}
