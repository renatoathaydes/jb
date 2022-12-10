import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dartle/dartle.dart';
import 'package:jb/jb.dart';
import 'package:jb/src/chunked_stream.dart';
import 'package:jb/src/utils.dart';
import 'package:logging/logging.dart';
import 'package:xml/xml.dart';

import 'output_consumer.dart';

final _closeMessage = Uint8List.fromList(const [0, 0, 0, 0]);

class _Proc {
  final Process process;
  final IOSink stdin;
  final Stream<List<int>> stdout;

  _Proc(this.process)
      : stdin = process.stdin,
        stdout = process.stdout.asBroadcastStream();
}

class JvmExecutor {
  final String _classpath;

  Future<_Proc>? _process;

  JvmExecutor(this._classpath) {
    logger.info('classpath: $_classpath');
  }

  Future<int> runJBuild(List<String> args,
      {Map<String, String> env = const {}}) async {
    final value =
        await run('jbuild.cli.RpcMain', 'runJBuild', [args], env: env);
    if (value is int) {
      return value;
    }
    throw DartleException(
        message: 'JBuild RPC returned unexpected value: $value');
  }

  Future<dynamic> run(String? className, String methodName, List args,
      {Map<String, String> env = const {}}) async {
    final process = await _startOrGetProcess(env);

    final stderrConsumer = _RpcExecLogger('err>', methodName);
    process.process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(stderrConsumer);
    process.stdin.add(_createRpcMessage(className, methodName, args));
    return _parseRpcResponse(process.stdout);
  }

  Future<_Proc> _startOrGetProcess(Map<String, String> env) {
    var proc = _process;
    if (proc == null) {
      proc = Process.start('java', ['-cp', _classpath, 'jbuild.cli.RpcMain'],
              runInShell: true,
              workingDirectory: Directory.current.path,
              environment: env)
          .then((p) => _Proc(p));
      _process = proc;
    }
    return proc;
  }

  Future<int> close() async {
    final procFuture = _process;
    if (procFuture != null) {
      final proc = await procFuture;
      proc.stdin.add(_closeMessage);
      try {
        await _parseRpcResponse(proc.stdout);
      } catch (e) {
        logger.fine('Problem closing RPC executor: $e');
      }
      return await proc.process.exitCode;
    }
    return 0;
  }

  List<int> _createRpcMessage(
      String? className, String methodName, List<dynamic> args) {
    final method = className == null ? methodName : '$className.$methodName';
    final message = '<?xml version="1.0"?>'
        '<methodCall>'
        '<methodName>$method</methodName>'
        '<params>${_rpcParams(args)}</params>'
        '</methodCall>';
    logger.fine(() => 'Sending RPC message: $message');
    final rpcMessage = utf8.encode(message);
    final len = ByteData(4)..setInt32(0, rpcMessage.length);
    return [...len.buffer.asUint8List(), ...rpcMessage];
  }

  String _rpcParams(List<dynamic> args) {
    return args.map(_rpcParam).join();
  }

  String _rpcParam(dynamic arg) {
    return '<param>${_rpcValue(arg)}</param>';
  }

  String _rpcValue(dynamic arg) {
    if (arg is String) {
      return '<value><string>$arg</string></value>';
    }
    if (arg is Iterable<String>) {
      return '<value><array><data>'
          '${arg.map(_rpcValue).join()}'
          '</data></array></value>';
    }
    if (arg is int) {
      return '<value><i4>$arg</i4></value>';
    }
    if (arg is bool) {
      return '<value><boolean>$arg</boolean></value>';
    }
    if (arg is double) {
      return '<value><double>$arg</double></value>';
    }
    throw ArgumentError('type is not supported in RPC: ${arg.runtimeType}');
  }

  Future<dynamic> _parseRpcResponse(Stream<List<int>> data) async {
    final messages =
        data.transform(const ChunkDecoder()).transform(utf8.decoder);
    final message = await messages.first;
    logger.fine(() => 'Received RPC response: $message');
    final XmlDocument doc;
    try {
      doc = XmlDocument.parse(message);
      // await data.transform(ChunkDecoder()).transform(utf8.decoder).first);
    } on XmlException catch (e) {
      throw DartleException(message: 'RPC response could not be parsed: $e');
    }
    final response = doc
        .getElement('methodResponse')
        .orThrow('no methodResponse in RPC response:\n'
            '${doc.toXmlString(pretty: true)}');

    final fault = response.getElement('fault');
    if (fault != null) {
      return _rpcFault(fault);
    }

    final params = response.getElement('params').orThrowA(
        () => 'RPC response missing params:\n${doc.toXmlString(pretty: true)}');

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
    switch (child.localName) {
      case 'string':
        return child.text;
      case 'int':
      case 'i4':
        return int.parse(child.text);
      case 'double':
        return double.parse(child.text);
      case 'boolean':
        return child.text == '1';
      default:
        throw DartleException(
            message: 'RPC value type not supported: ${child.nodeType.name}');
    }
  }

  Future<Never> _rpcFault(XmlElement fault) async {
    final struct = fault
        .getElement('value')
        .orThrowA(() =>
            'RPC fault missing value:\n${fault.toXmlString(pretty: true)}')
        .getElement('struct')
        .orThrowA(() =>
            'RPC fault missing struct:\n${fault.toXmlString(pretty: true)}');

    final members = struct.findElements('member');
    final faultString = members
        .firstWhere((m) => m.getElement('name')?.text == 'faultString',
            orElse: () => throw DartleException(
                message: 'RPC fault missing faultString:\n'
                    '${struct.toXmlString(pretty: true)}'))
        .getElement('value')
        .orThrowA(() => 'RPC faultString missing value:\n'
            '${struct.toXmlString(pretty: true)}')
        .getElement('string')
        .orThrowA(() => 'RPC faultString missing string value:\n'
            '${struct.toXmlString(pretty: true)}')
        .text;

    final faultCode = int.parse(members
        .firstWhere((m) => m.getElement('name')?.text == 'faultCode',
            orElse: () => throw DartleException(
                message: 'RPC faultCode missing:\n'
                    '${struct.toXmlString(pretty: true)}'))
        .getElement('value')
        .orThrowA(() => 'RPC faultCode missing value:\n'
            '${struct.toXmlString(pretty: true)}')
        .getElement('int')
        .orThrowA(() => 'RPC faultCode missing int value:\n'
            '${struct.toXmlString(pretty: true)}')
        .text);

    throw DartleException(message: faultString, exitCode: faultCode);
  }
}

class _RpcExecLogger extends JbOutputConsumer {
  final String prompt;
  final String taskName;

  _RpcExecLogger(this.prompt, this.taskName);

  LogColor _colorFor(Level level) {
    if (level == Level.SEVERE) return LogColor.red;
    if (level == Level.WARNING) return LogColor.yellow;
    return LogColor.gray;
  }

  @override
  Object createMessage(Level level, String line) {
    return ColoredLogMessage(
        '$prompt $taskName [jvm-rpc $pid]: $line', _colorFor(level));
  }
}
