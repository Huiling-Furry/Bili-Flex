import 'package:flutter/material.dart';
import '../data/models/video.dart';
import '../core/utils/formatters.dart';
import 'net_image.dart';

/// 视频卡片（推荐流/搜索结果通用）。
class VideoCard extends StatelessWidget {
  final VideoItem item;
  final VoidCallback? onTap;

  const VideoCard({super.key, required this.item, this.onTap});

  @override
  Widget build(BuildContext context) {
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
                NetImage(
                  url: item.cover,
                  radius: BorderRadius.circular(8),
                ),
                Positioned(
                  right: 6,
                  bottom: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
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
                Positioned(
                  left: 6,
                  bottom: 6,
                  child: Row(
                    children: [
                      const Icon(Icons.play_arrow, size: 12, color: Colors.white),
                      Text(
                        Formatters.count(item.playCount),
                        style: const TextStyle(color: Colors.white, fontSize: 10),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.subtitles_outlined, size: 12, color: Colors.white),
                      Text(
                        Formatters.count(item.danmakuCount),
                        style: const TextStyle(color: Colors.white, fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            item.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, height: 1.35),
          ),
          const SizedBox(height: 2),
          Text(
            item.author,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
