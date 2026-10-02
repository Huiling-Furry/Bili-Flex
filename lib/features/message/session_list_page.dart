import 'package:flutter/material.dart';
import '../../core/network/bili_dio.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/message.dart';
import '../../data/repositories/message_repo.dart';
import '../../widgets/net_image.dart';
import 'chat_page.dart';

/// 私信会话列表。
class SessionListPage extends StatefulWidget {
  const SessionListPage({super.key});

  @override
  State<SessionListPage> createState() => _SessionListPageState();
}

class _SessionListPageState extends State<SessionListPage> {
  final _repo = MessageRepo();
  final List<ImSession> _sessions = [];
  bool _loading = false;
  String? _error;

  bool get _loggedIn => BiliDio.instance.account.isLoggedIn;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!_loggedIn) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _repo.sessions();
      // 回填头像 / 昵称（系统会话自带 account_info，无需查询）。
      final needCards = list
          .where((s) => s.face.isEmpty)
          .map((s) => s.talkerId)
          .toList();
      if (needCards.isNotEmpty) {
        final cards = await _repo.userCards(needCards);
        for (final s in list) {
          s.user ??= cards[s.talkerId];
        }
      }
      list.sort((a, b) {
        if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
        return b.timestamp.compareTo(a.timestamp);
      });
      if (mounted) {
        setState(() {
          _sessions
            ..clear()
            ..addAll(list);
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open(ImSession s) async {
    if (s.hasUnread) {
      setState(() => s.unreadCount = 0);
      try {
        await _repo.ackSession(talkerId: s.talkerId);
      } catch (_) {}
    }
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatPage(
          talkerId: s.talkerId,
          name: s.title,
          face: s.face,
        ),
      ),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('我的消息')),
      body: !_loggedIn
          ? const Center(
              child: Text('登录后可查看私信', style: TextStyle(color: Colors.grey)))
          : RefreshIndicator(
              onRefresh: _load,
              child: _sessions.isEmpty
                  ? ListView(
                      children: [
                        const SizedBox(height: 120),
                        Center(
                          child: Text(
                            _loading ? '加载中…' : (_error ?? '暂无私信'),
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ),
                      ],
                    )
                  : ListView.separated(
                      itemCount: _sessions.length,
                      separatorBuilder: (_, _) =>
                          const Divider(height: 1, indent: 72),
                      itemBuilder: (_, i) => _tile(_sessions[i]),
                    ),
            ),
    );
  }

  Widget _tile(ImSession s) {
    final theme = Theme.of(context);
    return ListTile(
      tileColor: s.isPinned
          ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4)
          : null,
      leading: s.face.isNotEmpty
          ? ClipOval(child: NetImage(url: s.face, width: 46, height: 46))
          : const CircleAvatar(radius: 23, child: Icon(Icons.person)),
      title: Text(
        s.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 15),
      ),
      subtitle: Text(
        s.preview,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
      ),
      trailing: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            Formatters.timeAgo(s.timestamp),
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 6),
          if (s.isDnd)
            const Icon(Icons.notifications_off_outlined,
                size: 16, color: Colors.grey)
          else if (s.hasUnread)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(10),
              ),
              constraints: const BoxConstraints(minWidth: 18),
              child: Text(
                s.unreadCount > 99 ? '99+' : '${s.unreadCount}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 11),
              ),
            ),
        ],
      ),
      onTap: () => _open(s),
    );
  }
}