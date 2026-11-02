// views/widgets/controls_overlay.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:window_manager/window_manager.dart';

import '../../controllers/player_controller.dart';
import '../../controllers/danmu_controller.dart';
import 'custom_seekbar.dart';

class ControlsOverlay extends StatelessWidget {
  final PlayerController playerCtrl;
  final DanmuController danmuCtrl;
  final bool isSidebarOpen;
  final VoidCallback onToggleSidebar;
  final VoidCallback onToggleDanmuSettings;
  final VoidCallback? onInteraction;

  const ControlsOverlay({
    super.key,
    required this.playerCtrl,
    required this.danmuCtrl,
    required this.isSidebarOpen,
    required this.onToggleSidebar,
    required this.onToggleDanmuSettings,
    this.onInteraction,
  });

  String _format(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? "$h:$m:$s" : "$m:$s";
  }

  bool get _isDesktop {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux;
  }

  @override
  Widget build(BuildContext context) {
    // 💥 統一的圓形深灰半透明按鈕樣式 (對齊 toggleSidebar)
    final circularBtnStyle = IconButton.styleFrom(
      backgroundColor: const Color(0xFF323232),
      shape: const CircleBorder(),
      padding: const EdgeInsets.all(8),
    );

    return ListenableBuilder(
      listenable: Listenable.merge([playerCtrl, danmuCtrl]),
      builder: (context, _) {
        final player = playerCtrl.player;

        Widget topBarContent = Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black87, Colors.transparent],
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  playerCtrl.currentVideo?.displayName ?? "Select a video to play",
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                tooltip: "Playlist (J)",
                style: circularBtnStyle,
                icon: AnimatedRotation(
                  turns: isSidebarOpen ? 0.5 : 0.0,
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  child: SvgPicture.asset(
                    'assets/icons/toggle_sidebar.svg',
                    width: 32,
                    height: 32,
                    colorFilter: const ColorFilter.mode(
                      Colors.white,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
                onPressed: onToggleSidebar,
              ),
            ],
          ),
        );

        return Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // ================= Top Bar =================
            _isDesktop ? DragToMoveArea(child: topBarContent) : topBarContent,

            // ================= Bottom Bar =================
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black87, Colors.transparent],
                ),
              ),
              child: StreamBuilder<Duration>(
                stream: player.stream.position,
                builder: (context, snapshot) {
                  final pos = snapshot.data ?? player.state.position;
                  final dur = player.state.duration;

                  return Column(
                    children: [
                      // 進度條
                      CustomSeekBar(
                        position: pos,
                        duration: dur,
                        danmus: danmuCtrl.allDanmus,
                        onSeek: (target) => player.seek(target),
                      ),
                      Row(
                        children: [
                          // 💥 1. 播放 / 暫停按鈕 (帶圓形底色)
                          IconButton(
                            tooltip: player.state.playing
                                ? "Pause (Space)"
                                : "Play (Space)",
                            style: circularBtnStyle,
                            icon: Icon(
                              player.state.playing
                                  ? Icons.pause
                                  : Icons.play_arrow,
                              color: Colors.white,
                              size: 28,
                            ),
                            onPressed: () => player.playOrPause(),
                          ),

                          const SizedBox(width: 16),

                          // 💥 2. 播放倍速選單 (固定寬度 56px 膠囊造型，字數變動絕不抖動！)
                          _SpeedMenu(player: player),

                          const SizedBox(width: 16),

                          // 💥 3. 彈幕開關按鈕 (帶圓形底色)
                          IconButton(
                            tooltip: danmuCtrl.isDanmuEnabled
                                ? "Hide danmaku (D)"
                                : "Show danmaku (D)",
                            style: circularBtnStyle,
                            icon: SvgPicture.asset(
                              danmuCtrl.isDanmuEnabled
                                  ? 'assets/icons/danmu_on.svg'
                                  : 'assets/icons/danmu_off.svg',
                              width: 28,
                              height: 28,
                              colorFilter: danmuCtrl.isDanmuEnabled
                                  ? null
                                  : const ColorFilter.mode(
                                      Colors.white70,
                                      BlendMode.srcIn,
                                    ),
                            ),
                            onPressed: danmuCtrl.toggleDanmu,
                          ),

                          const SizedBox(width: 16),

                          // 💥 4. 彈幕設定按鈕 (帶圓形底色)
                          IconButton(
                            tooltip: "Danmaku Settings",
                            style: circularBtnStyle,
                            icon: SvgPicture.asset(
                              'assets/icons/danmu_settings.svg',
                              width: 28,
                              height: 28,
                              colorFilter: const ColorFilter.mode(
                                Colors.white,
                                BlendMode.srcIn,
                              ),
                            ),
                            onPressed: onToggleDanmuSettings,
                          ),

                          const SizedBox(width: 16),

                          // 💥 5. 音量控制區塊 (帶圓形底色 + 展開滑桿)
                          _VolumeControl(
                            player: player,
                            onInteraction: onInteraction,
                            buttonStyle: circularBtnStyle,
                          ),

                          const Spacer(),

                          // 6. 實時時間更新 (00:00 / 03:45)
                          Text(
                            "${_format(pos)} / ${_format(dur)}",
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white70,
                            ),
                          ),

                          const SizedBox(width: 16),

                          // 💥 7. 全螢幕切換按鈕 (帶圓形底色)
                          IconButton(
                            tooltip: playerCtrl.isFullScreen
                                ? "Exit full screen (F)"
                                : "Full screen (F)",
                            style: circularBtnStyle,
                            icon: SvgPicture.asset(
                              playerCtrl.isFullScreen
                                  ? 'assets/icons/fullscreen_exit.svg'
                                  : 'assets/icons/fullscreen_enter.svg',
                              width: 28,
                              height: 28,
                              colorFilter: const ColorFilter.mode(
                                Colors.white,
                                BlendMode.srcIn,
                              ),
                            ),
                            onPressed: playerCtrl.toggleFullScreen,
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

// ================= 💥 音量控制組件 =================
class _VolumeControl extends StatefulWidget {
  final dynamic player;
  final VoidCallback? onInteraction;
  final ButtonStyle buttonStyle;

  const _VolumeControl({
    required this.player,
    this.onInteraction,
    required this.buttonStyle,
  });

  @override
  State<_VolumeControl> createState() => _VolumeControlState();
}

class _VolumeControlState extends State<_VolumeControl> {
  bool _isHovered = false;
  double _lastVolume = 100.0;

  String _getVolumeIcon(double volume) {
    if (volume <= 0) return 'assets/icons/volume_mute.svg';
    if (volume < 50) return 'assets/icons/volume_mid.svg';
    return 'assets/icons/volume_max.svg';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<double>(
      stream: widget.player.stream.volume,
      initialData: widget.player.state.volume,
      builder: (context, snapshot) {
        final volume = (snapshot.data ?? 100.0).clamp(0.0, 100.0);

        return MouseRegion(
          onEnter: (_) {
            setState(() => _isHovered = true);
            widget.onInteraction?.call();
          },
          onHover: (_) => widget.onInteraction?.call(),
          onExit: (_) => setState(() => _isHovered = false),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 💥 帶統一圓形背景的喇叭按鈕
              IconButton(
                tooltip: volume <= 0 ? "Unmute (M)" : "Mute (M)",
                style: widget.buttonStyle,
                icon: SvgPicture.asset(
                  _getVolumeIcon(volume),
                  width: 28,
                  height: 28,
                  colorFilter: const ColorFilter.mode(
                    Colors.white,
                    BlendMode.srcIn,
                  ),
                ),
                onPressed: () {
                  widget.onInteraction?.call();
                  if (volume > 0) {
                    _lastVolume = volume;
                    widget.player.setVolume(0.0);
                  } else {
                    widget.player.setVolume(
                      _lastVolume > 0 ? _lastVolume : 100.0,
                    );
                  }
                },
              ),

              // 展開滑桿
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: _isHovered ? 80 : 0,
                child: ClipRect(
                  child: SliderTheme(
                    data: const SliderThemeData(
                      trackHeight: 3,
                      thumbShape: RoundSliderThumbShape(enabledThumbRadius: 5),
                      overlayShape: RoundSliderOverlayShape(overlayRadius: 10),
                      activeTrackColor: Colors.white,
                      inactiveTrackColor: Colors.white24,
                      thumbColor: Colors.white,
                    ),
                    child: Slider(
                      value: volume,
                      min: 0.0,
                      max: 100.0,
                      onChangeStart: (_) => widget.onInteraction?.call(),
                      onChanged: (val) {
                        widget.player.setVolume(val);
                        widget.onInteraction?.call();
                      },
                    ),
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

// ================= 💥 倍速選單組件 (固定寬度防抖動) =================
class _SpeedMenu extends StatelessWidget {
  final dynamic player;

  const _SpeedMenu({required this.player});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<double>(
      stream: player.stream.rate,
      initialData: player.state.rate,
      builder: (context, snapshot) {
        final currentRate = snapshot.data ?? 1.0;
        final speedText =
            "${currentRate.toStringAsFixed(currentRate % 1 == 0 ? 1 : 2)}x";

        return PopupMenuButton<double>(
          tooltip: "Playback Speed",
          initialValue: currentRate,
          color: const Color(0xEE222222),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: Colors.white12),
          ),
          onSelected: (rate) => player.setRate(rate),
          itemBuilder: (context) =>
              [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 3.0].map((rate) {
                final isSelected = (rate - currentRate).abs() < 0.01;
                return PopupMenuItem<double>(
                  value: rate,
                  height: 36,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "${rate}x",
                        style: TextStyle(
                          color: isSelected ? Colors.redAccent : Colors.white,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      if (isSelected)
                        const Icon(
                          Icons.check,
                          color: Colors.redAccent,
                          size: 16,
                        ),
                    ],
                  ),
                );
              }).toList(),
          // 💥 核心修正：固定寬度 56px 膠囊造型，統一深色背景，字數變動絕不抖動！
          child: Container(
            width: 56, // 👈 固定寬度，徹底杜絕 1.0x 變成 0.75x 時的版面跳動！
            height: 40, // 👈 高度對齊圓形按鈕直徑
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFF323232), // 👈 與按鈕相同的深灰半透明背景
              borderRadius: BorderRadius.circular(10), // 👈 圓角膠囊造形
            ),
            child: Text(
              speedText,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      },
    );
  }
}