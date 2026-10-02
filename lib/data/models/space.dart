import 'common.dart';

/// 用户空间资料（card + 统计）。
class SpaceInfo {
  final int mid;
  final String name;
  final String face;
  final String sign;
  final int level;
  final int fans; // 粉丝数
  final int following; // 关注数
  final int likes; // 获赞
  final int plays; // 播放量

  const SpaceInfo({
    this.mid = 0,
    this.name = '',
    this.face = '',
    this.sign = '',
    this.level = 0,
    this.fans = 0,
    this.following = 0,
    this.likes = 0,
    this.plays = 0,
  });

  SpaceInfo copyWith({
    int? fans,
    int? following,
    int? likes,
    int? plays,
  }) =>
      SpaceInfo(
        mid: mid,
        name: name,
        face: face,
        sign: sign,
        level: level,
        fans: fans ?? this.fans,
        following: following ?? this.following,
        likes: likes ?? this.likes,
        plays: plays ?? this.plays,
      );

  /// /x/web-interface/card 的 data.card
  factory SpaceInfo.fromCard(Map<String, dynamic> card) {
    final levelInfo = card['level_info'] as Map<String, dynamic>? ?? const {};
    return SpaceInfo(
      mid: (card['mid'] ?? 0) as int,
      name: (card['name'] ?? '') as String,
      face: PicUtil.normalize(card['face'] as String?),
      sign: (card['sign'] ?? '') as String,
      level: (levelInfo['current_level'] ?? 0) as int,
      fans: (card['fans'] ?? 0) as int,
      following: (card['attention'] ?? 0) as int,
    );
  }
}