import 'package:flutter/material.dart';
import '../core/utils/formatters.dart';
import '../data/models/library.dart';
import 'net_image.dart';

/// 收藏夹 / 搜索结果用的网格卡片。
class MediaGridCard extends StatelessWidget {
  final MediaItem item;
  final VoidCallback? onTap;

  const MediaGridCard({super.key, required this.item, this.onTap});

  @override
  Widget build(BuildContext context) {
    final pct = item.duration > 0 && item.progress > 0
        ? (item.progress / item.duration).clamp(0.0, 1.0)
        : 0.0;
    return InkWell(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 10,
            child: Stack(
              fit: StackFit.expand,
              children: [
                NetImage(url: item.cover, radius: BorderRadius.circular(8)),
                Positioned(
                  right: 6,
                  bottom: 6,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      Formatters.duration(item.duration),
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                    ),
                  ),
                ),
                if (pct > 0)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 3,
                      backgroundColor: Colors.black38,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(item.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, height: 1.3)),
          const SizedBox(height: 2),
          Text('${item.author} · ${Formatters.count(item.playCount)}播放',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ),
    );
  }
}

/// 历史记录 / 稍后再看用的横向卡片。
class MediaListTile extends StatelessWidget {
  final MediaItem item;
  final VoidCallback? onTap;
  final List<Widget> actions;

  const MediaListTile({
    super.key,
    required this.item,
    this.onTap,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final pct = item.duration > 0 && item.progress > 0
        ? (item.progress / item.duration).clamp(0.0, 1.0)
        : 0.0;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 140,
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    NetImage(url: item.cover, radius: BorderRadius.circular(8)),
                    Positioned(
                      right: 6,
                      bottom: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          Formatters.duration(item.duration),
                          style: const TextStyle(
                              color: Colors.white, fontSize: 10),
                        ),
                      ),
                    ),
                    if (pct > 0)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: LinearProgressIndicator(
                            value: pct, minHeight: 3),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14)),
                  const SizedBox(height: 4),
                  Text(
                    '${item.author} · ${Formatters.timeAgo(item.favTime)}',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  if (item.progress > 0 && !item.isFinished)
                    Text('看到 ${Formatters.duration(item.progress)}',
                        style: const TextStyle(
                            fontSize: 11, color: Colors.grey)),
                ],
              ),
            ),
            ...actions,
          ],
        ),
      ),
    );
  }
}