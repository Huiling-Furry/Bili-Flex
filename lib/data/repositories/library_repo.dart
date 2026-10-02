import '../../core/network/bili_dio.dart';
import '../../core/constants/endpoints.dart';
import '../models/library.dart';

/// 收藏夹 / 历史记录 / 稍后再看 数据。
class LibraryRepo {
  final BiliDio _dio = BiliDio.instance;

  // ---------------- 收藏夹 ----------------

  /// 当前用户创建的收藏夹列表。
  Future<List<FavFolder>> favFolders({required int mid}) async {
    final resp = await _dio.get(Endpoints.favFolderList, query: {
      'up_mid': mid,
      'web_location': 333.1387,
    });
    final list = (resp.data?['list'] as List<dynamic>? ?? []);
    return list
        .map((e) => FavFolder.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 收藏夹内容。
  Future<List<MediaItem>> favResources({
    required int mediaId,
    int pn = 1,
    int ps = 20,
  }) async {
    final resp = await _dio.get(Endpoints.favResourceList, query: {
      'media_id': mediaId,
      'pn': pn,
      'ps': ps,
      'platform': 'web',
      'order': 'mtime',
      'type': 0,
    });
    final list = (resp.data?['medias'] as List<dynamic>? ?? []);
    return list
        .whereType<Map<String, dynamic>>()
        .map(MediaItem.fromFav)
        .toList();
  }

  /// 收藏 / 取消收藏（type=2 表示视频稿件）。
  Future<void> favDeal({
    required int mediaId,
    required int aid,
    required bool add,
  }) async {
    await _dio.postForm(Endpoints.favResourceDeal, data: {
      'resources': '$aid:2',
      'media_id': mediaId,
      'platform': 'web',
      'add_media_ids': add ? '$mediaId' : '',
      'del_media_ids': add ? '' : '$mediaId',
      'csrf': _dio.account.csrf,
    });
  }

  // ---------------- 历史记录 ----------------

  Future<({List<MediaItem> items, int max, int viewAt})> history({
    int max = 0,
    int viewAt = 0,
    int ps = 30,
  }) async {
    final resp = await _dio.get(Endpoints.historyList, query: {
      'ps': ps,
      if (max > 0) 'max': max,
      if (viewAt > 0) 'view_at': viewAt,
      'business': '',
    });
    final list = (resp.data?['list'] as List<dynamic>? ?? []);
    final cursor = resp.data?['cursor'] as Map<String, dynamic>? ?? const {};
    return (
      items: list
          .whereType<Map<String, dynamic>>()
          .map(MediaItem.fromHistory)
          .toList(),
      max: (cursor['max'] ?? 0) as int,
      viewAt: (cursor['view_at'] ?? 0) as int,
    );
  }

  Future<void> clearHistory() async {
    await _dio.postForm(Endpoints.historyClear, data: {
      'csrf': _dio.account.csrf,
    });
  }

  Future<void> deleteHistory({required int aid}) async {
    await _dio.postForm(Endpoints.historyDelete, data: {
      'kid': '$aid',
      'csrf': _dio.account.csrf,
    });
  }

  // ---------------- 稍后再看 ----------------

  Future<List<MediaItem>> watchLater() async {
    final resp = await _dio.get(Endpoints.toviewList, query: {
      'web_location': 333.1387,
    });
    final list = (resp.data?['list'] as List<dynamic>? ?? []);
    return list
        .whereType<Map<String, dynamic>>()
        .map(MediaItem.fromToview)
        .toList();
  }

  Future<void> addWatchLater({required int aid}) async {
    await _dio.postForm(Endpoints.toviewAdd, data: {
      'aid': aid,
      'csrf': _dio.account.csrf,
    });
  }

  Future<void> removeWatchLater({required int aid}) async {
    await _dio.postForm(Endpoints.toviewDel, data: {
      'aid': aid,
      'csrf': _dio.account.csrf,
    });
  }
}