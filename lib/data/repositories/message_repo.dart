import 'dart:convert';
import 'dart:math';

import '../../core/constants/endpoints.dart';
import '../../core/network/bili_dio.dart';
import '../models/message.dart';

/// 私信（Whisper）数据：会话列表、聊天记录、发送、已读。
class MessageRepo {
  final BiliDio _dio = BiliDio.instance;

  /// 当前登录用户的 mid。
  int get selfUid => _dio.account.session.mid;

  /// 会话列表。[sessionType] 1=用户+系统。
  Future<List<ImSession>> sessions({int sessionType = 1}) async {
    final resp = await _dio.get(Endpoints.sessionList, query: {
      'session_type': sessionType,
      'sort_rule': 2,
      'group_fold': 0,
      'unfollow_fold': 0,
      'build': 0,
      'mobi_app': 'web',
    });
    final list = (resp.data?['session_list'] as List<dynamic>? ?? []);
    return list
        .whereType<Map<String, dynamic>>()
        .map(ImSession.fromJson)
        .toList();
  }

  /// 批量拉取用户卡片（头像 / 昵称），key 为 mid。
  Future<Map<int, ImUserCard>> userCards(Iterable<int> mids) async {
    final ids = mids.where((e) => e > 0).toSet().toList();
    if (ids.isEmpty) return const {};
    final resp = await _dio.get(Endpoints.userCards, query: {
      'uids': ids.join(','),
      'build': 0,
      'mobi_app': 'web',
    });
    final data = resp.data;
    final list = data is List ? data : const <dynamic>[];
    final result = <int, ImUserCard>{};
    for (final e in list.whereType<Map<String, dynamic>>()) {
      final card = ImUserCard.fromJson(e);
      if (card.mid > 0) result[card.mid] = card;
    }
    return result;
  }

  /// 聊天记录（[endSeqno] 为空时取最新的一页）。
  Future<({List<ImMessage> messages, bool hasMore, int minSeqno})> history({
    required int talkerId,
    int? endSeqno,
    int size = 20,
  }) async {
    final resp = await _dio.get(Endpoints.sessionMsgs, query: {
      'talker_id': talkerId,
      'session_type': 1,
      'size': size,
      'sender_device_id': 1,
      'build': 0,
      'mobi_app': 'web',
      'end_seqno': ?endSeqno,
    });
    final list = (resp.data?['messages'] as List<dynamic>? ?? []);
    return (
      messages: list
          .whereType<Map<String, dynamic>>()
          .map(ImMessage.fromJson)
          .toList(),
      hasMore: (resp.data?['has_more'] ?? 0) == 1,
      minSeqno: (resp.data?['min_seqno'] ?? 0) as int,
    );
  }

  /// 发送文字私信。
  Future<void> sendText({
    required int talkerId,
    required String content,
  }) async {
    await _dio.postForm(Endpoints.sendMsg, data: {
      'msg[sender_uid]': selfUid,
      'msg[receiver_id]': talkerId,
      'msg[receiver_type]': 1,
      'msg[msg_type]': 1,
      'msg[msg_status]': 0,
      'msg[content]': jsonEncode({'content': content}),
      'msg[timestamp]': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'msg[dev_id]': _devId(),
      'csrf': _dio.account.csrf,
      'build': 0,
      'mobi_app': 'web',
    });
  }

  /// 撤回自己发送的私信。[msgKey] 为目标消息的唯一 id。
  Future<void> revoke({required int talkerId, required int msgKey}) async {
    await _dio.postForm(Endpoints.sendMsg, data: {
      'msg[sender_uid]': selfUid,
      'msg[receiver_id]': talkerId,
      'msg[receiver_type]': 1,
      'msg[msg_type]': 5,
      'msg[msg_status]': 0,
      'msg[content]': msgKey,
      'msg[timestamp]': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'msg[dev_id]': _devId(),
      'csrf': _dio.account.csrf,
      'csrf_token': _dio.account.csrf,
      'build': 0,
      'mobi_app': 'web',
    });
  }

  /// 标记会话已读。[ackSeqno] 为空时全部已读。
  Future<void> ackSession({required int talkerId, int? ackSeqno}) async {
    await _dio.postForm(Endpoints.sessionUpdateAck, data: {
      'talker_id': talkerId,
      'session_type': 1,
      'ack_seqno': ?ackSeqno,
      'csrf': _dio.account.csrf,
      'csrf_token': _dio.account.csrf,
      'build': 0,
      'mobi_app': 'web',
    });
  }

  /// 未读私信总数（已关注 + 未关注）。
  Future<int> unreadTotal() async {
    final resp = await _dio.get(Endpoints.msgUnread, query: {
      'unread_type': 0,
      'build': 0,
      'mobi_app': 'web',
    });
    final d = resp.data;
    if (d is! Map<String, dynamic>) return 0;
    final follow = (d['follow_unread'] ?? 0) as int;
    final unfollow = (d['unfollow_unread'] ?? 0) as int;
    return follow + unfollow;
  }

  static final _rand = Random();

  /// 生成形如 `xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx` 的设备 id。
  static String _devId() {
    const chars = '0123456789ABCDEF';
    String hex(int n) =>
        List.generate(n, (_) => chars[_rand.nextInt(16)]).join();
    final y = '89AB'[_rand.nextInt(4)];
    return '${hex(8)}-${hex(4)}-4${hex(3)}-$y${hex(3)}-${hex(12)}';
  }
}