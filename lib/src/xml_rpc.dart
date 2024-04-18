import 'dart:convert';

import 'package:conveniently/conveniently.dart';
import 'package:dartle/dartle.dart' show DartleException;
import 'package:logging/logging.dart';
import 'package:xml/xml.dart';

import 'utils.dart';

final rpcLogger = Logger('jbuild-rpc');

List<int> createRpcMessage(String methodName, List<Object> args) {
  final message = '<?xml version="1.0"?>'
      '<methodCall>'
      '<methodName>$methodName</methodName>'
      '<params>${_rpcParams(args)}</params>'
      '</methodCall>';
  rpcLogger.fine(() => 'Sending RPC message: $message');
  return utf8.encode(message);
}

String _rpcParams(List<Object> args) {
  return args.map(_rpcParam).join();
}

String _rpcParam(Object arg) {
  return switch (arg) {
    String s => '<param>${_rpcValue(s)}</param>',
    List list when (list.every((s) => s is String)) =>
      '<param><value><array><data>'
          '${list.map((s) => _rpcValue(s as String)).join()}'
          '</data></array></value></param>',
    _ => throw DartleException(
        message: 'Unsupported RPC method call parameter: $arg')
  };
}

String _rpcValue(String arg) {
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
    return _value(paramList[0]);
  }
  throw DartleException(
      message: 'RPC response contains multiple parameters, '
          'which is not supported: ${doc.toXmlString(pretty: true)}');
}

dynamic _value(XmlElement element) {
  final value = element.getElement('value');
  if (value == null) return null;
  final children = value.children;
  if (children.length != 1) {
    throw DartleException(
        message: 'RPC value contains too many children: '
            '${value.toXmlString(pretty: true)}');
  }
  final child = children.first as XmlElement;
  return switch (child.localName) {
    'string' => child.innerText,
    'int' || 'i4' => int.parse(child.innerText),
    'double' => double.parse(child.innerText),
    'boolean' => child.innerText == '1',
    _ => throw DartleException(
        message: 'RPC value type not supported: ${child.nodeType.name}')
  };
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
