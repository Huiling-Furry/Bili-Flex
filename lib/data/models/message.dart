/// 私信（Whisper）相关数据模型。
library;

import 'dart:convert';

/// 私信消息类型。
class MsgType {
  static const int text = 1;
  static const int pic = 2;
  static const int drawBack = 5;
  static const int shareV2 = 7;
  static const int notifyMsg = 10;
  static const int videoCard = 11;
  static const int articleCard = 12;
  static const int pictureCard = 13;
  static const int commonShareCard = 14;
  static const int recommendCard = 16;
  static const int tipMessage = 18;
}

/// 分享 V2 的 source 类型。
class ShareSource {
  static const int album = 2;
  static const int video = 5;
  static const int article = 6;
  static const int dynamic = 11;
  static const int pgc = 16;
}

/// 私信用户卡片，来自 `/account/v1/user/cards`。
class ImUserCard {
  final int mid;
  final String name;
  final String face;
  final String sign;

  const ImUserCard({
    required this.mid,
    required this.name,
    required this.face,
    this.sign = '',
  });

  factory ImUserCard.fromJson(Map<String, dynamic> j) => ImUserCard(
        mid: (j['mid'] ?? 0) as int,
        name: (j['name'] ?? '') as String,
        face: (j['face'] ?? '') as String,
        sign: (j['sign'] ?? '') as String,
      );
}

/// 单条私信消息。
class ImMessage {
  final int senderUid;
  final int receiverId;
  final int msgType;
  final String content; // 原始 JSON 串
  final int timestamp; // 秒
  final int msgSeqno;
  final int msgKey;
  final int msgStatus; // 1 表示已撤回
  final int msgSource; // 8~11 为自动回复

  const ImMessage({
    required this.senderUid,
    required this.receiverId,
    required this.msgType,
    required this.content,
    required this.timestamp,
    this.msgSeqno = 0,
    this.msgKey = 0,
    this.msgStatus = 0,
    this.msgSource = 0,
  });

  factory ImMessage.fromJson(Map<String, dynamic> j) => ImMessage(
        senderUid: (j['sender_uid'] ?? 0) as int,
        receiverId: (j['receiver_id'] ?? 0) as int,
        msgType: (j['msg_type'] ?? 0) as int,
        content: '${j['content'] ?? ''}',
        timestamp: (j['timestamp'] ?? 0) as int,
        msgSeqno: (j['msg_seqno'] ?? 0) as int,
        msgKey: (j['msg_key'] ?? 0) as int,
        msgStatus: (j['msg_status'] ?? 0) as int,
        msgSource: (j['msg_source'] ?? 0) as int,
      );

  ImMessage copyWith({int? msgStatus}) => ImMessage(
        senderUid: senderUid,
        receiverId: receiverId,
        msgType: msgType,
        content: content,
        timestamp: timestamp,
        msgSeqno: msgSeqno,
        msgKey: msgKey,
        msgStatus: msgStatus ?? this.msgStatus,
        msgSource: msgSource,
      );

  bool get isRevoked => msgStatus == 1 || msgType == MsgType.drawBack;

  /// 是否为系统/卡片消息（不包气泡，居中或全宽展示）。
  bool get isSystem => const {
        MsgType.videoCard,
        MsgType.tipMessage,
        MsgType.notifyMsg,
        MsgType.pictureCard,
        MsgType.recommendCard,
      }.contains(msgType);

  /// 是否为自动回复。
  bool get isAutoReply => msgSource >= 8 && msgSource <= 11;

  /// 解析 content（部分字段存在双重 JSON 编码）。
  Map<String, dynamic> get body {
    if (content.isEmpty) return const {};
    try {
      final v = jsonDecode(content);
      if (v is Map<String, dynamic>) return v;
      if (v is String) {
        final v2 = jsonDecode(v);
        if (v2 is Map<String, dynamic>) return v2;
      }
    } catch (_) {}
    return const {};
  }

  /// 图片消息的图片地址。
  String? get imageUrl {
    if (msgType != MsgType.pic) return null;
    final url = body['url'];
    return url is String && url.isNotEmpty ? url : null;
  }

  /// 单行摘要文本（用于会话列表等）。
  String get text {
    if (isRevoked) return '[已撤回]';
    final b = body;
    switch (msgType) {
      case MsgType.text:
        return (b['content'] as String?) ?? content;
      case MsgType.pic:
      case MsgType.pictureCard:
        return '[图片]';
      case MsgType.shareV2:
        return '[分享] ${b['title'] ?? ''}'.trim();
      case MsgType.notifyMsg:
        return '[通知] ${b['title'] ?? b['content'] ?? ''}'.trim();
      case MsgType.videoCard:
        return '[视频] ${b['title'] ?? ''}'.trim();
      case MsgType.articleCard:
        return '[专栏] ${b['title'] ?? ''}'.trim();
      case MsgType.commonShareCard:
        return '[分享] ${b['title'] ?? ''}'.trim();
      case MsgType.recommendCard:
        return '[推荐] ${b['main_title'] ?? ''}'.trim();
      default:
        return (b['content'] as String?) ?? content;
    }
  }
}

/// 一个私信会话（与某个用户或系统助手的对话）。
class ImSession {
  final int talkerId;
  final int sessionType;
  int unreadCount;
  final int topTs; // >0 表示置顶
  final bool isDnd;
  final ImMessage? lastMsg;
  final String? accountName; // 系统会话自带的名称
  final String? accountFace;

  /// 关联的用户卡片（头像 / 昵称），列表加载后回填。
  ImUserCard? user;

  ImSession({
    required this.talkerId,
    required this.sessionType,
    required this.unreadCount,
    this.topTs = 0,
    this.isDnd = false,
    this.lastMsg,
    this.accountName,
    this.accountFace,
    this.user,
  });

  factory ImSession.fromJson(Map<String, dynamic> j) {
    final last = j['last_msg'];
    final info = j['account_info'];
    return ImSession(
      talkerId: (j['talker_id'] ?? 0) as int,
      sessionType: (j['session_type'] ?? 1) as int,
      unreadCount: (j['unread_count'] ?? 0) as int,
      topTs: (j['top_ts'] ?? 0) as int,
      isDnd: (j['is_dnd'] ?? 0) == 1,
      lastMsg: last is Map<String, dynamic> ? ImMessage.fromJson(last) : null,
      accountName: info is Map<String, dynamic> ? info['name'] as String? : null,
      accountFace:
          info is Map<String, dynamic> ? info['pic_url'] as String? : null,
    );
  }

  bool get isPinned => topTs > 0;
  bool get hasUnread => unreadCount > 0;

  String get title => user?.name ?? accountName ?? '用户 $talkerId';
  String get face => user?.face ?? accountFace ?? '';
  String get preview => lastMsg?.text ?? '';
  int get timestamp => lastMsg?.timestamp ?? 0;
}