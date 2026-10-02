import 'package:flutter/material.dart';
import '../../core/network/bili_dio.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/danmaku.dart';
import '../../data/models/library.dart';
import '../../data/models/video.dart';
import '../../data/repositories/library_repo.dart';
import '../../data/repositories/video_repo.dart';
import '../../widgets/bili_video_player.dart';
import '../../widgets/comment_section.dart';
import '../../widgets/danmaku_list.dart';
import '../../widgets/net_image.dart';

/// 路由参数：从列表页跳转视频详情时携带。
class VideoRouteArgs {
  final String bvid;
  final int aid;
  final int? cid;

  const VideoRouteArgs({this.bvid = '', this.aid = 0, this.cid});
}

class VideoDetailPage extends StatefulWidget {
  final String bvid;
  final int aid;
  final int? initialCid;

  const VideoDetailPage({
    super.key,
    this.bvid = '',
    this.aid = 0,
    this.initialCid,
  });

  @override
  State<VideoDetailPage> createState() => _VideoDetailPageState();
}

class _VideoDetailPageState extends State<VideoDetailPage> {
  final _repo = VideoRepo();
  final _lib = LibraryRepo();
  final _position = ValueNotifier<Duration>(Duration.zero);
  final _commentKey = GlobalKey();

  VideoDetail? _detail;
  List<VideoPage> _pages = [];
  int _pageIndex = 0;

  PlayUrlData? _playData;
  PlaybackSource? _source;
  int? _quality;

  List<DanmakuItem> _danmaku = [];
  List<VideoItem> _related = [];

  String? _error;
  bool _busy = true;
  bool _loadingStream = false;

  String? _bvid;
  int? _aid;

  @override
  void initState() {
    super.initState();
    _bvid = widget.bvid.isEmpty ? null : widget.bvid;
    _aid = widget.aid > 0 ? widget.aid : null;
    _load();
  }

  @override
  void dispose() {
    _position.dispose();
    super.dispose();
  }

  int get _cid {
    if (_pages.isNotEmpty && _pageIndex < _pages.length) {
      final p = _pages[_pageIndex];
      if (p.cid > 0) return p.cid;
    }
    return _detail?.cid ?? 0;
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final d = await _repo.detail(bvid: _bvid, aid: _aid);
      _bvid = d.bvid;
      _aid = d.aid;
      // 分 P：优先使用详情自带 pages，缺失时单独拉取。
      var pages = d.pages;
      if (pages.isEmpty) {
        try {
          pages = await _repo.pages(bvid: _bvid, aid: _aid);
        } catch (_) {}
      }
      _pages = pages;
      if (widget.initialCid != null) {
        final idx = pages.indexWhere((p) => p.cid == widget.initialCid);
        _pageIndex = idx >= 0 ? idx : 0;
      } else {
        final idx = pages.indexWhere((p) => p.cid == d.cid);
        _pageIndex = idx >= 0 ? idx : 0;
      }
      if (mounted) {
        setState(() {
          _detail = d;
          _busy = false;
        });
      }
      await _loadStream();
      _loadDanmaku();
      _loadRelated();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _busy = false;
        });
      }
    }
  }

  Future<void> _loadStream() async {
    final cid = _cid;
    if (cid <= 0) return;
    setState(() => _loadingStream = true);
    try {
      final data = await _repo.playUrlData(cid: cid, bvid: _bvid, aid: _aid);
      if (mounted) {
        setState(() {
          _playData = data;
          _source = data.buildSource(qualityId: _quality);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _source = null);
      }
    } finally {
      if (mounted) setState(() => _loadingStream = false);
    }
  }

  Future<void> _loadDanmaku() async {
    final cid = _cid;
    if (cid <= 0) return;
    try {
      // 每段约 6 分钟，按时长拉全部段落（批量并发，避免串行过慢）
      final segCount =
          ((_detail?.duration ?? 0) / 360).ceil().clamp(1, 30);
      final all = <DanmakuItem>[];
      const batch = 6;
      for (var start = 1; start <= segCount; start += batch) {
        final end = (start + batch - 1).clamp(start, segCount);
        final results = await Future.wait([
          for (var i = start; i <= end; i++)
            _repo
                .danmaku(cid: cid, segmentIndex: i)
                .catchError((_) => <DanmakuItem>[]),
        ]);
        for (final seg in results) {
          all.addAll(seg);
        }
      }
      // 分段返回顺序不保证，这里统一按出现时间排序
      all.sort((a, b) => a.progressMs.compareTo(b.progressMs));
      if (mounted) setState(() => _danmaku = all);
    } catch (_) {}
  }

  Future<void> _loadRelated() async {
    final aid = _aid;
    if (aid == null || aid <= 0) return;
    try {
      final r = await _repo.related(aid: aid);
      if (mounted) setState(() => _related = r);
    } catch (_) {}
  }

  Future<void> _switchPage(int index) async {
    if (index == _pageIndex) return;
    setState(() {
      _pageIndex = index;
      _danmaku = [];
      _source = null;
      _quality = null;
    });
    await _loadStream();
    _loadDanmaku();
  }

  /// 当前生效的画质（未手动选择时取最高可用画质）。
  int get _selectedQn {
    if (_quality != null) return _quality!;
    final list = _playData?.qualities ?? const [];
    return list.isNotEmpty ? list.first.qn : 80;
  }

  /// 切换画质：返回新的播放源，由播放器自行回跳进度。
  Future<PlaybackSource?> _changeQuality(int qn) async {
    final data = _playData;
    if (data == null) return null;
    final src = data.buildSource(qualityId: qn);
    if (mounted) {
      setState(() {
        _quality = qn;
        _source = src;
      });
    }
    return src;
  }

  Future<void> _like() async {
    final d = _detail;
    if (d == null) return;
    await _guard(() async {
      await _repo.likeVideo(bvid: d.bvid, like: 1);
      return '已点赞';
    });
  }

  Future<void> _coin() async {
    final d = _detail;
    if (d == null) return;
    await _guard(() async {
      await _repo.coinVideo(bvid: d.bvid, multiply: 1);
      return '已投币';
    });
  }

  Future<void> _triple() async {
    final d = _detail;
    if (d == null) return;
    await _guard(() async {
      await _repo.triple(bvid: d.bvid);
      return '已三连';
    });
  }

  Future<void> _guard(Future<String> Function() action) async {
    if (!BiliDio.instance.account.isLoggedIn) {
      _toast('请先登录');
      return;
    }
    try {
      final msg = await action();
      _toast(msg);
    } catch (e) {
      _toast('$e');
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  // ---------------- 收藏 ----------------

  Future<void> _openFavSheet() async {
    final d = _detail;
    if (d == null) return;
    if (!BiliDio.instance.account.isLoggedIn) {
      _toast('请先登录');
      return;
    }
    final mid = BiliDio.instance.account.session.mid;
    List<FavFolder> folders;
    try {
      folders = await _lib.favFolders(mid: mid);
    } catch (e) {
      _toast('获取收藏夹失败: $e');
      return;
    }
    if (!mounted) return;
    if (folders.isEmpty) {
      _toast('没有可用的收藏夹');
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(
              dense: true,
              title: Text('选择收藏夹',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            ...folders.map(
              (f) => ListTile(
                leading: const Icon(Icons.folder_outlined),
                title: Text(f.title),
                subtitle: Text('${f.mediaCount} 个内容'),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  await _guard(() async {
                    await _lib.favDeal(
                      mediaId: f.id,
                      aid: d.aid,
                      add: true,
                    );
                    return '已收藏到「${f.title}」';
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- 弹幕 / 多 P ----------------

  Future<void> _openPagesSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: _pages.length,
          itemBuilder: (_, i) {
            final p = _pages[i];
            final active = i == _pageIndex;
            return ListTile(
              selected: active,
              leading: Text('P${p.page}',
                  style: TextStyle(
                      fontWeight:
                          active ? FontWeight.bold : FontWeight.normal)),
              title: Text(p.part.isEmpty ? '第 ${p.page} P' : p.part,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: Text(Formatters.duration(p.duration),
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
              onTap: () {
                Navigator.of(ctx).pop();
                _switchPage(i);
              },
            );
          },
        ),
      ),
    );
  }

  void _scrollToComments() {
    final ctx = _commentKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx,
          duration: const Duration(milliseconds: 300));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('视频详情')),
      body: _busy
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _errorView()
              : _buildBody(),
    );
  }

  Widget _errorView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_error!, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: _load, child: const Text('重试')),
        ],
      ),
    );
  }

  Widget _buildBody() {
    final d = _detail!;
    return ListView(
      children: [
        BiliVideoPlayer(
          source: _source,
          danmaku: _danmaku,
          positionNotifier: _position,
          qualities: _playData?.qualities ?? const [],
          currentQn: _selectedQn,
          onQualityChange: _changeQuality,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(d.title,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(
                '${Formatters.count(d.view)} 播放 · ${Formatters.count(d.danmaku)} 弹幕 · ${Formatters.timeAgo(d.pubdate)}',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const SizedBox(height: 10),
              _ownerRow(d),
              const SizedBox(height: 12),
              _actionBar(d),
              const SizedBox(height: 8),
              if (d.desc.isNotEmpty)
                Text(d.desc,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.black54, fontSize: 13)),
              const Divider(height: 28),
              _streamBar(),
              if (_pages.length > 1) ...[
                const SizedBox(height: 8),
                _pageSelector(),
              ],
              const Divider(height: 28),
            ],
          ),
        ),
        _danmakuSection(),
        const Divider(height: 28),
        Padding(
          key: _commentKey,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: CommentSection(oid: d.aid, initialCount: d.reply),
        ),
        const Divider(height: 28),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text('相关视频',
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 8),
        ..._related.map(_relatedTile),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _ownerRow(VideoDetail d) {
    return Row(
      children: [
        InkWell(
          onTap: d.ownerMid > 0 ? () => _openSpace(d.ownerMid) : null,
          child: Row(
            children: [
              if (d.ownerFace.isEmpty)
                const CircleAvatar(radius: 14, child: Icon(Icons.person, size: 16))
              else
                ClipOval(
                  child: NetImage(url: d.ownerFace, width: 28, height: 28),
                ),
              const SizedBox(width: 8),
              Text(d.ownerName, style: const TextStyle(fontSize: 13)),
              const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
            ],
          ),
        ),
        const Spacer(),
        if (d.ownerMid > 0)
          OutlinedButton(
            onPressed: () => _openSpace(d.ownerMid),
            style: OutlinedButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            child: const Text('进空间', style: TextStyle(fontSize: 12)),
          ),
      ],
    );
  }

  void _openSpace(int mid) {
    Navigator.of(context).pushNamed('/space', arguments: mid);
  }

  Widget _actionBar(VideoDetail d) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _btn(Icons.thumb_up_outlined, Formatters.count(d.like), _like),
        _btn(Icons.monetization_on_outlined, Formatters.count(d.coin), _coin),
        _btn(Icons.star_border, Formatters.count(d.favorite), _openFavSheet),
        _btn(Icons.comment_outlined, Formatters.count(d.reply),
            _scrollToComments),
        _btn(Icons.thumb_up_alt_outlined, '三连', _triple),
      ],
    );
  }

  Widget _btn(IconData icon, String label, VoidCallback? onTap) {
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 20),
      label: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }

  Widget _streamBar() {
    final src = _source;
    return Row(
      children: [
        Icon(
          _loadingStream ? Icons.hourglass_top : Icons.hd_outlined,
          size: 18,
          color: Colors.grey,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            _loadingStream
                ? '正在解析播放流…'
                : src == null
                    ? '暂无可用播放流（可能需要登录或大会员）'
                    : '当前：${src.label}',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ),
      ],
    );
  }

  Widget _pageSelector() {
    final current = _pages[_pageIndex];
    return InkWell(
      onTap: _openPagesSheet,
      child: Row(
        children: [
          const Icon(Icons.playlist_play, size: 18, color: Colors.grey),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'P${current.page} · ${current.part.isEmpty ? '第 ${current.page} P' : current.part}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13),
            ),
          ),
          Text('共 ${_pages.length} P',
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const Icon(Icons.expand_more, size: 18, color: Colors.grey),
        ],
      ),
    );
  }

  Widget _danmakuSection() {
    final d = _detail!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('弹幕 ${_danmaku.length}',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold)),
              const Spacer(),
              Text('按播放进度高亮',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            ],
          ),
          const SizedBox(height: 4),
          DanmakuList(items: _danmaku, position: _position),
          Align(
            alignment: Alignment.centerRight,
            child: Text('统计：${Formatters.count(d.danmaku)} 条',
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  Widget _relatedTile(VideoItem v) {
    return ListTile(
      leading: SizedBox(
        width: 120,
        child: NetImage(url: v.cover, radius: BorderRadius.circular(6)),
      ),
      title: Text(v.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13)),
      subtitle: Text('${v.author} · ${Formatters.count(v.playCount)}播放',
          style: const TextStyle(fontSize: 11, color: Colors.grey)),
      onTap: () => Navigator.of(context).pushNamed(
        '/video',
        arguments: VideoRouteArgs(bvid: v.bvid, aid: v.aid),
      ),
    );
  }
}