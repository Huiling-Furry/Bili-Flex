import 'common.dart';

/// 收藏夹。
class FavFolder {
  final int id;
  final int fid;
  final int mid;
  final String title;
  final int mediaCount;

  const FavFolder({
    this.id = 0,
    this.fid = 0,
    this.mid = 0,
    this.title = '',
    this.mediaCount = 0,
  });

  factory FavFolder.fromJson(Map<String, dynamic> j) => FavFolder(
        id: (j['id'] ?? 0) as int,
        fid: (j['fid'] ?? j['id'] ?? 0) as int,
        mid: (j['mid'] ?? 0) as int,
        title: (j['title'] ?? '') as String,
        mediaCount: (j['media_count'] ?? 0) as int,
      );
}

/// 收藏/历史/稍后再看 通用的视频条目。
class MediaItem {
  final int aid;
  final int cid;
  final String bvid;
  final String title;
  final String cover;
  final String author;
  final int authorMid;
  final int duration;
  final int progress;
  final int playCount;
  final int favTime;

  const MediaItem({
    this.aid = 0,
    this.cid = 0,
    this.bvid = '',
    this.title = '',
    this.cover = '',
    this.author = '',
    this.authorMid = 0,
    this.duration = 0,
    this.progress = 0,
    this.playCount = 0,
    this.favTime = 0,
  });

  bool get isFinished => duration > 0 && progress >= duration - 3;

  /// /x/v3/fav/resource/list 的 medias 元素。
  factory MediaItem.fromFav(Map<String, dynamic> j) {
    final upper = j['upper'] as Map<String, dynamic>? ?? const {};
    final cnt = j['cnt_info'] as Map<String, dynamic>? ?? const {};
    return MediaItem(
      aid: (j['id'] ?? 0) as int,
      bvid: (j['bvid'] ?? j['bv_id'] ?? '') as String,
      title: (j['title'] ?? '') as String,
      cover: PicUtil.normalize(j['cover'] as String?),
      author: (upper['name'] ?? '') as String,
      authorMid: (upper['mid'] ?? 0) as int,
      duration: (j['duration'] ?? 0) as int,
      playCount: (cnt['play'] ?? 0) as int,
      favTime: (j['fav_time'] ?? 0) as int,
    );
  }

  /// /x/web-interface/history/cursor 的 list 元素。
  factory MediaItem.fromHistory(Map<String, dynamic> j) {
    final history = j['history'] as Map<String, dynamic>? ?? const {};
    final covers = (j['covers'] as List<dynamic>? ?? const []);
    final cover = (j['cover'] ?? (covers.isNotEmpty ? covers.first : ''))
        .toString();
    return MediaItem(
      aid: (history['oid'] ?? j['aid'] ?? 0) as int,
      cid: (history['cid'] ?? 0) as int,
      bvid: (j['bvid'] ?? history['bvid'] ?? '') as String,
      title: (j['show_title'] ?? j['title'] ?? '') as String,
      cover: PicUtil.normalize(cover),
      author: (j['author_name'] ?? '') as String,
      authorMid: (j['author_mid'] ?? 0) as int,
      duration: (j['duration'] ?? 0) as int,
      progress: (j['progress'] ?? -1) as int,
      favTime: (j['view_at'] ?? 0) as int,
    );
  }

  /// /x/v2/history/toview/web 的 list 元素。
  factory MediaItem.fromToview(Map<String, dynamic> j) {
    final owner = j['owner'] as Map<String, dynamic>? ?? const {};
    final stat = j['stat'] as Map<String, dynamic>? ?? const {};
    return MediaItem(
      aid: (j['aid'] ?? 0) as int,
      cid: (j['cid'] ?? 0) as int,
      bvid: (j['bvid'] ?? '') as String,
      title: (j['title'] ?? '') as String,
      cover: PicUtil.normalize(j['pic'] as String?),
      author: (owner['name'] ?? '') as String,
      authorMid: (owner['mid'] ?? 0) as int,
      duration: (j['duration'] ?? 0) as int,
      progress: (j['progress'] ?? -1) as int,
      playCount: (stat['view'] ?? 0) as int,
      favTime: (j['add_at'] ?? 0) as int,
    );
  }
}