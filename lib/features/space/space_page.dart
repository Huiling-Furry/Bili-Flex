import 'package:flutter/material.dart';
import '../../core/network/bili_dio.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/space.dart';
import '../../data/models/video.dart';
import '../../data/repositories/user_repo.dart';
import '../../widgets/net_image.dart';
import '../../widgets/video_card.dart';
import '../message/chat_page.dart';

/// 用户空间：名片 + 关注 + 投稿列表。
class SpacePage extends StatefulWidget {
  final int mid;
  const SpacePage({super.key, required this.mid});

  @override
  State<SpacePage> createState() => _SpacePageState();
}

class _SpacePageState extends State<SpacePage> {
  final _repo = UserRepo();
  final _scroll = ScrollController();

  SpaceInfo? _info;
  final List<VideoItem> _archives = [];
  int _pn = 0;
  bool _hasMore = true;

  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  bool? _following;

  bool get _loggedIn => BiliDio.instance.account.isLoggedIn;
  bool get _isSelf =>
      BiliDio.instance.account.session.mid == widget.mid;

  @override
  void initState() {
    super.initState();
    _load();
    _scroll.addListener(() {
      if (_scroll.position.pixels >
          _scroll.position.maxScrollExtent - 400) {
        _loadArchives();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final info = await _repo.spaceInfo(widget.mid);
      if (mounted) setState(() => _info = info);
      if (_loggedIn && !_isSelf) {
        try {
          final f = await _repo.isFollowing(widget.mid);
          if (mounted) setState(() => _following = f);
        } catch (_) {}
      }
      await _loadArchives(reset: true);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadArchives({bool reset = false}) async {
    if (_loadingMore) return;
    if (!reset && !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final list =
          await _repo.archive(widget.mid, pn: reset ? 1 : _pn + 1);
      if (mounted) {
        setState(() {
          if (reset) _archives.clear();
          _archives.addAll(list);
          _pn = reset ? 1 : _pn + 1;
          if (list.isEmpty) _hasMore = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _hasMore = false);
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _toggleFollow() async {
    if (!_loggedIn) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('请先登录')));
      return;
    }
    final next = !(_following ?? false);
    setState(() => _following = next);
    try {
      await _repo.relation(widget.mid, next ? 1 : 2);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(next ? '已关注' : '已取消关注')));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _following = !next);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('操作失败: $e')));
      }
    }
  }

  void _openChat() {
    if (!_loggedIn) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('请先登录')));
      return;
    }
    Navigator.of(context).pushNamed(
      '/chat',
      arguments: ChatArgs(
        talkerId: widget.mid,
        name: _info?.name ?? '用户空间',
        face: _info?.face ?? '',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('用户空间')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!,
                          style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 12),
                      ElevatedButton(onPressed: _load, child: const Text('重试')),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: CustomScrollView(
                    controller: _scroll,
                    slivers: [
                      SliverToBoxAdapter(child: _header()),
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(12, 8, 12, 8),
                          child: Text('投稿视频',
                              style: TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      _archiveSliver(),
                      const SliverToBoxAdapter(child: SizedBox(height: 24)),
                    ],
                  ),
                ),
    );
  }

  Widget _header() {
    final info = _info;
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipOval(
                child: info != null && info.face.isNotEmpty
                    ? NetImage(url: info.face, width: 64, height: 64)
                    : const CircleAvatar(
                        radius: 32, child: Icon(Icons.person, size: 32)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            info?.name ?? '未知用户',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ),
                        if ((info?.level ?? 0) > 0) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text('Lv${info!.level}',
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 10)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '关注 ${Formatters.count(info?.following)} · 粉丝 ${Formatters.count(info?.fans)}',
                      style:
                          const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              if (!_isSelf && _loggedIn)
                IconButton(
                  tooltip: '发私信',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.mail_outline),
                  onPressed: _openChat,
                ),
              if (!_isSelf && _following != null)
                _following!
                    ? OutlinedButton(
                        onPressed: _toggleFollow,
                        style: OutlinedButton.styleFrom(
                            visualDensity: VisualDensity.compact),
                        child: const Text('已关注',
                            style: TextStyle(fontSize: 12)),
                      )
                    : FilledButton(
                        onPressed: _toggleFollow,
                        style: FilledButton.styleFrom(
                            visualDensity: VisualDensity.compact),
                        child: const Text('关注',
                            style: TextStyle(fontSize: 12)),
                      ),
            ],
          ),
          if (info != null && info.sign.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(info.sign,
                style: const TextStyle(fontSize: 12, color: Colors.black54)),
          ],
          if (info != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                _stat('获赞', info.likes),
                _stat('播放', info.plays),
                _stat('投稿', _archives.length),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _stat(String label, int value) {
    return Expanded(
      child: Column(
        children: [
          Text(Formatters.count(value),
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.bold)),
          Text(label,
              style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _archiveSliver() {
    if (_archives.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Center(
            child: Text(
              _loadingMore ? '加载中…' : '暂无投稿',
              style: const TextStyle(color: Colors.grey),
            ),
          ),
        ),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.all(12),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.78,
        ),
        delegate: SliverChildBuilderDelegate(
          (_, i) {
            final v = _archives[i];
            return VideoCard(
              item: v,
              onTap: () => Navigator.of(context).pushNamed(
                '/video',
                arguments: v.bvid,
              ),
            );
          },
          childCount: _archives.length,
        ),
      ),
    );
  }
}