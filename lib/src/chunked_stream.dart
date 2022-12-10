import 'dart:convert';
import 'dart:typed_data';

class _ChunkedSink implements Sink<List<int>> {
  var index = 0;
  var parsingLen = true;
  var bb = ByteData(4);
  var _closed = false;
  final Sink<List<int>> _target;

  _ChunkedSink(this._target);

  @override
  void add(List<int> input) {
    if (_closed) {
      throw StateError('stream is already closed');
    }
    for (final b in input) {
      bb.setInt8(index++, b);
      if (parsingLen) {
        if (index == 4) {
          final length = bb.getInt32(0, Endian.big);
          if (0 > length || length > 1000000) {
            close();
            throw Exception('RPC message '
                '${length > 0 ? 'too big' : 'cannot be negative'}: $length');
          }
          if (length == 0) {
            return close();
          }
          _startChunk(length);
        }
      } else if (index >= bb.lengthInBytes) {
        _target.add(bb.buffer.asUint8List());
        _reset();
      }
    }
  }

  void _startChunk(int length) {
    bb = ByteData(length);
    index = 0;
    parsingLen = false;
  }

  void _reset() {
    bb = ByteData(4);
    index = 0;
    parsingLen = true;
  }

  @override
  void close() {
    _closed = true;
    try {
      _target.close();
    } catch (e) {
      // silently ignore close errors
    }
  }
}

class _ByteSink implements Sink<List<int>> {
  final _builder = BytesBuilder(copy: false);

  List<int> get bytes => _builder.takeBytes();

  @override
  void add(List<int> data) {
    _builder.add(data);
  }

  @override
  void close() {}
}

class ChunkDecoder extends Converter<List<int>, List<int>> {
  const ChunkDecoder();

  @override
  Sink<List<int>> startChunkedConversion(Sink<List<int>> sink) {
    return _ChunkedSink(sink);
  }

  @override
  List<int> convert(List<int> input) {
    final innerSink = _ByteSink();
    var outerSink = startChunkedConversion(innerSink);
    outerSink.add(input);
    outerSink.close();
    return innerSink.bytes;
  }
}
