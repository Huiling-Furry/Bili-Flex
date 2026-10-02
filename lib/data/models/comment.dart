/// 评论（对应 /x/v2/reply 的 replies 元素）。
class ReplyItem {
  final int rpid;
  final int oid;
  final int mid;
  final String uname;
  final String avatar;
  final String message;
  final int like;
  final int rcount;
  final int ctime;
  final bool liked;
  final List<ReplyItem> replies;

  const ReplyItem({
    this.rpid = 0,
    this.oid = 0,
    this.mid = 0,
    this.uname = '',
    this.avatar = '',
    this.message = '',
    this.like = 0,
    this.rcount = 0,
    this.ctime = 0,
    this.liked = false,
    this.replies = const [],
  });

  ReplyItem copyWith({int? like, bool? liked, List<ReplyItem>? replies}) =>
      ReplyItem(
        rpid: rpid,
        oid: oid,
        mid: mid,
        uname: uname,
        avatar: avatar,
        message: message,
        like: like ?? this.like,
        rcount: rcount,
        ctime: ctime,
        liked: liked ?? this.liked,
        replies: replies ?? this.replies,
      );

  static String _normalizeAvatar(String? url) {
    if (url == null || url.isEmpty) return '';
    if (url.startsWith('//')) return 'https:$url';
    return url;
  }

  factory ReplyItem.fromJson(Map<String, dynamic> j) {
    final member = j['member'] as Map<String, dynamic>? ?? const {};
    final content = j['content'] as Map<String, dynamic>? ?? const {};
    final action = (j['action'] ?? 0) as int;
    final sub = (j['replies'] as List<dynamic>? ?? [])
        .map((e) => ReplyItem.fromJson(e as Map<String, dynamic>))
        .toList();
    return ReplyItem(
      rpid: (j['rpid'] ?? 0) as int,
      oid: (j['oid'] ?? 0) as int,
      mid: (j['mid'] ?? 0) as int,
      uname: (member['uname'] ?? '') as String,
      avatar: _normalizeAvatar(member['avatar'] as String?),
      message: (content['message'] ?? '') as String,
      like: (j['like'] ?? 0) as int,
      rcount: (j['rcount'] ?? 0) as int,
      ctime: (j['ctime'] ?? 0) as int,
      liked: action == 1,
      replies: sub,
    );
  }
}

/// 一页评论。
class ReplyPage {
  final List<ReplyItem> replies;
  final List<ReplyItem> top;
  final int page;
  final int pageCount;
  final int allCount;

  const ReplyPage({
    this.replies = const [],
    this.top = const [],
    this.page = 1,
    this.pageCount = 1,
    this.allCount = 0,
  });

  bool get hasMore => page < pageCount;

  factory ReplyPage.fromJson(Map<String, dynamic> j) {
    final replies = (j['replies'] as List<dynamic>? ?? [])
        .map((e) => ReplyItem.fromJson(e as Map<String, dynamic>))
        .toList();
    final top = <ReplyItem>[];
    final topNode = j['top'];
    if (topNode is Map<String, dynamic>) {
      final upper = topNode['upper'];
      if (upper is Map<String, dynamic>) {
        top.add(ReplyItem.fromJson(upper));
      }
    }
    final pageInfo = j['page'] as Map<String, dynamic>? ?? const {};
    return ReplyPage(
      replies: replies,
      top: top,
      page: (pageInfo['num'] ?? 1) as int,
      pageCount: (pageInfo['count'] ?? 1) as int,
      allCount: (j['cursor'] is Map
              ? (j['cursor'] as Map)['all_count']
              : pageInfo['acount']) as int? ??
          0,
    );
  }
}