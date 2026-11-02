// painters/danmu_painter.dart

import 'package:flutter/material.dart';
import '../controllers/danmu_controller.dart';

class DanmuPainter extends CustomPainter {
  final DanmuController controller;

  DanmuPainter({required this.controller}) : super(repaint: controller.repaintNotifier);

  @override
  void paint(Canvas canvas, Size size) {
    // 💥 核心修正：彈幕關閉時，畫面上立刻隱藏消失！
    if (!controller.isDanmuEnabled || controller.activeDanmus.isEmpty) return;

    final needLayer = controller.opacity < 1.0;
    if (needLayer) {
      canvas.saveLayer(
        null,
        Paint()..color = Colors.white.withValues(alpha: controller.opacity),
      );
    }

    for (var d in controller.activeDanmus) {
      if (d.y == null || d.painter == null) continue;
      d.painter!.paint(canvas, Offset(d.x, d.y!));
    }

    if (needLayer) {
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant DanmuPainter oldDelegate) => true;
}