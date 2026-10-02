import 'package:flutter/material.dart';
import '../data/models/library.dart';
import '../features/video/video_detail_page.dart';

/// 从列表条目跳转到视频详情（自动携带 cid 以定位分 P）。
void openVideo(BuildContext context, MediaItem item) {
  Navigator.of(context).pushNamed(
    '/video',
    arguments: VideoRouteArgs(
      bvid: item.bvid,
      aid: item.aid,
      cid: item.cid > 0 ? item.cid : null,
    ),
  );
}