import '../../core/network/bili_dio.dart';
import '../../core/constants/endpoints.dart';
import '../models/video.dart';

/// 搜索。
class SearchRepo {
  final BiliDio _dio = BiliDio.instance;

  Future<List<String>> hotWords() async {
    final resp = await _dio.get(Endpoints.searchHot);
    final list = (resp.data?['trending']?['list'] as List<dynamic>? ?? []);
    return list.map((e) => (e as Map<String, dynamic>)['keyword'].toString()).toList();
  }

  Future<List<String>> suggest(String keyword) async {
    final resp = await _dio.get(Endpoints.searchSuggest, query: {
      'term': keyword,
    });
    final list = (resp.data?['tag'] as List<dynamic>? ?? []);
    return list.map((e) => (e as Map<String, dynamic>)['value'].toString()).toList();
  }

  /// 综合搜索。
  Future<List<VideoItem>> searchVideo(
    String keyword, {
    int page = 1,
    int order = 0,
  }) async {
    final resp = await _dio.get(
      Endpoints.searchType,
      wbi: true,
      query: {
        'search_type': 'video',
        'keyword': keyword,
        'page': page,
        'order': ['totalrank', 'click', 'pubdate', 'dm'][order],
      },
    );
    final list = (resp.data?['result'] as List<dynamic>? ?? []);
    return list
        .where((e) => (e as Map<String, dynamic>)['type'] == 'video')
        .map((e) => VideoItem.fromSearch(e as Map<String, dynamic>))
        .toList();
  }
}
