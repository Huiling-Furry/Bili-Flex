import 'package:flutter/material.dart';
import '../core/network/bili_dio.dart';
import '../core/utils/formatters.dart';
import '../data/models/comment.dart';
import '../data/repositories/comment_repo.dart';
import 'net_image.dart';

/// 评论区：排序切换 + 发送 + 点赞 + 分页加载。
class CommentSection extends StatefulWidget {
  final int oid;
  final int initialCount;
  final int scrollLimit;

  const CommentSection({
    super.key,
    required this.oid,
    this.initialCount = 0,
    this.scrollLimit = 6,
  });

  @override
  State<CommentSection> createState() => _CommentSectionState();
}

class _CommentSectionState extends State<CommentSection> {
  final _repo = CommentRepo();
  final _input = TextEditingController();
  final List<ReplyItem> _items = [];
  int _sort = 2; // 2=热门 0=时间
  int _pn = 0;
  int _pageCount = 1;
  int _allCount = 0;
  bool _loading = false;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _allCount = widget.initialCount;
    _loadMore(reset: true);
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _loadMore({bool reset = false}) async {
    if (_loading) return;
    if (!reset && _pn >= _pageCount) return;
    setState(() {
      _loading = true;
      if (reset) {
        _pn = 0;
        _items.clear();
      }
    });
    try {
      final page = await _repo.list(
        oid: widget.oid,
        sort: _sort,
        pn: _pn + 1,
      );
      if (mounted) {
        setState(() {
          _items.addAll(page.replies);
          _pn = page.page;
          _pageCount = page.pageCount;
          if (page.allCount > 0) _allCount = page.allCount;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _switchSort(int sort) {
    if (_sort == sort) return;
    setState(() => _sort = sort);
    _loadMore(reset: true);
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    if (!BiliDio.instance.account.isLoggedIn) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('请先登录后再评论')));
      return;
    }
    setState(() => _sending = true);
    try {
      await _repo.add(oid: widget.oid, message: text);
      if (!mounted) return;
      _input.clear();
      FocusScope.of(context).unfocus();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('评论已发送')));
      await _loadMore(reset: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('发送失败: $e')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _toggleLike(ReplyItem item) async {
    if (!BiliDio.instance.account.isLoggedIn) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('请先登录')));
      return;
    }
    final liked = !item.liked;
    // 乐观更新
    final idx = _items.indexWhere((e) => e.rpid == item.rpid);
    if (idx >= 0) {
      setState(() {
        _items[idx] = item.copyWith(
          liked: liked,
          like: item.like + (liked ? 1 : -1),
        );
      });
    }
    try {
      await _repo.like(oid: widget.oid, rpid: item.rpid, liked: liked);
    } catch (e) {
      if (idx >= 0 && mounted) {
        setState(() => _items[idx] = item);
      }
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('操作失败: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('评论 $_allCount',
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold)),
            const Spacer(),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 2, label: Text('热门')),
                ButtonSegment(value: 0, label: Text('最新')),
              ],
              selected: {_sort},
              showSelectedIcon: false,
              style: const ButtonStyle(
                visualDensity: VisualDensity.compact,
                textStyle: WidgetStatePropertyAll(TextStyle(fontSize: 12)),
              ),
              onSelectionChanged: (s) => _switchSort(s.first),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _input,
                minLines: 1,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: '发一条友善的评论…',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _sending ? null : _send,
              child: _sending
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('发送'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_items.isEmpty && _loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          ),
        if (_items.isEmpty && !_loading)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(_error ?? '还没有评论，快来抢沙发',
                  style: const TextStyle(color: Colors.grey)),
            ),
          ),
        ..._items.map(_buildComment),
        if (_items.isNotEmpty && _pn < _pageCount)
          Center(
            child: TextButton(
              onPressed: _loading ? null : () => _loadMore(),
              child: Text(_loading ? '加载中…' : '加载更多评论'),
            ),
          ),
      ],
    );
  }

  Widget _buildComment(ReplyItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _avatar(item.avatar, 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.uname,
                    style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Text(item.message, style: const TextStyle(fontSize: 14)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(Formatters.timeAgo(item.ctime),
                        style:
                            const TextStyle(fontSize: 11, color: Colors.grey)),
                    const SizedBox(width: 16),
                    InkWell(
                      onTap: () => _toggleLike(item),
                      child: Row(
                        children: [
                          Icon(
                            item.liked
                                ? Icons.thumb_up
                                : Icons.thumb_up_outlined,
                            size: 14,
                            color: item.liked ? Colors.blue : Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Text(Formatters.count(item.like),
                              style: TextStyle(
                                  fontSize: 11,
                                  color: item.liked
                                      ? Colors.blue
                                      : Colors.grey)),
                        ],
                      ),
                    ),
                  ],
                ),
                if (item.replies.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
                          .withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: item.replies
                          .take(3)
                          .map((r) => Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 3),
                                child: RichText(
                                  text: TextSpan(
                                    style: const TextStyle(
                                        fontSize: 13, color: Colors.black87),
                                    children: [
                                      TextSpan(
                                        text: '${r.uname}：',
                                        style: const TextStyle(
                                            color: Colors.grey),
                                      ),
                                      TextSpan(text: r.message),
                                    ],
                                  ),
                                ),
                              ))
                          .toList(),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatar(String url, double radius) {
    if (url.isEmpty) {
      return CircleAvatar(
        radius: radius,
        child: Icon(Icons.person, size: radius),
      );
    }
    return ClipOval(
      child: NetImage(url: url, width: radius * 2, height: radius * 2),
    );
  }
}