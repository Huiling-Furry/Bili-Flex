import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../data/models/danmaku.dart';
import '../core/utils/formatters.dart';

/// 弹幕列表：按时间排序展示，并根据播放进度高亮当前弹幕。
class DanmakuList extends StatelessWidget {
  final List<DanmakuItem> items;
  final ValueListenable<Duration>? position;
  final double height;

  const DanmakuList({
    super.key,
    required this.items,
    this.position,
    this.height = 220,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return SizedBox(
        height: 80,
        child: Center(
          child: Text('本段暂无弹幕', style: TextStyle(color: Colors.grey.shade500)),
        ),
      );
    }
    final sorted = [...items]..sort((a, b) => a.progressMs.compareTo(b.progressMs));
    return SizedBox(
      height: height,
      child: position == null
          ? _buildList(context, sorted, Duration.zero)
          : ValueListenableBuilder<Duration>(
              valueListenable: position!,
              builder: (_, pos, _) => _buildList(context, sorted, pos),
            ),
    );
  }

  Widget _buildList(BuildContext context, List<DanmakuItem> sorted, Duration pos) {
    final currentMs = pos.inMilliseconds;
    return ListView.builder(
      itemCount: sorted.length,
      itemBuilder: (_, i) {
        final d = sorted[i];
        final active = (d.progressMs - currentMs).abs() <= 4000;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 52,
                child: Text(
                  Formatters.duration(d.progressMs ~/ 1000),
                  style: TextStyle(
                    fontSize: 11,
                    color: active
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey,
                    fontWeight: active ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  d.content,
                  style: TextStyle(
                    fontSize: 13,
                    color: active ? Colors.black87 : Colors.black54,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}