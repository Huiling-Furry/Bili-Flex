import '../../core/network/bili_dio.dart';
import '../../core/constants/endpoints.dart';

/// 直播条目。
class LiveItem {
  final int roomId;
  final String title;
  final String cover;
  final String uname;
  final String face;
  final int online;
  final String areaName;

  const LiveItem({
    this.roomId = 0,
    this.title = '',
    this.cover = '',
    this.uname = '',
    this.face = '',
    this.online = 0,
    this.areaName = '',
  });

  factory LiveItem.fromJson(Map<String, dynamic> j) => LiveItem(
        roomId: (j['roomid'] ?? j['room_id'] ?? 0) as int,
        title: (j['title'] ?? '') as String,
        cover: (j['cover'] ?? j['room_cover'] ?? '').toString().startsWith('//')
            ? 'https://${j['cover'] ?? j['room_cover']}'
            : (j['cover'] ?? j['room_cover'] ?? '') as String,
        uname: (j['uname'] ?? j['name'] ?? '') as String,
        face: (j['face'] ?? j['uface'] ?? '') as String,
        online: (j['online'] ?? j['online_count'] ?? 0) as int,
        areaName: (j['area_name'] ?? j['areaName'] ?? '') as String,
      );
}

class LiveRepo {
  final BiliDio _dio = BiliDio.instance;

  Future<List<LiveItem>> recommend({int page = 1, int pageSize = 30}) async {
    final resp = await _dio.get(Endpoints.liveRecommend, query: {
      'page': page,
      'page_size': pageSize,
      'platform': 'web',
    });
    final list = (resp.data?['list'] as List<dynamic>? ?? []);
    return list.map((e) => LiveItem.fromJson(e as Map<String, dynamic>)).toList();
  }
}
