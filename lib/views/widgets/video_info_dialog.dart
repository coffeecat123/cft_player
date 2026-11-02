// views/widgets/video_info_dialog.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../controllers/player_controller.dart';

class VideoInfoDialog extends StatefulWidget {
  final PlayerController playerCtrl;
  final VoidCallback onClose;

  const VideoInfoDialog({
    super.key,
    required this.playerCtrl,
    required this.onClose,
  });

  @override
  State<VideoInfoDialog> createState() => _VideoInfoDialogState();
}

class _VideoInfoDialogState extends State<VideoInfoDialog> {
  String _fileSize = "Loading...";

  @override
  void initState() {
    super.initState();
    _loadFileSize();
  }

  void _loadFileSize() async {
    final cur = widget.playerCtrl.currentVideo;
    if (cur != null) {
      try {
        final bytes = await cur.videoFile.length();
        if (mounted) {
          setState(() => _fileSize = _formatSize(bytes));
        }
      } catch (_) {
        if (mounted) setState(() => _fileSize = "Unknown");
      }
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return "$bytes B";
    if (bytes < 1024 * 1024) return "${(bytes / 1024).toStringAsFixed(2)} KB";
    if (bytes < 1024 * 1024 * 1024) {
      return "${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB";
    }
    return "${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB";
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? "$h:$m:$s" : "$m:$s";
  }

  void _copyToClipboard(BuildContext context, String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Copied $label to clipboard!"),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final player = widget.playerCtrl.player;
    final cur = widget.playerCtrl.currentVideo;

    final name = cur?.name ?? "N/A";
    final path = cur?.videoFile.path ?? "N/A";
    final width = player.state.width ?? 0;
    final height = player.state.height ?? 0;
    final resolution = (width > 0 && height > 0) ? "${width} x $height" : "N/A";
    final duration = _formatDuration(player.state.duration);

    return Center(
      child: Container(
        width: 520,
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xEE222222),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white24, width: 1),
          boxShadow: const [
            BoxShadow(
              color: Colors.black87,
              blurRadius: 24,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 頂部標題與關閉按鈕
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.white, size: 22),
                    SizedBox(width: 8),
                    Text(
                      "Media Information",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70, size: 22),
                  onPressed: widget.onClose,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const Divider(color: Colors.white24, height: 24),

            // 資訊列表 (對齊 index.html 的 6 大項)
            _buildMetaRow("Name", name, () => _copyToClipboard(context, name, "Name")),
            _buildMetaRow("Path", path, () => _copyToClipboard(context, path, "Path")),
            _buildMetaRow("Resolution", resolution, () => _copyToClipboard(context, resolution, "Resolution")),
            _buildMetaRow("Size", _fileSize, () => _copyToClipboard(context, _fileSize, "Size")),
            _buildMetaRow("Duration", duration, () => _copyToClipboard(context, duration, "Duration")),
          ],
        ),
      ),
    );
  }

  Widget _buildMetaRow(String label, String value, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        hoverColor: Colors.white10,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 90,
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontFamily: 'monospace',
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.copy_rounded, color: Colors.white24, size: 24),
            ],
          ),
        ),
      ),
    );
  }
}