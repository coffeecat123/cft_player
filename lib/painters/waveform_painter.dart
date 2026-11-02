// painters/waveform_painter.dart

import 'dart:math';
import 'package:flutter/material.dart';
import '../models/danmu_item.dart';

class WaveformPainter extends CustomPainter {
  final List<DanmuItem> danmus;
  final double duration;
  final double maxWaveHeight; // 💥 新增：波形最高上限 (預設 44px)

  WaveformPainter({
    required this.danmus,
    required this.duration,
    this.maxWaveHeight = 44.0, // 可以在這裡隨時調整高度上限！
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (danmus.isEmpty || duration <= 0) return;

    final width = size.width.toInt();
    if (width <= 0) return;

    // 1. 基礎統計分桶
    final rawBins = List<double>.filled(width, 0.0);
    for (var d in danmus) {
      final binIndex = ((d.time / duration) * width).floor();
      if (binIndex >= 0 && binIndex < width) {
        rawBins[binIndex] += 1.0;
      }
    }

    // 2. 高斯平滑 (Gaussian Smoothing)
    const sigma = 6.0;
    final radius = (sigma * 3).ceil();
    final kernel = <double>[];
    double ksum = 0.0;
    for (int i = -radius; i <= radius; i++) {
      final v = exp(-(i * i) / (2 * sigma * sigma));
      kernel.add(v);
      ksum += v;
    }
    final norm = kernel.map((v) => v / ksum).toList();

    final smoothBins = List<double>.filled(width, 0.0);
    for (int i = 0; i < width; i++) {
      double sum = 0.0;
      for (int k = 0; k < norm.length; k++) {
        final j = i - radius + k;
        if (j >= 0 && j < width) {
          sum += rawBins[j] * norm[k];
        }
      }
      smoothBins[i] = sum;
    }

    final peakVal = smoothBins.reduce(max);
    if (peakVal == 0) return;

    // 💥 計算真實繪製高度：不超過畫布，也不超過自訂的 maxWaveHeight
    final actualMaxHeight = min(size.height - 2, maxWaveHeight);

    // 3. 連接折線
    final path = Path();
    path.moveTo(0, size.height);

    for (int i = 0; i < width - 1; i += 3) {
      final x = i.toDouble();
      // 根據密度比例計算高度，最高可達到 actualMaxHeight
      final currentHeight = (smoothBins[i] / peakVal) * actualMaxHeight;
      final y = size.height - currentHeight;
      path.lineTo(x, y);
    }

    // 4. 底部填滿
    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..close();

    final fillPaint = Paint()
      ..color = const Color(0x558A8A8A)
      ..style = PaintingStyle.fill;
    canvas.drawPath(fillPath, fillPaint);

    // 5. 頂部折線
    final strokePaint = Paint()
      ..color = const Color(0xFFBCBCBC)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant WaveformPainter oldDelegate) =>
      oldDelegate.danmus != danmus ||
      oldDelegate.duration != duration ||
      oldDelegate.maxWaveHeight != maxWaveHeight;
}