import 'dart:convert';
import 'package:crypto/crypto.dart';

/// B 站 WBI 签名工具。
///
/// 算法见 https://github.com/SocialSisterYi/bilibili-API-collect/blob/master/docs/misc/sign/wbi.md
/// 1. 从 /x/web-interface/nav 取 wbi_img.img_url / sub_url
/// 2. 取文件名（去扩展名）作为 img_key / sub_key
/// 3. 拼接后用 [mixinKeyEncTab] 重排，取前 32 位得 mixin_key
/// 4. 参数加 wts，按 key 排序拼接后 md5，得到 w_rid
class WbiSigner {
  static const List<int> mixinKeyEncTab = [
    46, 47, 18, 2, 53, 8, 23, 32, 15, 50, 10, 31, 58, 3, 45, 35,
    27, 43, 5, 49, 33, 9, 42, 19, 29, 28, 14, 39, 12, 38, 41, 13,
    37, 48, 7, 16, 24, 55, 40, 61, 26, 17, 0, 1, 60, 51, 30, 4,
    22, 25, 54, 21, 56, 59, 6, 63, 57, 62, 11, 36, 20, 34, 44, 52,
  ];

  String? _imgKey;
  String? _subKey;

  /// 用 nav 接口返回的 wbi_img 初始化。
  void refreshFromWbiImg(Map<String, dynamic> wbiImg) {
    _imgKey = _extractKey(wbiImg['img_url'] as String?);
    _subKey = _extractKey(wbiImg['sub_url'] as String?);
  }

  String? get imgKey => _imgKey;
  String? get subKey => _subKey;

  String? get mixinKey {
    if (_imgKey == null || _subKey == null) return null;
    final raw = '$_imgKey$_subKey';
    final buf = StringBuffer();
    for (final i in mixinKeyEncTab) {
      if (i < raw.length) buf.writeCharCode(raw.codeUnitAt(i));
    }
    return buf.toString().substring(0, 32);
  }

  String _extractKey(String? url) {
    if (url == null) return '';
    final segs = url.split('/');
    final file = segs.isEmpty ? '' : segs.last;
    final dot = file.indexOf('.');
    return dot < 0 ? file : file.substring(0, dot);
  }

  /// 给查询参数加上 w_rid / wts，返回新的参数表。
  Map<String, dynamic> sign(Map<String, dynamic> params) {
    final key = mixinKey;
    final wts = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final p = Map<String, dynamic>.from(params);
    p['wts'] = wts;
    if (key == null) return p;
    // 过滤 value 中的特殊字符
    final sortedKeys = p.keys.toList()..sort();
    final buf = StringBuffer();
    for (var i = 0; i < sortedKeys.length; i++) {
      final k = sortedKeys[i];
      var v = '${p[k]}';
      v = v.replaceAll(RegExp(r"[!'()*]"), '');
      buf.write('${i == 0 ? '' : '&'}$k=${Uri.encodeQueryComponent(v)}');
    }
    final raw = '$buf$key';
    p['w_rid'] = md5.convert(utf8.encode(raw)).toString();
    return p;
  }
}
