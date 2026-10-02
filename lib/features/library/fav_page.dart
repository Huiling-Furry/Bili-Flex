import 'package:flutter/material.dart';
import '../../core/network/bili_dio.dart';
import '../../data/models/library.dart';
import '../../data/repositories/library_repo.dart';
import '../../widgets/media_card.dart';
import '../../widgets/video_route.dart';

/// 我的收藏夹列表。
class FavPage extends StatefulWidget {
  const FavPage({super.key});

  @override
  State<FavPage> createState() => _FavPageState();
}

class _FavPageState extends State<FavPage> {
  final _repo = LibraryRepo();
  List<FavFolder> _folders = [];
  bool _loading = true;
  String? _error;

  bool get _loggedIn => BiliDio.instance.account.isLoggedIn;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!_loggedIn) {
      setState(() => _loading = false);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _repo.favFolders(
          mid: BiliDio.instance.account.session.mid);
      if (mounted) setState(() => _folders = list);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('我的收藏')),
      body: !_loggedIn
          ? _loginHint()
          : _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? _errorView()
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        itemCount: _folders.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final f = _folders[i];
                          return ListTile(
                            leading: const Icon(Icons.folder_outlined),
                            title: Text(f.title),
                            subtitle: Text('${f.mediaCount} 个内容'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => FavResourcePage(
                                  mediaId: f.id,
                                  title: f.title,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }

  Widget _loginHint() => const Center(
        child: Text('登录后可查看收藏夹', style: TextStyle(color: Colors.grey)),
      );

  Widget _errorView() => Center(
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

/// 某个收藏夹内的视频。
class FavResourcePage extends StatefulWidget {
  final int mediaId;
  final String title;

  const FavResourcePage({
    super.key,
    required this.mediaId,
    required this.title,
  });

  @override
  State<FavResourcePage> createState() => _FavResourcePageState();
}

class _FavResourcePageState extends State<FavResourcePage> {
  final _repo = LibraryRepo();
  final _scroll = ScrollController();
  final List<MediaItem> _items = [];
  int _pn = 0;
  bool _loading = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _load();
    _scroll.addListener(() {
      if (_scroll.position.pixels >
          _scroll.position.maxScrollExtent - 400) {
        _load();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_loading || !_hasMore) return;
    setState(() => _loading = true);
    try {
      final list = await _repo.favResources(mediaId: widget.mediaId, pn: _pn + 1);
      if (mounted) {
        setState(() {
          _items.addAll(list);
          _pn++;
          if (list.isEmpty) _hasMore = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _hasMore = false);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: _items.isEmpty && _loading
          ? const Center(child: CircularProgressIndicator())
          : GridView.builder(
              controller: _scroll,
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.78,
              ),
              itemCount: _items.length + (_loading ? 2 : 0),
              itemBuilder: (_, i) {
                if (i >= _items.length) {
                  return const Center(child: CircularProgressIndicator());
                }
                final m = _items[i];
                return MediaGridCard(
                  item: m,
                  onTap: () => openVideo(context, m),
                );
              },
            ),
    );
  }
}