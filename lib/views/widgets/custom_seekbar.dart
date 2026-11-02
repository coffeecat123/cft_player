// views/widgets/custom_seekbar.dart

import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/danmu_item.dart';
import '../../painters/waveform_painter.dart';

class CustomSeekBar extends StatefulWidget {
  final Duration position;
  final Duration duration;
  final List<DanmuItem> danmus;
  final ValueChanged<Duration> onSeek;

  const CustomSeekBar({
    super.key,
    required this.position,
    required this.duration,
    required this.danmus,
    required this.onSeek,
  });

  @override
  State<CustomSeekBar> createState() => _CustomSeekBarState();
}

class _CustomSeekBarState extends State<CustomSeekBar> {
  // 記錄使用者拖動中的毫秒數
  double? _dragValue;

  // 💥 需求 1：拖動時的實時節流計時器 (類似 setTimeout)
  Timer? _throttleTimer;
  Duration? _pendingSeekTime;

  @override
  void dispose() {
    _throttleTimer?.cancel();
    super.dispose();
  }

  void _onDragging(double val) {
    setState(() => _dragValue = val);
    _pendingSeekTime = Duration(milliseconds: val.toInt());

    // 💥 類似 setTimeout 節流機制：
    // 每 60ms 內只會向播放器發送一次 seek 請求，既能實時預覽畫面，又絕對不卡死！
    if (_throttleTimer == null || !_throttleTimer!.isActive) {
      _throttleTimer = Timer(const Duration(milliseconds: 60), () {
        if (_pendingSeekTime != null && mounted) {
          widget.onSeek(_pendingSeekTime!);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxMs = widget.duration.inMilliseconds.toDouble() > 0
        ? widget.duration.inMilliseconds.toDouble()
        : 1.0;

    final currentMs =
        _dragValue ??
        widget.position.inMilliseconds
            .clamp(0, widget.duration.inMilliseconds)
            .toDouble();

    final safeValue = currentMs.clamp(0.0, maxMs);

    return SizedBox(
      // 💥 1. 容器高度直接從 56 壓扁到 24！一口氣減少 20px 以上的巨大間距！
      height: 36,
      child: Stack(
        // 💥 2. 關鍵：允許山峰向上衝出容器，高度絕不被裁切！
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          // 💥 3. top 設為負數（-24），山峰向上生長，底部完美貼齊進度條
          Positioned(
            top: -26,
            bottom: 21,
            left: 14,
            right: 14,
            child: CustomPaint(
              painter: WaveformPainter(
                danmus: widget.danmus,
                duration: widget.duration.inSeconds.toDouble(),
                maxWaveHeight: 34.0, // 山峰高度完全不受影響，依然高聳！
              ),
            ),
          ),

          // 4. 進度條本體 (現在緊緊貼在底部)
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 6,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              activeTrackColor: Colors.redAccent,
              inactiveTrackColor: Colors.white24,
              thumbColor: Colors.redAccent,
            ),
            child: Slider(
              value: safeValue,
              max: maxMs,
              onChangeStart: (val) {
                setState(() => _dragValue = val);
              },
              onChanged: _onDragging,
              onChangeEnd: (val) {
                _throttleTimer?.cancel();
                _throttleTimer = null;
                widget.onSeek(Duration(milliseconds: val.toInt()));
                setState(() => _dragValue = null);
              },
            ),
          ),
        ],
      ),
    );
  }
}
