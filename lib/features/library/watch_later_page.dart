import 'package:flutter/material.dart';
import '../../core/network/bili_dio.dart';
import '../../data/models/library.dart';
import '../../data/repositories/library_repo.dart';
import '../../widgets/media_card.dart';
import '../../widgets/video_route.dart';

/// 稍后再看。
class WatchLaterPage extends StatefulWidget {
  const WatchLaterPage({super.key});

  @override
  State<WatchLaterPage> createState() => _WatchLaterPageState();
}

class _WatchLaterPageState extends State<WatchLaterPage> {
  final _repo = LibraryRepo();
  List<MediaItem> _items = [];
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
      final list = await _repo.watchLater();
      if (mounted) setState(() => _items = list);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _remove(MediaItem item) async {
    final idx = _items.indexWhere((e) => e.aid == item.aid);
    if (idx < 0) return;
    setState(() => _items.removeAt(idx));
    try {
      await _repo.removeWatchLater(aid: item.aid);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('已移出稍后再看')));
      }
    } catch (e) {
      // 失败则回滚
      if (mounted) {
        setState(() => _items.insert(idx, item));
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('移除失败: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('稍后再看')),
      body: !_loggedIn
          ? const Center(
              child:
                  Text('登录后可查看稍后再看', style: TextStyle(color: Colors.grey)))
          : _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_error!,
                              style: const TextStyle(color: Colors.red)),
                          const SizedBox(height: 12),
                          ElevatedButton(
                              onPressed: _load, child: const Text('重试')),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: _items.isEmpty
                          ? ListView(
                              children: const [
                                SizedBox(height: 120),
                                Center(
                                  child: Text('暂无稍后再看内容',
                                      style: TextStyle(color: Colors.grey)),
                                ),
                              ],
                            )
                          : ListView.builder(
                              itemCount: _items.length,
                              itemBuilder: (_, i) {
                                final m = _items[i];
                                return MediaListTile(
                                  item: m,
                                  onTap: () => openVideo(context, m),
                                  actions: [
                                    IconButton(
                                      tooltip: '移出',
                                      icon: const Icon(
                                          Icons.playlist_remove, size: 20),
                                      onPressed: () => _remove(m),
                                    ),
                                  ],
                                );
                              },
                            ),
                    ),
    );
  }
}