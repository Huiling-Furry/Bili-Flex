import 'dart:convert';
import 'dart:typed_data';

/// 极简 Protobuf 线格式（wire format）读取器。
///
/// 仅实现解析所需的最小集合，避免为一个弹幕接口引入 protoc 代码生成链路。
/// 支持：
/// - wire type 0：varint
/// - wire type 1：64 位定长
/// - wire type 2：长度前缀（bytes / string / 嵌套消息）
/// - wire type 5：32 位定长
///
/// 参考 https://protobuf.dev/programming-guides/encoding/
class ProtobufReader {
  ProtobufReader(this._bytes);

  final Uint8List _bytes;
  int _pos = 0;

  bool get isAtEnd => _pos >= _bytes.length;
  int get position => _pos;
  int get length => _bytes.length;

  /// 读取一个 varint（最多 10 字节）。
  int readVarint() {
    var result = 0;
    var shift = 0;
    while (_pos < _bytes.length) {
      final b = _bytes[_pos++];
      result |= (b & 0x7F) << shift;
      if ((b & 0x80) == 0) break;
      shift += 7;
      if (shift > 63) break;
    }
    return result;
  }

  /// 读取 tag，返回 (fieldNumber, wireType)；到末尾返回 null。
  ({int field, int wire})? readTag() {
    if (isAtEnd) return null;
    final tag = readVarint();
    return (field: tag >> 3, wire: tag & 0x07);
  }

  Uint8List readBytes() {
    final len = readVarint();
    final end = (_pos + len).clamp(0, _bytes.length);
    final out = _bytes.sublist(_pos, end);
    _pos = end;
    return out;
  }

  String readString() => utf8.decode(readBytes(), allowMalformed: true);

  double readDouble() {
    final v = ByteData.sublistView(_bytes, _pos, _pos + 8).getFloat64(0, Endian.little);
    _pos += 8;
    return v;
  }

  double readFloat() {
    final v = ByteData.sublistView(_bytes, _pos, _pos + 4).getFloat32(0, Endian.little);
    _pos += 4;
    return v;
  }

  void readFixed64() => _pos += 8;
  void readFixed32() => _pos += 4;

  /// 跳过当前字段。调用方需已读出 tag。
  void skip(int wireType) {
    switch (wireType) {
      case 0:
        readVarint();
      case 1:
        readFixed64();
      case 2:
        readBytes();
      case 5:
        readFixed32();
      default:
        // 未知类型，无法安全跳过，直接跳到末尾。
        _pos = _bytes.length;
    }
  }
}