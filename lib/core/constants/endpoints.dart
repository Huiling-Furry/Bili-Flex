/// B 站 HTTP 接口端点。
///
/// 路径相对时默认前缀 [BiliHosts.api]。
/// 这里只列出 BiliFlex 实际用到的核心端点，按业务域分组。
library;

import 'bili_hosts.dart';

class Endpoints {
  Endpoints._();

  // ---------------- 首页 / 推荐 / 热门 ----------------
  /// App 端推荐
  static const String feedIndex = '${BiliHosts.app}/x/v2/feed/index';
  /// Web 端推荐（WBI）
  static const String webRcmd = '/x/web-interface/wbi/index/top/feed/rcmd';
  /// 热门
  static const String popular = '/x/web-interface/popular';
  static const String popularSeries = '/x/web-interface/popular/series/list';

  // ---------------- 视频详情 / 播放 ----------------
  static const String videoView = '/x/web-interface/view';
  static const String videoViewDetail = '/x/web-interface/view/detail';
  static const String videoTags = '/x/web-interface/view/detail/tag';
  static const String relatedList = '/x/web-interface/archive/related';
  static const String playUrl = '/x/player/wbi/playurl';
  static const String playInfo = '/x/player/wbi/v2';
  static const String pagelist = '/x/player/pagelist';
  static const String onlineTotal = '/x/player/online/total';
  static const String aiConclusion = '/x/web-interface/view/conclusion/get';

  // ---------------- 视频互动 ----------------
  static const String like = '${BiliHosts.app}/x/v2/view/like';
  static const String coin = '${BiliHosts.app}/x/v2/view/coin/add';
  static const String triple = '/x/web-interface/archive/like/triple';
  static const String dislike = '${BiliHosts.app}/x/v2/view/dislike';
  static const String archiveRelation = '/x/web-interface/archive/relation';
  static const String shareAdd = '/x/web-interface/share/add';

  // ---------------- 评论 ----------------
  static const String replyMain = '/x/v2/reply';
  static const String replyReply = '/x/v2/reply/reply';
  static const String replyAdd = '/x/v2/reply/add';
  static const String replyDel = '/x/v2/reply/del';
  static const String replyAction = '/x/v2/reply/action';
  static const String replyTop = '/x/v2/reply/top';

  // ---------------- 弹幕 ----------------
  static const String dmSeg = '/x/v2/dm/web/seg.so';
  static const String dmPost = '/x/v2/dm/post';
  static const String dmFilterList = '/x/dm/filter/user';
  static const String dmFilterAdd = '/x/dm/filter/user/add';

  // ---------------- 搜索 ----------------
  static const String searchAll = '/x/web-interface/wbi/search/all/v2';
  static const String searchType = '/x/web-interface/wbi/search/type';
  static const String searchSuggest = '${BiliHosts.search}/main/suggest';
  static const String searchHot = '${BiliHosts.search}/main/hotword';
  static const String searchDefault = '/x/web-interface/wbi/search/default';

  // ---------------- 用户 / 空间 ----------------
  static const String nav = '/x/web-interface/nav';
  static const String navStat = '/x/web-interface/nav/stat';
  static const String memberCard = '/x/web-interface/card';
  static const String memberInfo = '/x/space/wbi/acc/info';
  static const String space = '${BiliHosts.app}/x/v2/space';
  static const String spaceArchive = '${BiliHosts.app}/x/v2/space/archive/cursor';
  static const String spaceArcSearch = '/x/space/wbi/arc/search';
  static const String relationStat = '/x/relation/stat';
  static const String relation = '/x/relation';
  static const String relationMod = '/x/relation/modify';
  static const String followings = '/x/relation/followings';
  static const String fans = '/x/relation/fans';
  static const String blacks = '/x/relation/blacks';
  static const String upStat = '/x/space/upstat';
  static const String topArc = '/x/space/top/arc';
  static const String coinVideo = '/x/space/coin/video';
  static const String likeVideo = '/x/space/like/video';

  // ---------------- 动态 ----------------
  static const String dynPortal = '/x/polymer/web-dynamic/v1/portal';
  static const String dynFeedAll = '/x/polymer/web-dynamic/v1/feed/all';
  static const String dynFeedSpace = '/x/polymer/web-dynamic/v1/feed/space';
  static const String dynDetail = '/x/polymer/web-dynamic/v1/detail';
  static const String dynThumb = '/x/dynamic/feed/dyn/thumb';
  static const String dynCreate = '/x/dynamic/feed/create/dyn';
  static const String dynRemove = '/x/dynamic/feed/operate/remove';
  static const String dynUploadBfs = '/x/dynamic/feed/draw/upload_bfs';
  static const String dynUnread = '/x/web-interface/dynamic/entrance';

  // ---------------- 收藏 / 历史 / 稍后再看 ----------------
  static const String favFolderList = '/x/v3/fav/folder/created/list';
  static const String favFolderAll = '/x/v3/fav/folder/created/list-all';
  static const String favResourceList = '/x/v3/fav/resource/list';
  static const String favResourceDeal = '/x/v3/fav/resource/batch-deal';
  static const String historyList = '/x/web-interface/history/cursor';
  static const String historyClear = '/x/v2/history/clear';
  static const String historyDelete = '/x/v2/history/delete';
  static const String toviewList = '/x/v2/history/toview/web';
  static const String toviewAdd = '/x/v2/history/toview/add';
  static const String toviewDel = '/x/v2/history/toview/v2/dels';

  // ---------------- 直播 ----------------
  static const String liveRecommend =
      '${BiliHosts.live}/xlive/web-interface/v1/second/getUserRecommend';
  static const String liveRoomInfo =
      '${BiliHosts.live}/xlive/web-room/v2/index/getRoomPlayInfo';
  static const String liveDanmuInfo =
      '${BiliHosts.live}/xlive/web-room/v1/index/getDanmuInfo';
  static const String liveDanmuHistory =
      '${BiliHosts.live}/xlive/web-room/v1/dM/gethistory';
  static const String liveAreaList =
      '${BiliHosts.live}/room/v1/Area/getList';
  static const String liveFollow =
      '${BiliHosts.live}/xlive/web-ucenter/user/following';
  static const String liveSendMsg = '${BiliHosts.live}/msg/send';

  // ---------------- 消息 / 私信 ----------------
  static const String msgUnread = '${BiliHosts.vc}/session_svr/v1/session_svr/single_unread';
  static const String msgFeedUnread = '/x/msgfeed/unread';
  static const String msgFeedReply = '/x/msgfeed/reply';
  static const String msgFeedAt = '/x/msgfeed/at';
  static const String msgFeedLike = '/x/msgfeed/like';
  static const String sessionList = '${BiliHosts.vc}/session_svr/v1/session_svr/get_sessions';
  static const String sessionMsgs = '${BiliHosts.vc}/svr_sync/v1/svr_sync/fetch_session_msgs';
  static const String sessionUpdateAck = '${BiliHosts.vc}/session_svr/v1/session_svr/update_ack';
  static const String sendMsg = '${BiliHosts.vc}/web_im/v1/web_im/send_msg';
  /// 批量查询用户卡片（头像 / 昵称）
  static const String userCards = '${BiliHosts.vc}/account/v1/user/cards';

  // ---------------- 登录 ----------------
  static const String captcha = '${BiliHosts.passport}/x/passport-login/captcha?source=main_web';
  static const String qrcodeGen = '${BiliHosts.passport}/x/passport-tv-login/qrcode/auth_code';
  static const String qrcodePoll = '${BiliHosts.passport}/x/passport-tv-login/qrcode/poll';
  static const String webKey = '${BiliHosts.passport}/x/passport-login/web/key';
  static const String webLogin = '${BiliHosts.passport}/x/passport-login/web/login';
  static const String appSmsSend = '${BiliHosts.passport}/x/passport-login/sms/send';
  static const String appSmsLogin = '${BiliHosts.passport}/x/passport-login/login/sms';
  static const String logout = '${BiliHosts.passport}/login/exit/v2';
  static const String getCoin = '${BiliHosts.account}/site/getCoin';

  // ---------------- 番剧 / PGC ----------------
  static const String pgcSeason = '/pgc/view/web/season';
  static const String pgcPlayUrl = '/pgc/player/web/v2/playurl';
  static const String pgcTimeline = '/pgc/web/timeline';
  static const String pgcRank = '/pgc/web/rank/list';
  static const String ranking = '/x/web-interface/ranking/v2';

  // ---------------- 通用 ----------------
  static const String emotePanel = '/x/emote/user/panel/web';
  static const String report = '${BiliHosts.space}/ajax/report/add';
  static const String heartBeat = '/x/click-interface/web/heartbeat';
  static const String historyReport = '/x/v2/history/report';
}
