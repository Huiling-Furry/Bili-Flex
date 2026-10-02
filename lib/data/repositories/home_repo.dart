import '../../core/network/bili_dio.dart';
import '../../core/constants/endpoints.dart';
import '../models/video.dart';

/// 首页 / 推荐 / 热门 数据。
class HomeRepo {
  final BiliDio _dio = BiliDio.instance;

  /// App 端推荐（未登录也能用）。
  Future<List<VideoItem>> feedIndex({int idx = 1, String? freshIdx}) async {
    final resp = await _dio.get(Endpoints.feedIndex, query: {
      'idx': idx,
      'platform': 'ios',
      'flush': idx == 1 ? 1 : 0,
      'fresh_idx': ?freshIdx,
    });
    final items = (resp.data?['items'] as List<dynamic>? ?? []);
    return items
        .map((e) => VideoItem.fromRcmd(e as Map<String, dynamic>))
        .where((e) => e.bvid.isNotEmpty || e.aid > 0)
        .toList();
  }

  /// 热门视频。
  Future<List<VideoItem>> popular({int pn = 1, int ps = 20}) async {
    final resp = await _dio.get(Endpoints.popular, query: {
      'pn': pn,
      'ps': ps,
    });
    final items = (resp.data?['list'] as List<dynamic>? ?? []);
    return items
        .map((e) => VideoItem.fromPopular(e as Map<String, dynamic>))
        .toList();
  }
}
