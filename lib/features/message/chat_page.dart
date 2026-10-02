import 'dart:convert';

import 'package:flutter/material.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/message.dart';
import '../../data/repositories/message_repo.dart';
import '../../widgets/chat_bubble.dart';
import '../../widgets/net_image.dart';

/// 进入聊天页所需的参数（用于路由传参）。
class ChatArgs {
  final int talkerId;
  final String name;
  final String face;
  const ChatArgs({required this.talkerId, required this.name, this.face = ''});
}

/// 私信聊天详情页。
class ChatPage extends StatefulWidget {
  final int talkerId;
  final String name;
  final String face;

  const ChatPage({
    super.key,
    required this.talkerId,
    required this.name,
    this.face = '',
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _repo = MessageRepo();
  final _scroll = ScrollController();
  final _input = TextEditingController();
  final List<ImMessage> _messages = []; // 时间正序：旧 → 新
  bool _loading = false;
  bool _sending = false;
  bool _hasMore = true;
  int _minSeqno = 0;
  String? _error;

  int get _selfUid => _repo.selfUid;

  @override
  void initState() {
    super.initState();
    _load();
    _scroll.addListener(() {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 300) {
        _loadOlder();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    _input.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await _repo.history(talkerId: widget.talkerId);
      if (mounted) {
        setState(() {
          _messages
            ..clear()
            ..addAll(page.messages);
          _hasMore = page.hasMore;
          _minSeqno = page.minSeqno;
        });
        _markRead();
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadOlder() async {
    if (_loading || !_hasMore || _minSeqno <= 0) return;
    setState(() => _loading = true);
    try {
      final page = await _repo.history(
        talkerId: widget.talkerId,
        endSeqno: _minSeqno,
      );
      if (mounted) {
        setState(() {
          _messages.insertAll(0, page.messages);
          _hasMore = page.hasMore;
          if (page.minSeqno > 0) _minSeqno = page.minSeqno;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markRead() async {
    final seqno = _messages.fold<int>(
        0, (m, e) => e.msgSeqno > m ? e.msgSeqno : m);
    try {
      await _repo.ackSession(
        talkerId: widget.talkerId,
        ackSeqno: seqno > 0 ? seqno : null,
      );
    } catch (_) {}
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    final optimistic = ImMessage(
      senderUid: _selfUid,
      receiverId: widget.talkerId,
      msgType: 1,
      content: jsonEncode({'content': text}),
      timestamp: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    );
    setState(() => _messages.add(optimistic));
    _input.clear();
    try {
      await _repo.sendText(talkerId: widget.talkerId, content: text);
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        setState(() => _messages.remove(optimistic));
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('发送失败: $e')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollToBottom() {
    if (!_scroll.hasClients) return;
    _scroll.animateTo(
      0,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.name)),
      body: Column(
        children: [
          Expanded(child: _list()),
          _inputBar(),
        ],
      ),
    );
  }

  Widget _list() {
    if (_messages.isEmpty) {
      return Center(
        child: Text(
          _loading ? '加载中…' : (_error ?? '还没有消息，打个招呼吧'),
          style: const TextStyle(color: Colors.grey),
        ),
      );
    }
    return ListView.builder(
      controller: _scroll,
      reverse: true,
      padding: const EdgeInsets.symmetric(vertical: 12),
      itemCount: _messages.length + (_hasMore ? 1 : 0),
      itemBuilder: (_, i) {
        if (i >= _messages.length) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        final m = _messages[_messages.length - 1 - i];
        return _bubble(m);
      },
    );
  }

  Widget _bubble(ImMessage m) {
    final mine = m.senderUid == _selfUid;
    final bubble = ChatBubble(
      msg: m,
      isOwner: mine,
      onLongPress: mine && !m.isRevoked && m.msgKey > 0
          ? () => _confirmRevoke(m)
          : null,
    );

    final time = Padding(
      padding: EdgeInsets.only(left: mine ? 0 : 42),
      child: Text(
        Formatters.timeAgo(m.timestamp),
        style: const TextStyle(fontSize: 11, color: Colors.grey),
      ),
    );

    if (m.isSystem) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          children: [bubble, const SizedBox(height: 3), time],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Column(
        crossAxisAlignment:
            mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment:
                mine ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!mine) ...[
                _avatar(m.senderUid),
                const SizedBox(width: 8),
              ],
              Flexible(child: bubble),
            ],
          ),
          const SizedBox(height: 3),
          time,
        ],
      ),
    );
  }

  /// 长按自己的消息 → 撤回。
  Future<void> _confirmRevoke(ImMessage m) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListTile(
          leading: const Icon(Icons.undo),
          title: const Text('撤回这条消息'),
          onTap: () => Navigator.of(ctx).pop(true),
        ),
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await _repo.revoke(talkerId: widget.talkerId, msgKey: m.msgKey);
      if (!mounted) return;
      setState(() {
        final i = _messages.indexOf(m);
        if (i >= 0) _messages[i] = m.copyWith(msgStatus: 1);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('撤回失败: $e')));
      }
    }
  }

  Widget _avatar(int mid) {
    final url = mid == widget.talkerId ? widget.face : '';
    if (url.isEmpty) {
      return const CircleAvatar(radius: 16, child: Icon(Icons.person, size: 18));
    }
    return ClipOval(child: NetImage(url: url, width: 32, height: 32));
  }

  Widget _inputBar() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          border: const Border(top: BorderSide(color: Color(0xFFEAECEF))),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _input,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                decoration: InputDecoration(
                  hintText: '发个消息…',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF2F3F5),
                ),
              ),
            ),
            const SizedBox(width: 6),
            IconButton(
              icon: _sending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded),
              color: Theme.of(context).colorScheme.primary,
              onPressed: _sending ? null : _send,
            ),
          ],
        ),
      ),
    );
  }
}