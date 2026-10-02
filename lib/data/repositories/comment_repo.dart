import '../../core/network/bili_dio.dart';
import '../../core/constants/endpoints.dart';
import '../models/comment.dart';

/// 评论区：列表 / 发送 / 点赞。
class CommentRepo {
  final BiliDio _dio = BiliDio.instance;

  /// 评论列表。sort：2=热门，0=时间。
  Future<ReplyPage> list({
    required int oid,
    int type = 1,
    int sort = 2,
    int pn = 1,
    int ps = 20,
  }) async {
    final resp = await _dio.get(Endpoints.replyMain, query: {
      'type': type,
      'oid': oid,
      'sort': sort,
      'pn': pn,
      'ps': ps,
      'nohot': sort == 2 ? 0 : 1,
    });
    return ReplyPage.fromJson(resp.data as Map<String, dynamic>);
  }

  /// 发送评论。
  Future<void> add({
    required int oid,
    required String message,
    int type = 1,
  }) async {
    await _dio.postForm(Endpoints.replyAdd, data: {
      'type': type,
      'oid': oid,
      'message': message,
      'plat': 1,
      'csrf': _dio.account.csrf,
    });
  }

  /// 点赞 / 取消点赞评论。
  Future<void> like({
    required int oid,
    required int rpid,
    required bool liked,
    int type = 1,
  }) async {
    await _dio.postForm(Endpoints.replyAction, data: {
      'type': type,
      'oid': oid,
      'rpid': rpid,
      'action': liked ? 1 : 0,
      'csrf': _dio.account.csrf,
    });
  }
}