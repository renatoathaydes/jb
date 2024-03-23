import 'dart:convert';

import 'package:conveniently/conveniently.dart';
import 'package:dartle/dartle.dart';
import 'package:jb/src/xml_rpc.dart';
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
