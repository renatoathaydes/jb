import 'dart:convert';

import 'package:conveniently/conveniently.dart';
import 'package:dartle/dartle.dart' show DartleException;
import 'package:logging/logging.dart';
import 'package:xml/xml.dart';

import 'utils.dart';

final rpcLogger = Logger('jbuild-rpc');

List<int> createRpcMessage(String methodName, List<Object?> args) {
  final message = '<?xml version="1.0"?>'
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
  return switch (arg) {
    null => '<param><value></value></param>',
    String s => '<param>${_rpcValue(s)}</param>',
    List list when (list.every((s) => s == null || s is String)) =>
      '<param><value><array><data>'
          '${list.map((s) => _rpcValue(s as String?)).join()}'
          '</data></array></value></param>',
    _ => throw DartleException(
        message: 'Unsupported RPC method call parameter: $arg')
  };
}

String _rpcValue(String? arg) {
  if (arg == null) {
    return '<value><null /></value>';
  }
  return '<value>$arg</value>';
}

Future<dynamic> parseRpcResponse(Stream<List<int>> rpcResponse) async {
  final message = await rpcResponse.text();
  rpcLogger.fine(() => 'Received RPC response: $message');
  final XmlDocument doc;
  try {
    doc = XmlDocument.parse(message);
    // await data.transform(ChunkDecoder()).transform(utf8.decoder).first);
  } on XmlException catch (e) {
    throw DartleException(message: 'RPC response could not be parsed: $e');
  }
  final response =
      doc.getElement('methodResponse').orThrow(() => DartleException(
          message: 'no methodResponse in RPC response:\n'
              '${doc.toXmlString(pretty: true)}'));

  final fault = response.getElement('fault');
  if (fault != null) {
    return _rpcFault(fault);
  }

  final params = response.getElement('params').orThrow(() => DartleException(
      message:
          'RPC response missing params:\n${doc.toXmlString(pretty: true)}'));

  // params may be empty or contain one result
  final paramList = params.findElements('param').toList(growable: false);
  if (paramList.isEmpty) return null;
  if (paramList.length == 1) {
    final children = paramList[0].childElements;
    if (children.length != 1 || children.first.localName != 'value') {
      throw DartleException(
          message: 'RPC response param should contain a single value, '
              'but it does not: ${paramList[0].toXmlString(pretty: true)}');
    }
    return _value(paramList[0].getElement('value')!);
  }
  throw DartleException(
      message: 'RPC response contains multiple parameters, '
          'which is not supported: ${doc.toXmlString(pretty: true)}');
}

dynamic _value(XmlElement value) {
  final children = value.childElements;
  if (children.length != 1) {
    throw DartleException(
        message: 'RPC value contains too many children: '
            '${value.toXmlString(pretty: true)}');
  }
  final child = children.first;
  return switch (child.localName) {
    'string' => child.innerText,
    'int' || 'i4' => int.parse(child.innerText),
    'double' => double.parse(child.innerText),
    'boolean' => child.innerText == '1',
    'array' => _arrayValue(child),
    _ => throw DartleException(
        message: 'RPC value type not supported: ${child.localName}')
  };
}

dynamic _arrayValue(XmlElement element) {
  if (element.childElements.length != 1 ||
      element.childElements.first.localName != 'data') {
    throw DartleException(
        message: 'RPC array value does not contain single "data" child: '
            '${element.toXmlString(pretty: true)}');
  }
  final data = element.childElements.first;
  return data.childElements.map(_value).toList(growable: false);
}

Future<Never> _rpcFault(XmlElement fault) async {
  final struct = fault
      .getElement('value')
      .orThrow(
          () => 'RPC fault missing value:\n${fault.toXmlString(pretty: true)}')
      .getElement('struct')
      .orThrow(() =>
          'RPC fault missing struct:\n${fault.toXmlString(pretty: true)}');

  final members = struct.findElements('member');
  final faultString = members
      .firstWhere((m) => m.getElement('name')?.innerText == 'faultString',
          orElse: () => throw DartleException(
              message: 'RPC fault missing faultString:\n'
                  '${struct.toXmlString(pretty: true)}'))
      .getElement('value')
      .orThrow(() => 'RPC faultString missing value:\n'
          '${struct.toXmlString(pretty: true)}')
      .getElement('string')
      .orThrow(() => 'RPC faultString missing string value:\n'
          '${struct.toXmlString(pretty: true)}')
      .innerText;

  final faultCode = int.parse(members
      .firstWhere((m) => m.getElement('name')?.innerText == 'faultCode',
          orElse: () => throw DartleException(
              message: 'RPC faultCode missing:\n'
                  '${struct.toXmlString(pretty: true)}'))
      .getElement('value')
      .orThrow(() => 'RPC faultCode missing value:\n'
          '${struct.toXmlString(pretty: true)}')
      .getElement('int')
      .orThrow(() => 'RPC faultCode missing int value:\n'
          '${struct.toXmlString(pretty: true)}')
      .innerText);

  throw DartleException(message: faultString, exitCode: faultCode);
}
