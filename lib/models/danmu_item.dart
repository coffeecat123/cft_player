// models/danmu_item.dart

import 'package:flutter/material.dart';

class DanmuItem {
  final String text;
  final double time;
  final Color color;
  final double size;
  double? y;
  bool shown;

  double x = 0.0;
  double width = 0.0;
  TextPainter? painter;

  DanmuItem({
    required this.text,
    required this.time,
    required this.color,
    required this.size,
    this.y,
    this.shown = false,
  });

  // 💥 不再需要傳入 opacity，全部使用 100% 純色飽和度！
  void initPainter(double fontSize) {
    painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color, // 100% 原色，白就是純白，紅就是純紅
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          // 純黑俐落描邊
          shadows: const [
            Shadow(offset: Offset(0.5, 0.5), blurRadius: 0, color: Colors.black),
            Shadow(offset: Offset(-0.5, -0.5), blurRadius: 0, color: Colors.black),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    width = painter!.width;
  }
}