import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:conveniently/conveniently.dart';
import 'package:dartle/dartle.dart';
import 'package:dartle/dartle_cache.dart';
import 'package:jb/src/xml_rpc.dart';
import 'package:jb/src/xml_rpc_structs.dart';
import 'package:test/test.dart';

void main() {
  group('XML-RPC Request', () {
    test('method call with no args', () {
      expect(
          utf8.decode(createRpcMessage('hello', const [])),
          equals('<?xml version="1.0"?>'
              '<methodCall>'
              '<methodName>hello</methodName>'
              '<params></params>'
              '</methodCall>'));
    });

    test('method call with null arg', () {
      expect(
          utf8.decode(createRpcMessage('example', [null])),
          equals('<?xml version="1.0"?>'
              '<methodCall>'
              '<methodName>example</methodName>'
              '<params><param><value><null /></value></param></params>'
              '</methodCall>'));
    });

    test('method call with boolean arg', () {
      expect(
          utf8.decode(createRpcMessage('num', [false, true])),
          equals('<?xml version="1.0"?>'
              '<methodCall>'
              '<methodName>num</methodName>'
              '<params>'
              '<param><value><boolean>0</boolean></value></param>'
              '<param><value><boolean>1</boolean></value></param>'
              '</params>'
              '</methodCall>'));
    });

    test('method call with int arg', () {
      for (final n in [1, 100, 12345678, 0, -1, -32]) {
        expect(
            utf8.decode(createRpcMessage('num', [n])),
            equals('<?xml version="1.0"?>'
                '<methodCall>'
                '<methodName>num</methodName>'
                '<params><param><value><int>$n</int></value></param></params>'
                '</methodCall>'));
      }
    });

    test('method call with double arg', () {
      for (final n in [3.1415, 1.0, 0.0, -1.0]) {
        expect(
            utf8.decode(createRpcMessage('num', [n])),
            equals('<?xml version="1.0"?>'
                '<methodCall>'
                '<methodName>num</methodName>'
                '<params><param><value><double>$n</double></value></param></params>'
                '</methodCall>'));
      }
    });

    test('method call with string arg', () {
      expect(
          utf8.decode(createRpcMessage('Hi.hello', const ['joe'])),
          equals('<?xml version="1.0"?>'
              '<methodCall>'
              '<methodName>Hi.hello</methodName>'
              '<params><param>'
              '<value>joe</value>'
              '</param></params>'
              '</methodCall>'));
    });

    test('method call with many string args', () {
      expect(
          utf8.decode(createRpcMessage('sayHi', const ['joe', 'mary'])),
          equals('<?xml version="1.0"?>'
              '<methodCall>'
              '<methodName>sayHi</methodName>'
              '<params>'
              '<param><value>joe</value></param>'
              '<param><value>mary</value></param>'
              '</params>'
              '</methodCall>'));
    });

    test('method call with single string array arg', () {
      expect(
          utf8.decode(createRpcMessage('sayHi', const [
            ['joe', 'mary']
          ])),
          equals('<?xml version="1.0"?>'
              '<methodCall>'
              '<methodName>sayHi</methodName>'
              '<params>'
              '<param><value><array><data>'
              '<value>joe</value>'
              '<value>mary</value>'
              '</data></array></value></param>'
              '</params>'
              '</methodCall>'));
    });

    test('method call with single int array arg', () {
      expect(
          utf8.decode(createRpcMessage('numbers', const [
            [42, 24]
          ])),
          equals('<?xml version="1.0"?>'
              '<methodCall>'
              '<methodName>numbers</methodName>'
              '<params>'
              '<param><value><array><data>'
              '<value><int>42</int></value>'
              '<value><int>24</int></value>'
              '</data></array></value></param>'
              '</params>'
              '</methodCall>'));
    });

    test('method call with array of arrays arg', () {
      expect(
          utf8.decode(createRpcMessage('take', const [
            1,
            ['hi', true],
            [],
          ])),
          equals('<?xml version="1.0"?>'
              '<methodCall>'
              '<methodName>take</methodName>'
              '<params>'
              '<param><value><int>1</int></value></param>'
              '<param><value><array><data>'
              '<value>hi</value>'
              '<value><boolean>1</boolean></value>'
              '</data></array></value></param>'
              '<param><value><array><data>'
              '</data></array></value></param>'
              '</params>'
              '</methodCall>'));
    });

    test('method call with DateTime argument', () {
      final time = DateTime.parse('19980717T14:08:55');
      expect(
          utf8.decode(createRpcMessage('time', [time])),
          equals('<?xml version="1.0"?>'
              '<methodCall>'
              '<methodName>time</methodName>'
              '<params>'
              '<param><value>'
              '<dateTime.iso8601>1998-07-17T14:08:55.000</dateTime.iso8601>'
              '</value></param>'
              '</params>'
              '</methodCall>'));
    });

    test('method call with Uint8List argument', () {
      final value = Uint8List.fromList([24, 42]);
      expect(
          utf8.decode(createRpcMessage('b64', [value])),
          equals('<?xml version="1.0"?>'
              '<methodCall>'
              '<methodName>b64</methodName>'
              '<params>'
              '<param><value>'
              '<base64>GCo=</base64>'
              '</value></param>'
              '</params>'
              '</methodCall>'));
    });

    test('method call with struct argument', () {
      expect(
          utf8.decode(createRpcMessage('struct', [
            ChangeSet([
              FileChange(File('foo'), ChangeKind.added),
              FileChange(Directory('bar/zort'), ChangeKind.modified),
            ], [
              FileChange(File('output'), ChangeKind.deleted),
            ]).toMap(),
          ])),
          equals('<?xml version="1.0"?>'
              '<methodCall>'
              '<methodName>struct</methodName>'
              '<params>'
              '<param><value>'
              '<struct>'
              '<name>inputChanges</name>'
              '<value><array><data>'
              '<value><struct>'
              '<name>path</name><value>foo</value>'
              '<name>kind</name><value>added</value>'
              '</struct></value>'
              '<value><struct>'
              '<name>path</name><value>bar/zort</value>'
              '<name>kind</name><value>modified</value>'
              '</struct></value>'
              '</data></array></value>'
              '<name>outputChanges</name>'
              '<value><array><data>'
              '<value><struct>'
              '<name>path</name><value>output</value>'
              '<name>kind</name><value>deleted</value>'
              '</struct></value>'
              '</data></array></value>'
              '</struct>'
              '</value></param>'
              '</params>'
              '</methodCall>'));
    });
  });

  group('XML-RPC Response', () {
    test('No value', () async {
      expect(
          await parseRpcResponse(
              _toBytes('<?xml version="1.0" encoding="UTF-8"?>'
                  '<methodResponse><params>'
                  '</params></methodResponse>')),
          isNull);
    });

    test('Single int value', () {
      4.timesIndex$((index) async {
        final number = index * 3;
        expect(
            await parseRpcResponse(
                _toBytes('<?xml version="1.0" encoding="UTF-8"?>'
                    '<methodResponse><params>'
                    '<param><value><int>$number</int></value></param>'
                    '</params></methodResponse>')),
            equals(number));
      });
    });

    test('Single i4 value', () {
      4.timesIndex$((index) async {
        final number = index * 3;
        expect(
            await parseRpcResponse(
                _toBytes('<?xml version="1.0" encoding="UTF-8"?>'
                    '<methodResponse><params>'
                    '<param><value><i4>$number</i4></value></param>'
                    '</params></methodResponse>')),
            equals(number));
      });
    });

    test('Single double value', () {
      4.timesIndex$((index) async {
        final number = index * 3.1415;
        expect(
            await parseRpcResponse(
                _toBytes('<?xml version="1.0" encoding="UTF-8"?>'
                    '<methodResponse><params>'
                    '<param><value><double>$number</double></value></param>'
                    '</params></methodResponse>')),
            equals(number));
      });
    });

    test('Single null value', () async {
      expect(
          await parseRpcResponse(
              _toBytes('<?xml version="1.0" encoding="UTF-8"?>'
                  '<methodResponse><params>'
                  '<param><value><null /></value></param>'
                  '</params></methodResponse>')),
          isNull);
    });

    test('Single DateTime value', () async {
      final time = DateTime.parse('19980717T14:08:55');
      expect(
          await parseRpcResponse(
              _toBytes('<?xml version="1.0" encoding="UTF-8"?>'
                  '<methodResponse><params>'
                  '<param><value>'
                  '<dateTime.iso8601>1998-07-17T14:08:55.000</dateTime.iso8601>'
                  '</value></param>'
                  '</params></methodResponse>')),
          equals(time));
    });

    test('Single binary value', () async {
      final value = Uint8List.fromList([24, 42]);
      expect(
          await parseRpcResponse(
              _toBytes('<?xml version="1.0" encoding="UTF-8"?>'
                  '<methodResponse><params>'
                  '<param><value>'
                  '<base64>GCo=</base64>'
                  '</value></param>'
                  '</params></methodResponse>')),
          equals(value));
    });

    test('Single boolean value', () {
      2.timesIndex$((index) async {
        final boolean = index % 2 == 0 ? '1' : '0';
        expect(
            await parseRpcResponse(
                _toBytes('<?xml version="1.0" encoding="UTF-8"?>'
                    '<methodResponse><params>'
                    '<param><value><boolean>$boolean</boolean></value></param>'
                    '</params></methodResponse>')),
            equals(boolean == '1'));
      });
    });

    test('Empty array value', () async {
      expect(
          await parseRpcResponse(
              _toBytes('<?xml version="1.0" encoding="UTF-8"?>'
                  '<methodResponse><params>'
                  '<param><value><array><data/></array></value></param>'
                  '</params></methodResponse>')),
          equals([]));
    });

    test('Array of values', () async {
      expect(
          await parseRpcResponse(
              _toBytes('<?xml version="1.0" encoding="UTF-8"?>'
                  '<methodResponse><params>'
                  '<param><value><array><data>'
                  '<value><boolean>1</boolean></value>'
                  '<value><int>32</int></value>'
                  '<value><array><data/></array></value>'
                  '</data></array></value></param>'
                  '</params></methodResponse>')),
          equals([true, 32, []]));
    });

    test('Fault', () {
      expectLater(
          () =>
              parseRpcResponse(_toBytes('<?xml version="1.0" encoding="UTF-8"?>'
                  '<methodResponse><fault><value>'
                  '<struct>'
                  ' <member>'
                  '  <name>faultCode</name>'
                  '  <value><int>4</int></value>'
                  ' </member>'
                  ' <member>'
                  '  <name>faultString</name>'
                  '  <value><string>Too many parameters.</string></value>'
                  ' </member>'
                  '</struct>'
                  '</value></fault></methodResponse>')),
          throwsA(isA<DartleException>()
              .having(
                  (a) => a.message, 'message', equals('Too many parameters.'))
              .having((a) => a.exitCode, 'exitCode', equals(4))));
    });
  });
}

Stream<List<int>> _toBytes(String message) {
  return Stream.fromIterable([utf8.encode(message)]);
}
