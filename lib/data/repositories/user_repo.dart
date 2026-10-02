import '../../core/network/bili_dio.dart';
import '../../core/constants/endpoints.dart';
import '../models/common.dart';
import '../models/space.dart';
import '../models/video.dart';

/// 用户空间 / 关系。
class UserRepo {
  final BiliDio _dio = BiliDio.instance;

  /// 用户名片。
  Future<({BiliUser user, int mid})> card(int mid) async {
    final resp = await _dio.get(Endpoints.memberCard, query: {
      'mid': mid,
      'photo': 1,
    });
    final c = resp.data?['card'] as Map<String, dynamic>? ?? {};
    return (
      user: BiliUser(
        name: c['name'] ?? '',
        face: c['face'] ?? '',
        mid: (c['mid'] ?? mid) as int,
      ),
      mid: (c['mid'] ?? mid) as int,
    );
  }

  /// 空间资料（名片 + 播放/获赞统计）。
  Future<SpaceInfo> spaceInfo(int mid) async {
    final resp = await _dio.get(Endpoints.memberCard, query: {
      'mid': mid,
      'photo': 1,
    });
    final card = resp.data?['card'] as Map<String, dynamic>? ?? const {};
    var info = SpaceInfo.fromCard(card);
    // 播放量/获赞数（可能因隐私设置失败，失败不影响主体信息）
    try {
      final up = await _dio.get(Endpoints.upStat, query: {'mid': mid});
      final archive = up.data?['archive'] as Map<String, dynamic>? ?? const {};
      info = info.copyWith(
        plays: (archive['view'] ?? 0) as int,
        likes: ((up.data?['likes'] ?? 0) as num).toInt(),
      );
    } catch (_) {}
    return info;
  }

  /// 是否已关注该用户。
  Future<bool> isFollowing(int mid) async {
    final resp = await _dio.get(Endpoints.relation, query: {'fid': mid});
    return ((resp.data?['attribute'] ?? 0) as int) != 0;
  }

  /// 用户投稿视频（web 端 wbi）。
  Future<List<VideoItem>> archive(int mid, {int pn = 1, int ps = 30}) async {
    final resp = await _dio.get(
      Endpoints.spaceArcSearch,
      wbi: true,
      query: {
        'mid': mid,
        'pn': pn,
        'ps': ps,
        'order': 'pubdate',
        'platform': 'web',
      },
    );
    final list = (resp.data?['list']?['vlist'] as List<dynamic>? ?? []);
    return list
        .whereType<Map<String, dynamic>>()
        .map((e) => VideoItem(
              aid: (e['aid'] ?? 0) as int,
              bvid: (e['bvid'] ?? '') as String,
              title: (e['title'] ?? '') as String,
              cover: PicUtil.normalize(e['pic'] as String?),
              author: (e['author'] ?? '') as String,
              authorMid: mid,
              playCount: (e['play'] ?? 0) as int,
              danmakuCount: (e['video_review'] ?? 0) as int,
              duration: (e['length'] ?? 0) as int,
              bvidOrAid: (e['bvid'] ?? '').toString(),
            ))
        .toList();
  }

  /// 关注/取关。act: 1=关注 2=取关
  Future<void> relation(int toMid, int act) async {
    await _dio.postForm(Endpoints.relationMod, data: {
      'fid': toMid,
      'act': act,
      're_src': 11,
      'csrf': _dio.account.csrf,
    });
  }
}