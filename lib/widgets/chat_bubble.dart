import 'dart:convert';

import 'package:flutter/material.dart';

import '../data/models/message.dart';
import 'net_image.dart';

/// 单条私信消息气泡，覆盖 12 种消息类型的渲染。
///
/// [isOwner] true=自己发的（右侧），false=对方发的（左侧）。
class ChatBubble extends StatelessWidget {
  final ImMessage msg;
  final bool isOwner;
  final VoidCallback? onLongPress;

  const ChatBubble({
    super.key,
    required this.msg,
    required this.isOwner,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = msg.body;

    final child = _buildContent(context, theme, content);

    // 系统消息不包气泡，直接全宽展示
    if (msg.isSystem) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onLongPress: onLongPress,
        child: child,
      );
    }

    final isPic = msg.msgType == MsgType.pic;
    final bubble = Container(
      constraints: const BoxConstraints(maxWidth: 300),
      decoration: BoxDecoration(
        color: isOwner
            ? theme.colorScheme.secondaryContainer
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: isOwner
            ? const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(6),
              )
            : const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(6),
                bottomRight: Radius.circular(16),
              ),
      ),
      padding: isPic
          ? const EdgeInsets.fromLTRB(8, 8, 8, 6)
          : const EdgeInsets.fromLTRB(12, 8, 12, 6),
      child: Column(
        crossAxisAlignment:
            isOwner ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          child,
          SizedBox(height: isPic ? 7 : 2),
          if (msg.isRevoked)
            Text(
              '已撤回',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          if (msg.isAutoReply) ...[
            Divider(
              height: 10,
              thickness: 1,
              color: theme.colorScheme.outline.withValues(alpha: 0.2),
            ),
            Text(
              '此条消息为自动回复',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ],
      ),
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: onLongPress,
      child: bubble,
    );
  }

  Widget _buildContent(
      BuildContext context, ThemeData theme, Map<String, dynamic> content) {
    try {
      switch (msg.msgType) {
        case MsgType.text:
          return _text(theme, content);
        case MsgType.pic:
          return _pic(context, content);
        case MsgType.shareV2:
          return _shareV2(context, theme, content);
        case MsgType.videoCard:
          return _videoCard(context, theme, content);
        case MsgType.articleCard:
          return _articleCard(context, theme, content);
        case MsgType.commonShareCard:
          return _commonShareCard(context, theme, content);
        case MsgType.notifyMsg:
          return _notifyMsg(theme, content);
        case MsgType.pictureCard:
          return _pictureCard(content);
        case MsgType.recommendCard:
          return _recommendCard(context, theme, content);
        case MsgType.tipMessage:
          return _tipMessage(theme, content);
        default:
          return _fallback(theme, content);
      }
    } catch (_) {
      return _fallback(theme, content);
    }
  }

  // ---------- 文本 ----------
  Widget _text(ThemeData theme, Map<String, dynamic> content) {
    final text = content['content']?.toString() ?? '';
    final style = TextStyle(
      color: isOwner
          ? theme.colorScheme.onSecondaryContainer
          : theme.colorScheme.onSurface,
      height: 1.5,
    );
    // URL 高亮
    final spans = <InlineSpan>[];
    text.splitMapJoin(
      RegExp(r'https?://[^\s]+'),
      onMatch: (m) {
        spans.add(TextSpan(
          text: m.group(0),
          style: style.copyWith(color: theme.colorScheme.primary),
        ));
        return '';
      },
      onNonMatch: (s) {
        spans.add(TextSpan(text: s, style: style));
        return '';
      },
    );
    return SelectableText.rich(TextSpan(children: spans));
  }

  // ---------- 图片 ----------
  Widget _pic(BuildContext context, Map<String, dynamic> content) {
    final url = content['url']?.toString() ?? '';
    if (url.isEmpty) return _fallback(Theme.of(context), content);
    final w = (content['width'] as num?)?.toDouble() ?? 220;
    final h = (content['height'] as num?)?.toDouble() ?? 220;
    final width = w > 0 && w < 220 ? w : 220.0;
    final height = w > 0 ? width * (h / w) : 220.0;
    return NetImage(
      url: url,
      width: width,
      height: height,
      radius: BorderRadius.circular(8),
    );
  }

  // ---------- 分享 V2 ----------
  Widget _shareV2(
      BuildContext context, ThemeData theme, Map<String, dynamic> content) {
    final source = content['source'] as int? ?? 0;
    final typeLabel = switch (source) {
      ShareSource.album => '相簿',
      ShareSource.video => '视频',
      ShareSource.article => '专栏',
      ShareSource.dynamic => '动态',
      ShareSource.pgc => '番剧',
      _ => null,
    };
    return GestureDetector(
      onTap: () => _onShareTap(context, source, content),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          NetImage(
            url: content['thumb']?.toString() ?? '',
            width: 220,
            height: 123.75,
            radius: BorderRadius.circular(8),
          ),
          const SizedBox(height: 6),
          Text(
            content['title']?.toString() ?? '',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isOwner
                  ? theme.colorScheme.onSecondaryContainer
                  : theme.colorScheme.onSurface,
              fontWeight: FontWeight.bold,
              height: 1.4,
            ),
          ),
          if ((content['headline'] as String?)?.isNotEmpty == true)
            Text(
              content['headline'].toString(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isOwner
                    ? theme.colorScheme.onSecondaryContainer
                    : theme.colorScheme.onSurface,
                fontSize: 12,
              ),
            ),
          if (content['author'] != null)
            Text(
              '${content['author']}${typeLabel != null ? ' · $typeLabel' : ''}',
              style: TextStyle(
                color: (isOwner
                        ? theme.colorScheme.onSecondaryContainer
                        : theme.colorScheme.onSurface)
                    .withValues(alpha: 0.6),
                fontSize: 12,
              ),
            ),
        ],
      ),
    );
  }

  void _onShareTap(
      BuildContext context, int source, Map<String, dynamic> content) {
    if (source == ShareSource.video) {
      _openVideo(context, content['bvid']?.toString());
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('暂不支持打开此类型（$source）')),
    );
  }

  // ---------- 视频卡片 ----------
  Widget _videoCard(
      BuildContext context, ThemeData theme, Map<String, dynamic> content) {
    final attachMsg = content['attach_msg']?['content']?.toString();
    final seconds = content['times'] as int? ?? 0;
    return Center(
      child: Container(
        clipBehavior: Clip.hardEdge,
        constraints: const BoxConstraints(maxWidth: 400),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: theme.colorScheme.surfaceContainerHighest,
        ),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _openVideo(context, content['bvid']?.toString()),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Stack(
                children: [
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: NetImage(
                      url: content['cover']?.toString() ?? '',
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    left: 6,
                    bottom: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _formatDuration(seconds),
                        style: const TextStyle(
                            color: Colors.white, fontSize: 11),
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Text(
                  seconds == 0
                      ? '内容已失效'
                      : content['title']?.toString() ?? '',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                    height: 1.4,
                  ),
                ),
              ),
              if (attachMsg?.isNotEmpty == true)
                Container(
                  margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    attachMsg!,
                    style: TextStyle(
                        color: theme.colorScheme.onSurface, fontSize: 13),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- 专栏卡片 ----------
  Widget _articleCard(
      BuildContext context, ThemeData theme, Map<String, dynamic> content) {
    final images = content['image_urls'] as List<dynamic>? ?? [];
    return GestureDetector(
      onTap: () => ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('专栏详情暂未实现')),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (images.isNotEmpty)
            Row(
              children: [
                for (final img in images.take(3))
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: NetImage(
                      url: img.toString(),
                      width: 100,
                      height: 60,
                      radius: BorderRadius.circular(6),
                    ),
                  ),
              ],
            ),
          const SizedBox(height: 6),
          Text(
            content['title']?.toString() ?? '',
            style: TextStyle(
              color: isOwner
                  ? theme.colorScheme.onSecondaryContainer
                  : theme.colorScheme.onSurface,
              fontWeight: FontWeight.bold,
              height: 1.4,
            ),
          ),
          if ((content['summary'] as String?)?.isNotEmpty == true)
            Text(
              content['summary'].toString(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: (isOwner
                        ? theme.colorScheme.onSecondaryContainer
                        : theme.colorScheme.onSurface)
                    .withValues(alpha: 0.6),
                fontSize: 12,
                height: 1.4,
              ),
            ),
        ],
      ),
    );
  }

  // ---------- 通用分享卡片（直播等） ----------
  Widget _commonShareCard(
      BuildContext context, ThemeData theme, Map<String, dynamic> content) {
    if (content['source'] == '直播') {
      return GestureDetector(
        onTap: () => ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('直播间暂未实现')),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            NetImage(
              url: content['cover']?.toString() ?? '',
              width: 220,
              height: 123.75,
              radius: BorderRadius.circular(8),
            ),
            const SizedBox(height: 6),
            Text(
              content['title']?.toString() ?? '',
              style: TextStyle(
                color: isOwner
                    ? theme.colorScheme.onSecondaryContainer
                    : theme.colorScheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '${content['author']} · 直播',
              style: TextStyle(
                color: (isOwner
                        ? theme.colorScheme.onSecondaryContainer
                        : theme.colorScheme.onSurface)
                    .withValues(alpha: 0.6),
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }
    return _fallback(theme, content);
  }

  // ---------- 通知消息 ----------
  Widget _notifyMsg(ThemeData theme, Map<String, dynamic> content) {
    final modules = content['modules'] as List<dynamic>? ?? [];
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              content['title']?.toString() ?? '',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const Divider(height: 12),
            if ((content['text'] as String?)?.isNotEmpty == true)
              Text(content['text'].toString()),
            for (final m in modules.whereType<Map<String, dynamic>>())
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 80,
                      child: Text(
                        m['title']?.toString() ?? '',
                        style: TextStyle(color: theme.colorScheme.outline),
                      ),
                    ),
                    Expanded(child: Text(m['detail']?.toString() ?? '')),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ---------- 图片卡片（大宽图） ----------
  Widget _pictureCard(Map<String, dynamic> content) {
    return Align(
      alignment: Alignment.topCenter,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: NetImage(
          url: content['pic_url']?.toString() ?? '',
          width: 400,
          height: 200,
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  // ---------- 推荐卡片 ----------
  Widget _recommendCard(
      BuildContext context, ThemeData theme, Map<String, dynamic> content) {
    final subCards = content['sub_cards'] as List<dynamic>? ?? [];
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              content['main_title']?.toString() ?? '',
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            for (final sc in subCards.whereType<Map<String, dynamic>>())
              GestureDetector(
                onTap: () {
                  final jumpUrl = sc['jump_url']?.toString() ?? '';
                  final bvid = RegExp(r'BV[0-9A-Za-z]+').firstMatch(jumpUrl)?.group(0);
                  if (bvid != null) _openVideo(context, bvid);
                },
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      NetImage(
                        url: sc['cover_url']?.toString() ?? '',
                        width: 120,
                        height: 67.5,
                        radius: BorderRadius.circular(6),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              sc['field1']?.toString() ?? '',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: theme.colorScheme.onSurface,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              sc['field2']?.toString() ?? '',
                              style: TextStyle(
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.6),
                                fontSize: 11,
                              ),
                            ),
                            Text(
                              sc['field3']?.toString() ?? '',
                              style: TextStyle(
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.6),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ---------- 系统提示 ----------
  Widget _tipMessage(ThemeData theme, Map<String, dynamic> content) {
    // content.content 可能是双重 JSON 编码的数组
    var text = '';
    try {
      final raw = content['content'];
      if (raw is String) {
        final arr = jsonDecode(raw);
        text = arr is List ? _joinTipItems(arr) : raw;
      } else if (raw is List) {
        text = _joinTipItems(raw);
      }
    } catch (_) {
      text = content['content']?.toString() ?? '';
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 24),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: theme.colorScheme.outline.withValues(alpha: 0.8),
          fontSize: 12,
          height: 1.5,
        ),
      ),
    );
  }

  static String _joinTipItems(List<dynamic> arr) => arr
      .whereType<Map<String, dynamic>>()
      .map((e) => e['text']?.toString() ?? '')
      .join('\n');

  // ---------- 兜底 ----------
  Widget _fallback(ThemeData theme, Map<String, dynamic> content) {
    return Text(
      msg.content.isEmpty ? '[未知消息类型 ${msg.msgType}]' : msg.text,
      style: TextStyle(
        color: isOwner
            ? theme.colorScheme.onSecondaryContainer
            : theme.colorScheme.onSurface,
      ),
    );
  }

  // ---------- 工具 ----------
  void _openVideo(BuildContext context, String? bvid) {
    if (bvid == null || bvid.isEmpty) return;
    Navigator.pushNamed(context, '/video', arguments: bvid);
  }

  static String _formatDuration(int seconds) {
    if (seconds <= 0) return '--:--';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}