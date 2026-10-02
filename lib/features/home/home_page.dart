import 'package:flutter/material.dart';
import '../../data/models/video.dart';
import '../../data/repositories/home_repo.dart';
import '../../widgets/video_card.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BiliFlex'),
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: '推荐'),
            Tab(text: '热门'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: const [
          _FeedTab(isRecommend: true),
          _FeedTab(isRecommend: false),
        ],
      ),
    );
  }
}

class _FeedTab extends StatefulWidget {
  const _FeedTab({required this.isRecommend});
  final bool isRecommend;

  @override
  State<_FeedTab> createState() => _FeedTabState();
}

class _FeedTabState extends State<_FeedTab>
    with AutomaticKeepAliveClientMixin {
  final _repo = HomeRepo();
  final List<VideoItem> _items = [];
  int _page = 1;
  bool _loading = false;
  String? _error;
  final _scroll = ScrollController();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
    _scroll.addListener(() {
      if (_scroll.position.pixels >
          _scroll.position.maxScrollExtent - 400) {
        _load();
      }
    });
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      if (reset) {
        _page = 1;
        _items.clear();
      }
    });
    try {
      final list = widget.isRecommend
          ? await _repo.feedIndex(idx: _page)
          : await _repo.popular(pn: _page);
      if (mounted) {
        setState(() {
          _items.addAll(list);
          _page++;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_error != null && _items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: () => _load(reset: true), child: const Text('重试')),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () => _load(reset: true),
      child: GridView.builder(
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
          final v = _items[i];
          return VideoCard(
            item: v,
            onTap: () => Navigator.of(context).pushNamed(
              '/video',
              arguments: v.bvid,
            ),
          );
        },
      ),
    );
  }
}
