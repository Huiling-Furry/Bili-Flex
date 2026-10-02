import 'common.dart';

/// 推荐/搜索/历史/收藏里的视频卡片。
class VideoItem {
  final int aid;
  final String bvid;
  final String title;
  final String cover;
  final String author;
  final int authorMid;
  final int playCount;
  final int danmakuCount;
  final int duration; // 秒
  final String bvidOrAid;

  const VideoItem({
    this.aid = 0,
    this.bvid = '',
    this.title = '',
    this.cover = '',
    this.author = '',
    this.authorMid = 0,
    this.playCount = 0,
    this.danmakuCount = 0,
    this.duration = 0,
    this.bvidOrAid = '',
  });

  factory VideoItem.fromRcmd(Map<String, dynamic> j) {
    // /x/v2/feed/index 结构
    return VideoItem(
      aid: (j['id'] ?? 0) as int,
      bvid: (j['bvid'] ?? '') as String,
      title: (j['title'] ?? '') as String,
      cover: PicUtil.normalize(j['pic'] as String?),
      author: (j['owner']?['name'] ?? '') as String,
      authorMid: (j['owner']?['mid'] ?? 0) as int,
      playCount: (j['stat']?['view'] ?? 0) as int,
      danmakuCount: (j['stat']?['danmaku'] ?? 0) as int,
      duration: (j['duration'] ?? 0) as int,
      bvidOrAid: (j['bvid'] ?? 'av${j['id'] ?? ''}').toString(),
    );
  }

  factory VideoItem.fromPopular(Map<String, dynamic> j) {
    return VideoItem(
      aid: (j['aid'] ?? 0) as int,
      bvid: (j['bvid'] ?? '') as String,
      title: (j['title'] ?? '') as String,
      cover: PicUtil.normalize(j['pic'] as String?),
      author: (j['owner']?['name'] ?? '') as String,
      authorMid: (j['owner']?['mid'] ?? 0) as int,
      playCount: (j['stat']?['view'] ?? 0) as int,
      danmakuCount: (j['stat']?['danmaku'] ?? 0) as int,
      duration: (j['duration'] ?? 0) as int,
      bvidOrAid: (j['bvid'] ?? '').toString(),
    );
  }

  factory VideoItem.fromSearch(Map<String, dynamic> j) {
    return VideoItem(
      aid: (j['aid'] ?? 0) as int,
      bvid: (j['bvid'] ?? '') as String,
      title: (j['title'] ?? '').replaceAll(RegExp(r'<[^>]+>'), ''),
      cover: PicUtil.normalize(
        (j['pic'] ?? '').toString().startsWith('//')
            ? 'https://${j['pic']}'
            : j['pic'] as String?,
      ),
      author: (j['author'] ?? '') as String,
      authorMid: (j['mid'] ?? 0) as int,
      playCount: (j['play'] ?? 0) as int,
      danmakuCount: (j['video_review'] ?? 0) as int,
      duration: _searchDuration(j['duration']),
      bvidOrAid: (j['bvid'] ?? '').toString(),
    );
  }

  static int _searchDuration(dynamic d) {
    if (d is int) return d;
    if (d is String) {
      final parts = d.split(':');
      if (parts.length == 2) return (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
      if (parts.length == 3) {
        return (int.tryParse(parts[0]) ?? 0) * 3600 +
            (int.tryParse(parts[1]) ?? 0) * 60 +
            (int.tryParse(parts[2]) ?? 0);
      }
    }
    return 0;
  }
}

/// 视频分 P。
class VideoPage {
  final int cid;
  final int page;
  final String part;
  final int duration;

  const VideoPage({
    this.cid = 0,
    this.page = 1,
    this.part = '',
    this.duration = 0,
  });

  factory VideoPage.fromJson(Map<String, dynamic> j) => VideoPage(
        cid: (j['cid'] ?? 0) as int,
        page: (j['page'] ?? 1) as int,
        part: (j['part'] ?? '') as String,
        duration: (j['duration'] ?? 0) as int,
      );
}

/// 视频详情（/x/web-interface/view）。
class VideoDetail {
  final int aid;
  final String bvid;
  final String title;
  final String desc;
  final String cover;
  final int cid;
  final int duration;
  final int pubdate;
  final int ownerMid;
  final String ownerName;
  final String ownerFace;
  final int view;
  final int danmaku;
  final int reply;
  final int favorite;
  final int coin;
  final int like;
  final List<VideoPage> pages;

  const VideoDetail({
    this.aid = 0,
    this.bvid = '',
    this.title = '',
    this.desc = '',
    this.cover = '',
    this.cid = 0,
    this.duration = 0,
    this.pubdate = 0,
    this.ownerMid = 0,
    this.ownerName = '',
    this.ownerFace = '',
    this.view = 0,
    this.danmaku = 0,
    this.reply = 0,
    this.favorite = 0,
    this.coin = 0,
    this.like = 0,
    this.pages = const [],
  });

  factory VideoDetail.fromJson(Map<String, dynamic> j) {
    final pages = (j['pages'] as List<dynamic>? ?? [])
        .map((e) => VideoPage.fromJson(e as Map<String, dynamic>))
        .toList();
    return VideoDetail(
      aid: (j['aid'] ?? 0) as int,
      bvid: (j['bvid'] ?? '') as String,
      title: (j['title'] ?? '') as String,
      desc: (j['desc'] ?? '') as String,
      cover: PicUtil.normalize(j['pic'] as String?),
      cid: (j['cid'] ?? 0) as int,
      duration: (j['duration'] ?? 0) as int,
      pubdate: (j['pubdate'] ?? 0) as int,
      ownerMid: (j['owner']?['mid'] ?? 0) as int,
      ownerName: (j['owner']?['name'] ?? '') as String,
      ownerFace: PicUtil.normalize(j['owner']?['face'] as String?),
      view: (j['stat']?['view'] ?? 0) as int,
      danmaku: (j['stat']?['danmaku'] ?? 0) as int,
      reply: (j['stat']?['reply'] ?? 0) as int,
      favorite: (j['stat']?['favorite'] ?? 0) as int,
      coin: (j['stat']?['coin'] ?? 0) as int,
      like: (j['stat']?['like'] ?? 0) as int,
      pages: pages,
    );
  }
}

/// 播放流条目（DASH / FLV）。
class PlayUrlItem {
  final String baseUrl;
  final List<String> backupUrls;
  final int bandwidth;
  final String mimeType;
  final int qualityId;
  final String qualityLabel;
  final int width;
  final int height;

  const PlayUrlItem({
    this.baseUrl = '',
    this.backupUrls = const [],
    this.bandwidth = 0,
    this.mimeType = '',
    this.qualityId = 0,
    this.qualityLabel = '',
    this.width = 0,
    this.height = 0,
  });

  factory PlayUrlItem.fromJson(Map<String, dynamic> j) {
    final id = (j['id'] ?? 0) as int;
    return PlayUrlItem(
      baseUrl: (j['baseUrl'] ?? j['base_url'] ?? '') as String,
      backupUrls: (j['backupUrl'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      bandwidth: (j['bandwidth'] ?? 0) as int,
      mimeType: (j['mimeType'] ?? '') as String,
      qualityId: id,
      qualityLabel: PlayUrlData.qualityName(id),
      width: (j['width'] ?? 0) as int,
      height: (j['height'] ?? 0) as int,
    );
  }
}

/// 画质选项（qn + 展示名）。
class QualityOption {
  /// 画质 ID：6=240P, 16=360P, 32=480P, 64=720P, 74=720P60, 80=1080P,
  /// 112=1080P+, 116=1080P60, 120=4K, 125=HDR, 126=杜比视界, 127=8K
  final int qn;
  final String label;

  const QualityOption({required this.qn, required this.label});

  factory QualityOption.fromQn(int qn) =>
      QualityOption(qn: qn, label: PlayUrlData.qualityName(qn));
}

/// 播放流解析结果（DASH + durl）。
class PlayUrlData {
  final List<PlayUrlItem> dashVideo;
  final List<PlayUrlItem> dashAudio;
  final List<PlayUrlItem> durl;
  final List<int> acceptQuality;

  const PlayUrlData({
    this.dashVideo = const [],
    this.dashAudio = const [],
    this.durl = const [],
    this.acceptQuality = const [],
  });

  bool get isEmpty => dashVideo.isEmpty && durl.isEmpty;

  /// 可选画质列表（去重、从高到低）。
  List<QualityOption> get qualities {
    final ids = <int>{
      ...acceptQuality,
      ...dashVideo.map((e) => e.qualityId),
      ...durl.map((e) => e.qualityId),
    }..remove(0);
    final sorted = ids.toList()..sort((a, b) => b.compareTo(a));
    return sorted.map(QualityOption.fromQn).toList();
  }

  /// 画质 id → 名称。
  static String qualityName(int id) => switch (id) {
        6 => '240P',
        16 => '360P',
        32 => '480P',
        64 => '720P',
        74 => '720P60',
        80 => '1080P',
        112 => '1080P+',
        116 => '1080P60',
        120 => '4K',
        125 => 'HDR',
        126 => '杜比视界',
        127 => '8K',
        0 => '默认',
        _ => '${id}P',
      };

  factory PlayUrlData.fromJson(Map<String, dynamic> j) {
    final dash = j['dash'] as Map<String, dynamic>?;
    List<PlayUrlItem> parse(List<dynamic>? l) => (l ?? [])
        .map((e) => PlayUrlItem.fromJson(e as Map<String, dynamic>))
        .toList();
    final accept = ((j['accept_quality'] ?? const []) as List<dynamic>)
        .map((e) => e is int ? e : int.tryParse('$e') ?? 0)
        .where((e) => e > 0)
        .toList();
    final durl = (j['durl'] as List<dynamic>? ?? []).map((e) {
      final m = e as Map<String, dynamic>;
      final q = (m['id'] ?? (accept.isNotEmpty ? accept.first : 0)) as int;
      return PlayUrlItem(
        baseUrl: (m['url'] ?? '') as String,
        backupUrls: (m['backup_url'] as List<dynamic>? ?? [])
            .map((x) => x.toString())
            .toList(),
        mimeType: 'video/x-flv',
        qualityId: q,
        qualityLabel: qualityName(q),
      );
    }).toList();
    return PlayUrlData(
      dashVideo: parse(dash?['video'] as List<dynamic>?),
      dashAudio: parse(dash?['audio'] as List<dynamic>?),
      durl: durl,
      acceptQuality: accept,
    );
  }

  /// 构建可直接播放的源：优先使用混流的 durl（自带音轨），
  /// 否则使用 DASH 视频 + 外挂最高码率音轨。
  PlaybackSource? buildSource({int? qualityId}) {
    if (durl.isNotEmpty) {
      final pick = qualityId == null
          ? durl.first
          : (durl.firstWhere((e) => e.qualityId == qualityId,
              orElse: () => durl.first));
      return PlaybackSource(
        videoUrl: pick.baseUrl,
        label: '${pick.qualityLabel} · FLV',
      );
    }
    if (dashVideo.isNotEmpty) {
      final sorted = [...dashVideo]
        ..sort((a, b) => b.qualityId.compareTo(a.qualityId));
      final pick = qualityId == null
          ? sorted.first
          : sorted.firstWhere(
              (e) => e.qualityId == qualityId,
              orElse: () => sorted.first,
            );
      PlayUrlItem? audio;
      if (dashAudio.isNotEmpty) {
        final sortedAudio = [...dashAudio]
          ..sort((a, b) => b.bandwidth.compareTo(a.bandwidth));
        audio = sortedAudio.first;
      }
      return PlaybackSource(
        videoUrl: pick.baseUrl,
        audioUrl: audio?.baseUrl,
        label: '${pick.qualityLabel} · DASH',
      );
    }
    return null;
  }
}

/// 播放源：视频地址 + 可选的外挂音轨（DASH 音视频分离）。
class PlaybackSource {
  final String videoUrl;
  final String? audioUrl;
  final String label;

  const PlaybackSource({
    required this.videoUrl,
    this.audioUrl,
    this.label = '',
  });

  bool get isPlayable => videoUrl.isNotEmpty;
}
