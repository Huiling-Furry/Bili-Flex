/// 数字/时间/时长格式化工具。
class Formatters {
  /// 1.2万 / 3.4亿 等 B 站风格计数。
  static String count(int? n) {
    if (n == null) return '0';
    if (n < 10000) return '$n';
    if (n < 100000000) {
      final v = (n / 10000).toStringAsFixed(1);
      return '${_trim(v)}万';
    }
    final v = (n / 100000000).toStringAsFixed(1);
    return '${_trim(v)}亿';
  }

  static String _trim(String v) {
    if (v.endsWith('.0')) return v.substring(0, v.length - 2);
    return v;
  }

  /// 时长秒 → mm:ss 或 hh:mm:ss
  static String duration(int sec) {
    final h = sec ~/ 3600;
    final m = (sec % 3600) ~/ 60;
    final s = sec % 60;
    final ss = s.toString().padLeft(2, '0');
    final mm = m.toString().padLeft(2, '0');
    if (h > 0) return '$h:$mm:$ss';
    return '$mm:$ss';
  }

  /// 时间戳（秒）→ 友好显示
  static String timeAgo(int? sec) {
    if (sec == null || sec == 0) return '';
    final t = DateTime.fromMillisecondsSinceEpoch(sec * 1000);
    final now = DateTime.now();
    final diff = now.difference(t);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes}分钟前';
    if (diff.inDays < 1) return '${diff.inHours}小时前';
    if (diff.inDays < 30) return '${diff.inDays}天前';
    if (diff.inDays < 365) return '${t.month}月${t.day}日';
    return '${t.year}年${t.month}月${t.day}日';
  }
}
