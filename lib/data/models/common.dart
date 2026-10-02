/// 通用数据模型。
library;

/// B 站用户简介（卡片/列表里常见）。
class BiliUser {
  final String name;
  final String face;
  final int mid;

  const BiliUser({this.name = '', this.face = '', this.mid = 0});

  factory BiliUser.fromJson(Map<String, dynamic>? j) {
    if (j == null) return const BiliUser();
    return BiliUser(
      name: (j['uname'] ?? j['name'] ?? '') as String,
      face: (j['face'] ?? '') as String,
      mid: (j['mid'] ?? j['mid_'] ?? 0) as int,
    );
  }
}

/// 图片地址带 CDN 后缀处理。
class PicUtil {
  static String normalize(String? url) {
    if (url == null || url.isEmpty) return '';
    if (url.startsWith('//')) return 'https:$url';
    return url;
  }
}
