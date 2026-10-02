import 'package:flutter/material.dart';
import '../../data/models/video.dart';
import '../../data/repositories/search_repo.dart';
import '../../widgets/video_card.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _repo = SearchRepo();
  final _ctrl = TextEditingController();
  List<String> _hots = [];
  List<String> _suggest = [];
  List<VideoItem> _results = [];
  bool _searched = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _repo.hotWords().then((h) => setState(() => _hots = h));
  }

  Future<void> _search(String kw) async {
    if (kw.trim().isEmpty) return;
    setState(() {
      _loading = true;
      _searched = true;
      _suggest = [];
    });
    try {
      final r = await _repo.searchVideo(kw);
      if (mounted) setState(() => _results = r);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('搜索失败: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _ctrl,
          textInputAction: TextInputAction.search,
          onSubmitted: _search,
          onChanged: (s) async {
            if (s.length >= 2) {
              final sug = await _repo.suggest(s);
              if (mounted) setState(() => _suggest = sug);
            }
          },
          decoration: const InputDecoration(
            hintText: '搜索视频 / UP / 番剧',
            border: InputBorder.none,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => _search(_ctrl.text),
          ),
        ],
      ),
      body: _searched ? _resultView() : _hotView(),
    );
  }

  Widget _hotView() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('热搜', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _hots
              .map((h) => ActionChip(
                    label: Text(h),
                    onPressed: () {
                      _ctrl.text = h;
                      _search(h);
                    },
                  ))
              .toList(),
        ),
        if (_suggest.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text('搜索建议', style: TextStyle(fontWeight: FontWeight.bold)),
          ..._suggest.map((s) => ListTile(
                title: Text(s),
                onTap: () {
                  _ctrl.text = s;
                  _search(s);
                },
              )),
        ],
      ],
    );
  }

  Widget _resultView() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_results.isEmpty) {
      return const Center(child: Text('没有结果'));
    }
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.78,
      ),
      itemCount: _results.length,
      itemBuilder: (_, i) {
        final v = _results[i];
        return VideoCard(
          item: v,
          onTap: () => Navigator.of(context).pushNamed('/video', arguments: v.bvid),
        );
      },
    );
  }
}
