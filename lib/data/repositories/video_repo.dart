import 'dart:typed_data';

import '../../core/network/bili_dio.dart';
import '../../core/constants/endpoints.dart';
import '../models/danmaku.dart';
import '../models/video.dart';

/// 视频详情、播放流、相关推荐、弹幕、分 P、互动。
class VideoRepo {
  final BiliDio _dio = BiliDio.instance;

  Future<VideoDetail> detail({String? bvid, int? aid}) async {
    assert(bvid != null || aid != null);
    final resp = await _dio.get(Endpoints.videoView, query: {
      'bvid': ?bvid,
      'aid': ?aid,
    });
    return VideoDetail.fromJson(resp.data as Map<String, dynamic>);
  }

  /// 分 P 列表（用于多 P 切换）。
  Future<List<VideoPage>> pages({String? bvid, int? aid}) async {
    final resp = await _dio.get(Endpoints.pagelist, query: {
      'bvid': ?bvid,
      'aid': ?aid,
    });
    final list = (resp.data as List<dynamic>? ?? []);
    return list
        .map((e) => VideoPage.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 播放流（同时请求 DASH 与 durl，便于兼容不同账号权限）。
  Future<PlayUrlData> playUrlData({
    required int cid,
    String? bvid,
    int? aid,
    int qn = 80,
  }) async {
    final resp = await _dio.get(
      Endpoints.playUrl,
      wbi: true,
      query: {
        'bvid': ?bvid,
        'aid': ?aid,
        'cid': cid,
        'qn': qn,
        'fnval': 17, // 1(MP4/FLV) | 16(DASH)
        'fnver': 0,
        'fourk': 1,
      },
    );
    return PlayUrlData.fromJson(resp.data as Map<String, dynamic>);
  }

  /// 弹幕分段（seg.so，protobuf）。segmentIndex 从 1 开始，每段约 6 分钟。
  Future<List<DanmakuItem>> danmaku({
    required int cid,
    int segmentIndex = 1,
  }) async {
    final bytes = await _dio.getBytes(Endpoints.dmSeg, query: {
      'type': 1,
      'oid': cid,
      'segment_index': segmentIndex,
    });
    if (bytes.isEmpty) return const [];
    return DanmakuItem.parseSegment(Uint8List.fromList(bytes));
  }

  Future<List<VideoItem>> related({required int aid}) async {
    final resp = await _dio.get(Endpoints.relatedList, query: {'aid': aid});
    final list = (resp.data as List<dynamic>? ?? []);
    return list
        .map((e) => VideoItem.fromPopular(e as Map<String, dynamic>))
        .toList();
  }

  /// 点赞：like=1 点赞，2 取消。
  Future<void> likeVideo({String? bvid, int? aid, required int like}) async {
    await _dio.postForm(Endpoints.like, data: {
      'bvid': ?bvid,
      'aid': ?aid,
      'like': like,
      'eab_x': 1,
      'ramval': 0,
      'type': 1,
      'csrf': _dio.account.csrf,
    });
  }

  /// 投币。
  Future<void> coinVideo({
    String? bvid,
    int? aid,
    required int multiply,
    bool alsoLike = false,
  }) async {
    await _dio.postForm(Endpoints.coin, data: {
      'bvid': ?bvid,
      'aid': ?aid,
      'multiply': multiply,
      'select_like': alsoLike ? 1 : 0,
      'csrf': _dio.account.csrf,
    });
  }

  /// 一键三连。
  Future<void> triple({required String bvid}) async {
    await _dio.postForm(Endpoints.triple, data: {
      'bvid': bvid,
      'like': 1,
      'eab_x': 1,
      'ramval': 0,
      'type': 1,
      'csrf': _dio.account.csrf,
    });
  }
}