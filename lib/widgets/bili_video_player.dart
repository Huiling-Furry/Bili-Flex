import 'dart:async';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../data/models/danmaku.dart';
import '../data/models/video.dart';

/// 倍速选项。
const _playbackRates = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

/// 快进/快退秒数。
const _skipSeconds = 10;

/// 控制栏自动隐藏延迟。
const _controlsHideDelay = Duration(seconds: 3);

/// 滚动弹幕从右到左的总时长（秒）。
const _danmakuScrollDuration = 8.0;

/// 弹幕字号。
const _danmakuFontSize = 25.0;

/// 弹幕行高（字号 + 行间距），用于按高度计算轨道数。
const _danmakuLineHeight = _danmakuFontSize + 6;

/// 顶部/底部弹幕停留时长（秒）。
const _danmakuStaticSeconds = 5.0;

/// BiliFlex 视频播放器（基于 media_kit / libmpv）。
///
/// 功能：播放/暂停、进度条滑动、倍速、画质切换、快进快退（按钮 + 双击左/右半屏）、
/// 弹幕叠加显示/隐藏、控制栏 3 秒无操作自动隐藏。
class BiliVideoPlayer extends StatefulWidget {
  /// 播放源。DASH 音视频分离时会带上外挂音轨。
  final PlaybackSource? source;

  /// 弹幕列表（来自 [VideoRepo.danmaku]，protobuf 分段解析）。
  final List<DanmakuItem> danmaku;

  /// 播放进度，供外部（弹幕列表）做时间轴同步与跳转。
  final ValueNotifier<Duration>? positionNotifier;

  /// 可选画质。
  final List<QualityOption> qualities;

  /// 当前画质 qn。
  final int currentQn;

  /// 画质切换回调，返回新的播放源。
  final Future<PlaybackSource?> Function(int qn)? onQualityChange;

  final double aspectRatio;

  const BiliVideoPlayer({
    super.key,
    required this.source,
    this.danmaku = const [],
    this.positionNotifier,
    this.qualities = const [],
    this.currentQn = 80,
    this.onQualityChange,
    this.aspectRatio = 16 / 9,
  });

  @override
  State<BiliVideoPlayer> createState() => _BiliVideoPlayerState();
}

class _BiliVideoPlayerState extends State<BiliVideoPlayer> {
  late final Player _player = Player();
  late final VideoController _controller = VideoController(_player);

  // 播放状态（用 ValueNotifier 局部刷新，避免整屏 rebuild）
  final ValueNotifier<Duration> _internalPos = ValueNotifier(Duration.zero);
  final ValueNotifier<Duration> _duration = ValueNotifier(Duration.zero);
  final ValueNotifier<bool> _playing = ValueNotifier(false);
  final ValueNotifier<double> _rate = ValueNotifier(1.0);
  final ValueNotifier<int> _danmakuTick = ValueNotifier(0);

  ValueNotifier<Duration> get _pos => widget.positionNotifier ?? _internalPos;

  bool _isSeeking = false;
  bool _controlsVisible = true;
  Timer? _hideTimer;
  double? _doubleTapX;

  // 弹幕
  List<DanmakuItem> _danmaku = const [];
  final List<_ActiveDanmaku> _active = [];
  bool _danmakuEnabled = true;
  Timer? _danmakuTimer;
  int _danmakuIndex = 0;
  int _topSeq = 0;
  int _bottomSeq = 0;
  final List<int> _trackEndMs = [];

  Size _size = Size.zero;

  String? _error;
  bool _buffering = true;
  Duration? _resumeAfterReload;

  StreamSubscription<Duration>? _posSub;
  StreamSubscription<Duration>? _durSub;
  StreamSubscription<bool>? _playingSub;
  StreamSubscription<double>? _rateSub;
  StreamSubscription<bool>? _bufferSub;
  StreamSubscription<String>? _errSub;
  StreamSubscription<bool>? _completedSub;

  @override
  void initState() {
    super.initState();
    _applyDanmaku(widget.danmaku);

    _posSub = _player.stream.position.listen((p) {
      if (!_isSeeking) _pos.value = p;
    });
    _durSub = _player.stream.duration.listen((d) => _duration.value = d);
    _playingSub = _player.stream.playing.listen((p) => _playing.value = p);
    _rateSub = _player.stream.rate.listen((r) => _rate.value = r);
    _bufferSub = _player.stream.buffering.listen((b) {
      if (mounted) setState(() => _buffering = b);
    });
    _errSub = _player.stream.error.listen((e) {
      if (mounted) setState(() => _error = e);
    });
    _completedSub = _player.stream.completed.listen((_) {
      _playing.value = false;
    });

    _open();
    _startDanmakuTimer();
    _showControls();
  }

  @override
  void didUpdateWidget(covariant BiliVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.danmaku, widget.danmaku)) {
      _applyDanmaku(widget.danmaku);
    }
    if (oldWidget.source?.videoUrl != widget.source?.videoUrl ||
        oldWidget.source?.audioUrl != widget.source?.audioUrl) {
      final resume = _resumeAfterReload ?? _pos.value;
      _resumeAfterReload = null;
      _open(resumeAt: resume);
    }
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _durSub?.cancel();
    _playingSub?.cancel();
    _rateSub?.cancel();
    _bufferSub?.cancel();
    _errSub?.cancel();
    _completedSub?.cancel();
    _hideTimer?.cancel();
    _danmakuTimer?.cancel();
    _internalPos.dispose();
    _duration.dispose();
    _playing.dispose();
    _rate.dispose();
    _danmakuTick.dispose();
    _player.dispose();
    super.dispose();
  }

  // ================= 播放 =================

  Future<void> _open({Duration? resumeAt}) async {
    final src = widget.source;
    if (src == null || !src.isPlayable) {
      if (mounted) setState(() => _buffering = false);
      return;
    }
    if (mounted) {
      setState(() {
        _error = null;
        _buffering = true;
      });
    }
    try {
      // DASH 音视频分离时，用 mpv 的 audio-file 属性外挂音轨。
      // 用 dynamic 调用，避免 Web 端因缺少该方法而编译失败。
      final platform = _player.platform;
      try {
        await (platform as dynamic).setProperty('audio-file', src.audioUrl ?? '');
      } catch (_) {}
      await _player.open(Media(src.videoUrl), play: _playing.value);
      if (resumeAt != null && resumeAt > Duration.zero) {
        await _player.seek(resumeAt);
      }
      _resetDanmaku(atMs: (resumeAt ?? Duration.zero).inMilliseconds);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  void _togglePlay() {
    if (_playing.value) {
      _player.pause();
    } else {
      _player.play();
    }
    _showControls();
  }

  void _seekRelative(int seconds) {
    final target = _pos.value + Duration(seconds: seconds);
    final clamped = target < Duration.zero
        ? Duration.zero
        : (target > _duration.value ? _duration.value : target);
    _player.seek(clamped);
    _showControls();
  }

  void _onSeekStart(double _) {
    setState(() => _isSeeking = true);
    _showControls();
  }

  void _onSeekChanged(double value) {
    _pos.value = Duration(milliseconds: value.toInt());
  }

  void _onSeekEnd(double value) {
    final target = Duration(milliseconds: value.toInt());
    _player.seek(target);
    setState(() => _isSeeking = false);
    _resetDanmaku(atMs: target.inMilliseconds);
  }

  void _setRate(double rate) {
    _player.setRate(rate);
    _showControls();
  }

  Future<void> _changeQuality(int qn) async {
    final cb = widget.onQualityChange;
    if (cb == null) return;
    // 记录进度，等父级更新 source 后由 didUpdateWidget 重新打开并回跳。
    _resumeAfterReload = _pos.value;
    _showControls();
    try {
      await cb(qn);
    } catch (e) {
      _resumeAfterReload = null;
      if (mounted) {
        setState(() => _error = '$e');
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('画质切换失败: $e')));
      }
    }
  }

  // ================= 控制栏 =================

  void _showControls() {
    if (mounted) setState(() => _controlsVisible = true);
    _hideTimer?.cancel();
    _hideTimer = Timer(_controlsHideDelay, () {
      if (mounted && _playing.value) {
        setState(() => _controlsVisible = false);
      }
    });
  }

  void _toggleControls() {
    if (_controlsVisible) {
      _hideTimer?.cancel();
      setState(() => _controlsVisible = false);
    } else {
      _showControls();
    }
  }

  void _onDoubleTap() {
    final dx = _doubleTapX ?? _size.width / 2;
    _seekRelative(dx < _size.width / 2 ? -_skipSeconds : _skipSeconds);
  }

  // ================= 弹幕 =================

  /// 顶部/底部固定弹幕。
  static bool _isStatic(DanmakuItem d) => d.mode == 4 || d.mode == 5;

  /// 逆向滚动弹幕（从左侧进入向右移动）。
  static bool _isReverse(DanmakuItem d) => d.mode == 6;

  /// 轨道数按播放器高度动态计算，让弹幕铺满整个画面。
  int get _trackCount {
    final h = _size.height;
    if (h <= 0) return 12;
    return (h / _danmakuLineHeight).floor().clamp(6, 40);
  }

  /// 顶部/底部弹幕各自可用的轨道数。
  int get _staticTrackCount => (_trackCount ~/ 2).clamp(2, 10);

  void _ensureTracks(int count) {
    if (_trackEndMs.length == count) return;
    _trackEndMs
      ..clear()
      ..addAll(List.filled(count, 0));
  }

  void _applyDanmaku(List<DanmakuItem> list) {
    _danmaku = [...list]..sort((a, b) => a.progressMs.compareTo(b.progressMs));
    _resetDanmaku();
  }

  void _startDanmakuTimer() {
    _danmakuTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (!mounted || !_danmakuEnabled || !_playing.value) return;
      _updateDanmaku();
    });
  }

  void _updateDanmaku() {
    if (_danmaku.isEmpty) return;
    final now = _pos.value.inMilliseconds;
    final width = _size.width <= 0 ? 320.0 : _size.width;
    _ensureTracks(_trackCount);

    // 加入新弹幕：3s 窗口保证即使掉帧/卡顿也不会漏掉弹幕
    while (_danmakuIndex < _danmaku.length) {
      final d = _danmaku[_danmakuIndex];
      if (d.progressMs > now) break;
      if (d.progressMs >= now - 3000) _addDanmaku(d, width);
      _danmakuIndex++;
    }

    // 位置直接由播放进度推算，保证与时间轴严格对齐、不因掉帧而漂移
    _active.removeWhere((a) {
      final elapsed = (now - a.item.progressMs) / 1000.0;
      final ratio = elapsed / _danmakuScrollDuration;
      if (!_isStatic(a.item)) {
        if (_isReverse(a.item)) {
          a.x = -a.width + (width + a.width) * ratio;
          return a.x > width;
        }
        a.x = width - (width + a.width) * ratio;
        return a.x < -a.width;
      }
      return elapsed > _danmakuStaticSeconds;
    });

    _danmakuTick.value++;
  }

  void _addDanmaku(DanmakuItem item, double screenWidth) {
    final text = item.displayText;
    if (text.isEmpty) return; // 无法解析的高级/代码弹幕直接跳过
    final width = _danmakuFontSize * text.length * 1.1 + 20;
    final count = _trackCount;
    _ensureTracks(count);

    int track;
    if (!_isStatic(item)) {
      // 选择最早空闲的轨道：所有轨道都占用时仍会显示（可能重叠，但不丢弃）
      track = 0;
      var earliest = _trackEndMs[0];
      for (var i = 1; i < count; i++) {
        if (_trackEndMs[i] < earliest) {
          earliest = _trackEndMs[i];
          track = i;
        }
      }
      // 该轨道被占满的时刻 = 本条弹幕尾部完全进入画面的时间
      _trackEndMs[track] =
          (_pos.value.inMilliseconds +
                  (width / (screenWidth + width)) *
                      _danmakuScrollDuration *
                      1000)
              .round();
    } else if (item.mode == 5) {
      track = _topSeq++ % _staticTrackCount;
    } else {
      track = _bottomSeq++ % _staticTrackCount;
    }

    _active.add(_ActiveDanmaku(
      item: item,
      x: _isReverse(item) ? -width : screenWidth,
      track: track,
      width: width,
    ));
  }

  void _resetDanmaku({int? atMs}) {
    final now = atMs ?? _pos.value.inMilliseconds;
    _active.clear();
    _trackEndMs.fillRange(0, _trackEndMs.length, 0);
    _topSeq = 0;
    _bottomSeq = 0;
    _danmakuIndex = 0;
    // 跳过当前时间之前的弹幕
    while (_danmakuIndex < _danmaku.length &&
        _danmaku[_danmakuIndex].progressMs < now) {
      _danmakuIndex++;
    }
    if (mounted) _danmakuTick.value++;
  }

  void _toggleDanmaku() {
    setState(() {
      _danmakuEnabled = !_danmakuEnabled;
      if (!_danmakuEnabled) _active.clear();
    });
    _showControls();
  }

  // ================= UI =================

  @override
  Widget build(BuildContext context) {
    final src = widget.source;
    final playable = src != null && src.isPlayable;
    return AspectRatio(
      aspectRatio: widget.aspectRatio,
      child: LayoutBuilder(
        builder: (context, constraints) {
          _size = Size(constraints.maxWidth, constraints.maxHeight);
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _toggleControls,
            onDoubleTapDown: (d) => _doubleTapX = d.localPosition.dx,
            onDoubleTap: _onDoubleTap,
            child: ColoredBox(
              color: Colors.black,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (playable)
                    Video(controller: _controller)
                  else
                    const Center(
                      child: Text('暂无播放地址',
                          style: TextStyle(color: Colors.white70, fontSize: 13)),
                    ),

                  // 弹幕层：单独用 ValueListenable 驱动，不重建视频
                  if (_danmakuEnabled && _danmaku.isNotEmpty)
                    ValueListenableBuilder<int>(
                      valueListenable: _danmakuTick,
                      builder: (_, _, _) => _buildDanmakuLayer(),
                    ),

                  if (playable && _buffering && _error == null)
                    const Center(
                      child: SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white),
                      ),
                    ),

                  if (_error != null) _errorView(),

                  AnimatedOpacity(
                    opacity: _controlsVisible ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: IgnorePointer(
                      ignoring: !_controlsVisible,
                      child: _buildControls(playable),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDanmakuLayer() {
    final height = _size.height <= 0 ? 180.0 : _size.height;
    final trackHeight = height / _trackCount;
    final children = <Widget>[];
    for (final a in _active) {
      final item = a.item;
      final text = Text(
        item.displayText,
        style: TextStyle(
          fontSize: _danmakuFontSize,
          color: Color(0xFF000000 | (item.color & 0xFFFFFF)),
          fontWeight: FontWeight.bold,
          shadows: const [
            Shadow(color: Colors.black54, offset: Offset(1, 1), blurRadius: 2),
          ],
        ),
      );
      if (!_isStatic(item)) {
        children.add(Positioned(
          left: a.x,
          top: a.track * trackHeight,
          child: text,
        ));
      } else if (item.mode == 5) {
        children.add(Positioned(
          top: a.track * trackHeight,
          left: 0,
          right: 0,
          child: Center(child: text),
        ));
      } else {
        children.add(Positioned(
          bottom: a.track * trackHeight + 4,
          left: 0,
          right: 0,
          child: Center(child: text),
        ));
      }
    }
    return IgnorePointer(child: ClipRect(child: Stack(children: children)));
  }

  Widget _errorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.white70, size: 32),
            const SizedBox(height: 8),
            Text(
              '播放失败\n$_error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControls(bool playable) {
    final src = widget.source;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black87],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (src != null && src.label.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 12, bottom: 4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(src.label,
                    style: const TextStyle(color: Colors.white, fontSize: 11)),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                ValueListenableBuilder<bool>(
                  valueListenable: _playing,
                  builder: (_, playing, _) => IconButton(
                    icon: Icon(
                      playing ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                      size: 28,
                    ),
                    onPressed: playable ? _togglePlay : null,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.replay_10, color: Colors.white),
                  onPressed: playable ? () => _seekRelative(-_skipSeconds) : null,
                ),
                IconButton(
                  icon: const Icon(Icons.forward_10, color: Colors.white),
                  onPressed: playable ? () => _seekRelative(_skipSeconds) : null,
                ),
                ValueListenableBuilder<Duration>(
                  valueListenable: _pos,
                  builder: (_, pos, _) => ValueListenableBuilder<Duration>(
                    valueListenable: _duration,
                    builder: (_, dur, _) => Text(
                      '${_formatDuration(pos)} / ${_formatDuration(dur)}',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(child: _buildSlider()),
                const SizedBox(width: 8),
                _buildRateButton(),
                if (widget.qualities.isNotEmpty) _buildQualityButton(),
                IconButton(
                  tooltip: _danmakuEnabled ? '关闭弹幕' : '显示弹幕',
                  icon: Icon(
                    _danmakuEnabled ? Icons.subtitles : Icons.subtitles_off,
                    color: _danmakuEnabled ? Colors.white : Colors.white54,
                  ),
                  onPressed: _toggleDanmaku,
                ),
              ],
            ),
          ),
          const SizedBox(height: 2),
        ],
      ),
    );
  }

  Widget _buildSlider() {
    return ValueListenableBuilder<Duration>(
      valueListenable: _pos,
      builder: (_, pos, _) => ValueListenableBuilder<Duration>(
        valueListenable: _duration,
        builder: (_, dur, _) {
          final maxMs =
              dur.inMilliseconds > 0 ? dur.inMilliseconds.toDouble() : 1.0;
          final value = pos.inMilliseconds.toDouble().clamp(0.0, maxMs);
          return SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              thumbShape:
                  const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape:
                  const RoundSliderOverlayShape(overlayRadius: 12),
            ),
            child: Slider(
              value: value,
              min: 0,
              max: maxMs,
              activeColor: Colors.white,
              inactiveColor: Colors.white30,
              onChangeStart: _onSeekStart,
              onChanged: _onSeekChanged,
              onChangeEnd: _onSeekEnd,
            ),
          );
        },
      ),
    );
  }

  Widget _buildRateButton() {
    return ValueListenableBuilder<double>(
      valueListenable: _rate,
      builder: (_, rate, _) => PopupMenuButton<double>(
        initialValue: rate,
        tooltip: '倍速',
        onSelected: _setRate,
        itemBuilder: (_) => _playbackRates
            .map((r) => PopupMenuItem(
                  value: r,
                  child: Text(
                    '${_trimRate(r)}x',
                    style: TextStyle(
                      fontWeight:
                          r == rate ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ))
            .toList(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            '${_trimRate(rate)}x',
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
        ),
      ),
    );
  }

  Widget _buildQualityButton() {
    return PopupMenuButton<int>(
      initialValue: widget.currentQn,
      tooltip: '画质',
      onSelected: _changeQuality,
      itemBuilder: (_) => widget.qualities
          .map((q) => PopupMenuItem(
                value: q.qn,
                child: Text(
                  q.label,
                  style: TextStyle(
                    fontWeight: q.qn == widget.currentQn
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ))
          .toList(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Text(
          QualityOption.fromQn(widget.currentQn).label,
          style: const TextStyle(color: Colors.white, fontSize: 13),
        ),
      ),
    );
  }

  static String _trimRate(double r) =>
      r == r.roundToDouble() ? r.toInt().toString() : '$r';

  static String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }
}

/// 当前活跃的弹幕（含运行时位置信息）。
class _ActiveDanmaku {
  final DanmakuItem item;
  double x;
  final int track;
  final double width;

  _ActiveDanmaku({
    required this.item,
    required this.x,
    required this.track,
    required this.width,
  });
}