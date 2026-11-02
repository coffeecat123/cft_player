// views/widgets/danmu_settings_panel.dart

import 'package:flutter/material.dart';
import '../../controllers/danmu_controller.dart';

class DanmuSettingsPanel extends StatelessWidget {
  final DanmuController danmuCtrl;
  final VoidCallback onClose;
  final VoidCallback? onInteraction; // 💥 新增：任何設定變動時的通知回呼

  const DanmuSettingsPanel({
    super.key,
    required this.danmuCtrl,
    required this.onClose,
    this.onInteraction, // 💥
  });

  void _handle(VoidCallback action) {
    action();
    onInteraction?.call(); // 💥 觸發重設計時器
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: danmuCtrl,
      builder: (context, _) {
        return Container(
          width: 300,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xEE1E1E1E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white12),
            boxShadow: const [
              BoxShadow(
                color: Colors.black54,
                blurRadius: 16,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 標題列
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Danmaku Settings",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                    onPressed: onClose,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const Divider(color: Colors.white24, height: 16),

              // 1. 速度 (0.5x ~ 3.0x)
              _buildSettingRow(
                label: "Speed",
                valueDisplay: "${danmuCtrl.danmuSpeed.toStringAsFixed(1)}x",
                slider: Slider(
                  value: danmuCtrl.danmuSpeed,
                  min: 0.5,
                  max: 3.0,
                  divisions: 25,
                  onChanged: (v) => _handle(() => danmuCtrl.setSpeed(v)),
                ),
              ),

              // 2. 字體大小 (12px ~ 36px)
              _buildSettingRow(
                label: "Size",
                valueDisplay: "${danmuCtrl.danmuSize.toInt()}px",
                slider: Slider(
                  value: danmuCtrl.danmuSize,
                  min: 12.0,
                  max: 36.0,
                  divisions: 12,
                  onChanged: (v) => _handle(() => danmuCtrl.setSize(v)),
                ),
              ),

              // 3. 不透明度 (10% ~ 100%)
              _buildSettingRow(
                label: "Opacity",
                valueDisplay: "${(danmuCtrl.opacity * 100).toInt()}%",
                slider: Slider(
                  value: danmuCtrl.opacity,
                  min: 0.1,
                  max: 1.0,
                  divisions: 18,
                  onChanged: (v) => _handle(() => danmuCtrl.setOpacity(v)),
                ),
              ),

              // 4. 顯示範圍 (10% ~ 100%)
              _buildSettingRow(
                label: "Range",
                valueDisplay: "${(danmuCtrl.danmuRange * 100).toInt()}%",
                slider: Slider(
                  value: danmuCtrl.danmuRange,
                  min: 0.1,
                  max: 1.0,
                  divisions: 18,
                  onChanged: (v) => _handle(() => danmuCtrl.setRange(v)),
                ),
              ),

              // 5. 同屏上限 (5 ~ 200)
              _buildSettingRow(
                label: "Limit",
                valueDisplay: "${danmuCtrl.danmuLimit}",
                slider: Slider(
                  value: danmuCtrl.danmuLimit.toDouble(),
                  min: 5.0,
                  max: 200.0,
                  divisions: 39,
                  onChanged: (v) => _handle(() => danmuCtrl.setLimit(v.toInt())),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSettingRow({
    required String label,
    required String valueDisplay,
    required Widget slider,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: const SliderThemeData(
                trackHeight: 3,
                thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: RoundSliderOverlayShape(overlayRadius: 12),
                activeTrackColor: Colors.white,
                inactiveTrackColor: Colors.white24,
                thumbColor: Colors.white,
              ),
              child: slider,
            ),
          ),
          SizedBox(
            width: 44,
            child: Text(
              valueDisplay,
              textAlign: TextAlign.end,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}