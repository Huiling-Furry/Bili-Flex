import 'dart:convert';
import 'dart:typed_data';
import '../../core/utils/protobuf_reader.dart';

/// 弹幕条目（对应 protobuf DanmakuElem）。
class DanmakuItem {
  final int id;
  final int progressMs;
  final int mode;
  final int color;
  final String content;
  final int ctime;

  const DanmakuItem({
    this.id = 0,
    this.progressMs = 0,
    this.mode = 1,
    this.color = 0xFFFFFF,
    this.content = '',
    this.ctime = 0,
  });

  Duration get time => Duration(milliseconds: progressMs);

  /// 弹幕类型中文说明。
  String get modeLabel => switch (mode) {
        1 || 2 || 3 => '滚动',
        4 => '底部',
        5 => '顶部',
        6 => '逆向',
        7 => '高级',
        8 => '代码',
        _ => '弹幕',
      };

  /// 展示用文本。
  ///
  /// 高级/代码弹幕（mode 7、8）的 content 是 JSON 数组，文字在第 5 项；
  /// 无法解析时返回空串，由调用方跳过（避免把 JSON 原文画到屏幕上）。
  String get displayText {
    if (mode != 7 && mode != 8) return content;
    try {
      final v = jsonDecode(content);
      if (v is List && v.length > 4 && v[4] is String) return v[4] as String;
    } catch (_) {}
    return '';
  }

  /// 解析弹幕分段响应（DmSegMobileReply），elems 为字段 1。
  static List<DanmakuItem> parseSegment(Uint8List bytes) {
    final out = <DanmakuItem>[];
    final reader = ProtobufReader(bytes);
    while (!reader.isAtEnd) {
      final tag = reader.readTag();
      if (tag == null) break;
      if (tag.field == 1 && tag.wire == 2) {
        out.add(_parseElem(reader.readBytes()));
      } else {
        reader.skip(tag.wire);
      }
    }
    return out;
  }

  static DanmakuItem _parseElem(Uint8List bytes) {
    final r = ProtobufReader(bytes);
    var id = 0;
    var progress = 0;
    var mode = 1;
    var color = 0xFFFFFF;
    var content = '';
    var ctime = 0;
    while (!r.isAtEnd) {
      final tag = r.readTag();
      if (tag == null) break;
      switch ((tag.field, tag.wire)) {
        case (1, 0):
          id = r.readVarint();
        case (2, 0):
          progress = r.readVarint();
        case (3, 0):
          mode = r.readVarint();
        case (5, 0):
          color = r.readVarint();
        case (7, 2):
          content = r.readString();
        case (8, 0):
          ctime = r.readVarint();
        default:
          r.skip(tag.wire);
      }
    }
    return DanmakuItem(
      id: id,
      progressMs: progress,
      mode: mode,
      color: color,
      content: content,
      ctime: ctime,
    );
  }
}