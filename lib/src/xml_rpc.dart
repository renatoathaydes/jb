import 'dart:convert';
import 'dart:typed_data';

import 'package:conveniently/conveniently.dart';
import 'package:dartle/dartle.dart' show DartleException;
import 'package:logging/logging.dart';
import 'package:xml/xml.dart';

import 'utils.dart';

final rpcLogger = Logger('jbuild-rpc');

List<int> createRpcMessage(String methodName, List<Object?> args) {
  final message =
      '<?xml version="1.0"?>'
      '<methodCall>'
      '<methodName>$methodName</methodName>'
      '<params>${_rpcParams(args)}</params>'
      '</methodCall>';
  rpcLogger.fine(() => 'Sending RPC message: $message');
  return utf8.encode(message);
}

String _rpcParams(List<Object?> args) {
  return args.map(_rpcParam).join();
}

String _rpcParam(Object? arg) {
  return '<param>${_rpcValue(arg)}</param>';
}

String _rpcValue(Object? arg) {
  final value = switch (arg) {
    null => '<null />',
    String s => s,
    int n => '<int>$n</int>',
    double n => '<double>$n</double>',
    bool b => '<boolean>${b ? '1' : '0'}</boolean>',
    Uint8List bin => '<base64>${base64Encode(bin)}</base64>',
    DateTime time =>
      '<dateTime.iso8601>${time.toIso8601String()}</dateTime.iso8601>',
    Iterable iter =>
      '<array><data>${iter.map(_rpcValue).join()}</data></array>',
    Map map => _struct(map),
    _ => _struct((arg as dynamic).toJson()),
  };
  return '<value>$value</value>';
}

String _struct(Map map) {
  final builder = StringBuffer();
  builder.write('<struct>');
  map.forEach((k, v) {
    builder
      ..write('<member><name>')
      ..write(k)
      ..write('</name>')
      ..write(_rpcValue(v))
      ..write('</member>');
  });
  builder.write('</struct>');
  return builder.toString();
}

Future<dynamic> parseRpcResponse(Stream<List<int>> rpcResponse) async {
  final message = await rpcResponse.textUtf8();
  rpcLogger.fine(() => 'Received RPC response: $message');
  final XmlDocument doc;
  try {
    doc = XmlDocument.parse(message);
  } on XmlException catch (e) {
    throw DartleException(message: 'RPC response could not be parsed: $e');
  }
  final response = doc
      .getElement('methodResponse')
      .orThrow(
        () => DartleException(
          message:
              'no methodResponse in RPC response:\n'
              '${doc.toXmlString(pretty: true)}',
        ),
      );

  final fault = response.getElement('fault');
  if (fault != null) {
    return _rpcFault(fault);
  }

  final params = response
      .getElement('params')
      .orThrow(
        () => DartleException(
          message:
              'RPC response missing params:\n${doc.toXmlString(pretty: true)}',
        ),
      );

  // params may be empty or contain one result
  final paramList = params.findElements('param').toList(growable: false);
  if (paramList.isEmpty) return null;
  if (paramList.length == 1) {
    final children = paramList[0].childElements;
    if (children.length != 1 || children.first.localName != 'value') {
      throw DartleException(
        message:
            'RPC response param should contain a single value, '
            'but it does not: ${paramList[0].toXmlString(pretty: true)}',
      );
    }
    return _value(paramList[0].getElement('value')!);
  }
  throw DartleException(
    message:
        'RPC response contains multiple parameters, '
        'which is not supported: ${doc.toXmlString(pretty: true)}',
  );
}

dynamic _value(XmlElement value) {
  final children = value.childElements;
  if (children.length != 1) {
    throw DartleException(
      message:
          'RPC value contains too many children: '
          '${value.toXmlString(pretty: true)}',
    );
  }
  final child = children.first;
  return switch (child.localName) {
    'string' => child.innerText,
    'int' || 'i4' => int.parse(child.innerText),
    'double' => double.parse(child.innerText),
    'boolean' when child.innerText == '1' => true,
    'boolean' when child.innerText == '0' => false,
    'boolean' => throw DartleException(
      message: "RPC value invalid for boolean: '${child.innerText}'",
    ),
    'array' => _arrayValue(child),
    'dateTime.iso8601' => DateTime.parse(child.innerText),
    'base64' => base64Decode(child.innerText),
    'null' when child.innerText.isEmpty => null,
    _ => throw DartleException(
      message: 'RPC value type not supported: ${child.localName}',
    ),
  };
}

dynamic _arrayValue(XmlElement element) {
  if (element.childElements.length != 1 ||
      element.childElements.first.localName != 'data') {
    throw DartleException(
      message:
          'RPC array value does not contain single "data" child: '
          '${element.toXmlString(pretty: true)}',
    );
  }
  final data = element.childElements.first;
  return data.childElements.map(_value).toList(growable: false);
}

Future<Never> _rpcFault(XmlElement fault) async {
  final struct = fault
      .getElement('value')
      .orThrow(
        () => 'RPC fault missing value:\n${fault.toXmlString(pretty: true)}',
      )
      .getElement('struct')
      .orThrow(
        () => 'RPC fault missing struct:\n${fault.toXmlString(pretty: true)}',
      );

  final members = struct.findElements('member');
  final faultString = members
      .firstWhere(
        (m) => m.getElement('name')?.innerText == 'faultString',
        orElse: () => throw DartleException(
          message:
              'RPC fault missing faultString:\n'
              '${struct.toXmlString(pretty: true)}',
        ),
      )
      .getElement('value')
      .orThrow(
        () =>
            'RPC faultString missing value:\n'
            '${struct.toXmlString(pretty: true)}',
      )
      .getElement('string')
      .orThrow(
        () =>
            'RPC faultString missing string value:\n'
            '${struct.toXmlString(pretty: true)}',
      )
      .innerText;

  final faultCode = int.parse(
    members
        .firstWhere(
          (m) => m.getElement('name')?.innerText == 'faultCode',
          orElse: () => throw DartleException(
            message:
                'RPC faultCode missing:\n'
                '${struct.toXmlString(pretty: true)}',
          ),
        )
        .getElement('value')
        .orThrow(
          () =>
              'RPC faultCode missing value:\n'
              '${struct.toXmlString(pretty: true)}',
        )
        .getElement('int')
        .orThrow(
          () =>
              'RPC faultCode missing int value:\n'
              '${struct.toXmlString(pretty: true)}',
        )
        .innerText,
  );

  throw DartleException(message: faultString, exitCode: faultCode);
}
