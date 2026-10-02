import 'package:flutter/material.dart';
import '../../core/network/bili_dio.dart';
import '../../data/models/library.dart';
import '../../data/repositories/library_repo.dart';
import '../../widgets/media_card.dart';
import '../../widgets/video_route.dart';

/// 观看历史。
class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final _repo = LibraryRepo();
  final _scroll = ScrollController();
  final List<MediaItem> _items = [];
  int _max = 0;
  int _viewAt = 0;
  bool _loading = false;
  bool _hasMore = true;
  String? _error;

  bool get _loggedIn => BiliDio.instance.account.isLoggedIn;

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

  Future<void> _load({bool reset = false}) async {
    if (!_loggedIn) return;
    if (_loading) return;
    if (!reset && !_hasMore) return;
    setState(() {
      _loading = true;
      _error = null;
      if (reset) {
        _items.clear();
        _max = 0;
        _viewAt = 0;
        _hasMore = true;
      }
    });
    try {
      final page = await _repo.history(max: _max, viewAt: _viewAt);
      if (mounted) {
        setState(() {
          _items.addAll(page.items);
          _max = page.max;
          _viewAt = page.viewAt;
          if (page.items.isEmpty) _hasMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _hasMore = false;
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _delete(MediaItem item) async {
    setState(() => _items.removeWhere((e) => e.aid == item.aid));
    try {
      await _repo.deleteHistory(aid: item.aid);
    } catch (_) {}
  }

  Future<void> _clearAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清空历史记录'),
        content: const Text('确定要清空全部观看历史吗？此操作不可撤销。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('清空')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _repo.clearHistory();
      if (mounted) setState(() => _items.clear());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('清空失败: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('观看历史'),
        actions: [
          if (_loggedIn && _items.isNotEmpty)
            IconButton(
              tooltip: '清空',
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: _clearAll,
            ),
        ],
      ),
      body: !_loggedIn
          ? const Center(
              child:
                  Text('登录后可查看观看历史', style: TextStyle(color: Colors.grey)))
          : RefreshIndicator(
              onRefresh: () => _load(reset: true),
              child: _items.isEmpty
                  ? ListView(
                      children: [
                        const SizedBox(height: 120),
                        Center(
                          child: Text(
                            _loading
                                ? '加载中…'
                                : (_error ?? '暂无观看历史'),
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      controller: _scroll,
                      itemCount: _items.length + (_hasMore ? 1 : 0),
                      itemBuilder: (_, i) {
                        if (i >= _items.length) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        final m = _items[i];
                        return Dismissible(
                          key: ValueKey('h_${m.aid}_${m.cid}'),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            color: Colors.red,
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            child: const Icon(Icons.delete, color: Colors.white),
                          ),
                          onDismissed: (_) => _delete(m),
                          child: MediaListTile(
                            item: m,
                            onTap: () => openVideo(context, m),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}