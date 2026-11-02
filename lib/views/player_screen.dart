// views/player_screen.dart

import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/foundation.dart'; 
import 'package:flutter_svg/flutter_svg.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:desktop_drop/desktop_drop.dart';

import '../controllers/player_controller.dart';
import '../controllers/danmu_controller.dart';
import '../services/danmu_parser.dart';
import '../painters/danmu_painter.dart';
import 'widgets/controls_overlay.dart';
import 'widgets/playlist_drawer.dart';
import 'widgets/danmu_settings_panel.dart';
import 'widgets/video_info_dialog.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen>
    with SingleTickerProviderStateMixin {
  final playerCtrl = PlayerController();
  final danmuCtrl = DanmuController();

  late final Ticker _ticker;
  final Stopwatch _stopwatch = Stopwatch();

  bool showControls = true;
  bool isSidebarOpen = false;
  bool isDanmuSettingsOpen = false;
  bool isVideoInfoOpen = false;
  Timer? hideControlsTimer;
  String? _lastVideoPath;

  Duration _lastElapsed = Duration.zero;
  double _lastPosSec = 0.0;
  // 1. 鍵盤防止重複觸發集合 (防 repeat)
  final Set<LogicalKeyboardKey> _downKeys = {};

  // 💥 2. 右方向鍵 3 倍速長按邏輯變數
  Timer? _arrowRightTimer;
  double? _prevPlaybackRate;

  // 3. 指針類型判斷 (區分 Mouse 或 Touch)
  PointerDeviceKind _lastPointerKind = PointerDeviceKind.mouse;

  // 4. 滑動快進 (Touch 專屬)
  double? dragStartX;
  Duration? dragStartTime;
  Duration? dragTargetTime;
  String skipDisplay = "";
 bool get _isTouchUser {
    // 1. 如果是 Android 或 iOS 手機，一律強制走「手機觸控手勢」！
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
         defaultTargetPlatform == TargetPlatform.iOS)) {
      return true;
    }
    // 2. 桌面端 (Windows) 只有在真正使用觸控螢幕時才走觸控手勢
    return _lastPointerKind == PointerDeviceKind.touch;
  }
  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? "$h:$m:$s" : "$m:$s";
  }

  @override
  void initState() {
    super.initState();

    // 💥 1. 預加載所有 SVG 圖示進記憶體快取，點擊按鈕 0 延遲，徹底告別「卡一下」！
    Future.microtask(() async {
      if (!mounted) return;

      const icons = [
        'assets/icons/danmu_on.svg',
        'assets/icons/danmu_off.svg',
        'assets/icons/danmu_settings.svg',
        'assets/icons/fullscreen_enter.svg',
        'assets/icons/fullscreen_exit.svg',
        'assets/icons/toggle_sidebar.svg',
        'assets/icons/volume_max.svg',
        'assets/icons/volume_mid.svg',
        'assets/icons/volume_mute.svg',
      ];

      // 💥 flutter_svg 2.x+ 最新官方預加載寫法：
      for (final iconPath in icons) {
        final loader = SvgAssetLoader(iconPath);
        await svg.cache.putIfAbsent(
          loader.cacheKey(null),
          () => loader.loadBytes(null),
        );
      }
    });

    playerCtrl.player.stream.position.listen((pos) {
      _stopwatch.reset();
      if (playerCtrl.player.state.playing) {
        _stopwatch.start();
      }
    });

    playerCtrl.player.stream.playing.listen((playing) {
      if (playing) {
        _stopwatch.start();
      } else {
        _stopwatch.stop();
      }
    });

    // 💥 2. 只要影片在播，Ticker 就持續運行，讓現有彈幕平滑飄完！
    _ticker = createTicker((elapsed) {
      if (playerCtrl.player.state.playing) {
        final rawDt = (elapsed - _lastElapsed).inMicroseconds / 1000000.0;
        final dt = rawDt.clamp(0.0, 0.05);
        _lastElapsed = elapsed;

        final currentSec =
            playerCtrl.player.state.position.inMilliseconds / 1000.0;

        if ((currentSec - _lastPosSec).abs() > 1.5) {
          danmuCtrl.onSeek(currentSec);
        }
        _lastPosSec = currentSec;

        danmuCtrl.tick(dt, currentSec);
      } else {
        _lastElapsed = elapsed;
      }
    });
    _ticker.start();

    playerCtrl.addListener(_onVideoChanged);
  }

  void _onVideoChanged() async {
    final cur = playerCtrl.currentVideo;
    if (cur == null) return;
    if (cur.videoFile.path == _lastVideoPath) return;
    _lastVideoPath = cur.videoFile.path;

    // 💥 核心修復：換影片的第一瞬間，立刻秒清空舊彈幕！
    danmuCtrl.clear();

    // 如果這部新影片有 XML 檔才去解析載入
    if (cur.xmlFile != null && mounted) {
      final danmus = await DanmuParser.parseXml(cur.xmlFile!);
      // 防禦：確認解析完時使用者沒有又切換到別部影片
      if (mounted &&
          playerCtrl.currentVideo?.videoFile.path == cur.videoFile.path) {
        danmuCtrl.init(
          danmus,
          Size(danmuCtrl.containerWidth, danmuCtrl.containerHeight),
        );
      }
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _stopwatch.stop();
    _arrowRightTimer?.cancel();
    playerCtrl.removeListener(_onVideoChanged);
    playerCtrl.dispose();
    danmuCtrl.dispose();
    hideControlsTimer?.cancel();
    super.dispose();
  }

  void resetHideTimer() {
    if (!showControls) {
      setState(() => showControls = true);
    }
    hideControlsTimer?.cancel();
    hideControlsTimer = Timer(const Duration(milliseconds: 2500), () {
      if (mounted && playerCtrl.player.state.playing) {
        setState(() {
          showControls = false;
          isDanmuSettingsOpen = false; // 💥 4. 控制列隱藏時，自動把彈幕面板一起收起！
        });
      }
    });
  }

  // 💥 鍵盤事件（精準處理短按 +5 秒與長按 3 倍速）
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      // 💥 改用 physicalKey 進行記錄與比對
      if (_downKeys.contains(event.logicalKey)) {
        return KeyEventResult.handled;
      }
      _downKeys.add(event.logicalKey);

      // 💥 核心魔法：使用 event.physicalKey（直接抓取實體按鍵，徹底免疫任何中文輸入法！）
      final pKey = event.physicalKey;

      // 1. 空白鍵 (Space)
      if (pKey == PhysicalKeyboardKey.space) {
        playerCtrl.player.playOrPause();
        return KeyEventResult.handled;
      }
      // 2. 全螢幕 (F)
      else if (pKey == PhysicalKeyboardKey.keyF) {
        playerCtrl.toggleFullScreen();
        return KeyEventResult.handled;
      }
      // 3. 彈幕開關 (D)
      else if (pKey == PhysicalKeyboardKey.keyD) {
        danmuCtrl.toggleDanmu();
        return KeyEventResult.handled;
      }
      // 4. 側邊欄 (J)
      else if (pKey == PhysicalKeyboardKey.keyJ) {
        setState(() => isSidebarOpen = !isSidebarOpen);
        return KeyEventResult.handled;
      }
      // 5. 影片資訊 (I)
      else if (pKey == PhysicalKeyboardKey.keyI) {
        setState(() => isVideoInfoOpen = !isVideoInfoOpen);
        return KeyEventResult.handled;
      }
      // 6. 靜音 (M)
      else if (pKey == PhysicalKeyboardKey.keyM) {
        final curVol = playerCtrl.player.state.volume;
        playerCtrl.player.setVolume(curVol > 0 ? 0.0 : 100.0);
        return KeyEventResult.handled;
      }
      // 7. 倍速調整 (Q / W / E / R)
      else if (pKey == PhysicalKeyboardKey.keyW) {
        final curRate = playerCtrl.player.state.rate;
        final newRate = (curRate - 0.1).clamp(0.1, 10.0);
        playerCtrl.player.setRate(double.parse(newRate.toStringAsFixed(2)));
        return KeyEventResult.handled;
      } else if (pKey == PhysicalKeyboardKey.keyE) {
        final curRate = playerCtrl.player.state.rate;
        final newRate = (curRate + 0.1).clamp(0.1, 10.0);
        playerCtrl.player.setRate(double.parse(newRate.toStringAsFixed(2)));
        return KeyEventResult.handled;
      } else if (pKey == PhysicalKeyboardKey.keyQ) {
        final curRate = playerCtrl.player.state.rate;
        final newRate = (curRate - 1.0).clamp(0.1, 10.0);
        playerCtrl.player.setRate(double.parse(newRate.toStringAsFixed(2)));
        return KeyEventResult.handled;
      } else if (pKey == PhysicalKeyboardKey.keyR) {
        final curRate = playerCtrl.player.state.rate;
        final newRate = (curRate + 1.0).clamp(0.1, 10.0);
        playerCtrl.player.setRate(double.parse(newRate.toStringAsFixed(2)));
        return KeyEventResult.handled;
      }
      // 8. 音量方向鍵 (↑ / ↓)
      else if (pKey == PhysicalKeyboardKey.arrowUp) {
        final curVol = playerCtrl.player.state.volume;
        playerCtrl.player.setVolume((curVol + 5.0).clamp(0.0, 100.0));
        return KeyEventResult.handled;
      } else if (pKey == PhysicalKeyboardKey.arrowDown) {
        final curVol = playerCtrl.player.state.volume;
        playerCtrl.player.setVolume((curVol - 5.0).clamp(0.0, 100.0));
        return KeyEventResult.handled;
      }
      // 9. 快進快退方向鍵 (← / →)
      else if (pKey == PhysicalKeyboardKey.arrowLeft) {
        playerCtrl.player.seek(
          playerCtrl.player.state.position - const Duration(seconds: 5),
        );
        return KeyEventResult.handled;
      } else if (pKey == PhysicalKeyboardKey.arrowRight) {
        if (!playerCtrl.player.state.playing) {
          playerCtrl.player.seek(
            playerCtrl.player.state.position + const Duration(seconds: 5),
          );
        } else {
          _arrowRightTimer?.cancel();
          _arrowRightTimer = Timer(const Duration(milliseconds: 200), () {
            _arrowRightTimer = null;
            _prevPlaybackRate = playerCtrl.player.state.rate;
            playerCtrl.player.setRate(3.0);
          });
        }
        return KeyEventResult.handled;
      }
      // 10. 上一首 / 下一首 ([ / ])
      else if (pKey == PhysicalKeyboardKey.bracketRight) {
        playerCtrl.playNext();
        return KeyEventResult.handled;
      } else if (pKey == PhysicalKeyboardKey.bracketLeft) {
        playerCtrl.playPrevious();
        return KeyEventResult.handled;
      }
    } else if (event is KeyUpEvent) {
      _downKeys.remove(event.logicalKey);

      if (event.physicalKey == PhysicalKeyboardKey.arrowRight) {
        if (_arrowRightTimer != null && _arrowRightTimer!.isActive) {
          _arrowRightTimer!.cancel();
          _arrowRightTimer = null;
          playerCtrl.player.seek(
            playerCtrl.player.state.position + const Duration(seconds: 5),
          );
        } else if (_prevPlaybackRate != null) {
          final original = _prevPlaybackRate!;
          _prevPlaybackRate = null;
          playerCtrl.player.setRate(original);
        }
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final drawerWidth = (MediaQuery.sizeOf(context).width * 0.3).clamp(
      360.0, // 👈 這裡就是 minWidth！
      520.0, // 👈 這裡就是 maxWidth！
    );

    return DropTarget(
      onDragDone: (details) {
        playerCtrl.addFiles(details.files);
      },
      child: Focus(
        autofocus: true,
        onKeyEvent: _handleKeyEvent,
        child: MouseRegion(
          cursor: showControls
              ? SystemMouseCursors.basic
              : SystemMouseCursors.none,
          onHover: (_) => resetHideTimer(),
          child: Scaffold(
            backgroundColor: Colors.black,
            body: Stack(
              children: [
                // ================= 1. 影片 + 彈幕 + 控制列舞台 (可被側欄擠壓縮回) =================
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  top: 0,
                  bottom: 0,
                  left: 0,
                  right: isSidebarOpen ? drawerWidth : 0, // 💥 側欄打開時，右邊自動內縮
                  child: Stack(
                    children: [
                      // 1.1 影片層
                      Center(
                        child: Video(
                          controller: playerCtrl.videoController,
                          controls: NoVideoControls,
                        ),
                      ),

                      // 1.2 彈幕層
                      Positioned.fill(
                        child: IgnorePointer(
                          child: ClipRect(
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                danmuCtrl.resize(constraints.biggest);
                                return CustomPaint(
                                  painter: DanmuPainter(controller: danmuCtrl),
                                );
                              },
                            ),
                          ),
                        ),
                      ),

                      // 1.3 手勢分流 (Mouse vs Touch)
                      Positioned.fill(
                        child: Listener(
                          onPointerDown: (e) => _lastPointerKind = e.kind,
                          child: GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            // 💥 1. 單擊點選：
                            onTap: () {
                              if (_isTouchUser) {
                                // 📱 手機：單擊只「切換顯示/隱藏控制列」，絕不暫停！
                                setState(() {
                                  showControls = !showControls;
                                  if (!showControls) isDanmuSettingsOpen = false;
                                });
                              } else {
                                // 💻 電腦滑鼠：單擊直接暫停/播放
                                playerCtrl.player.playOrPause();
                                resetHideTimer();
                              }
                            },
                            // 💥 2. 雙擊點選：
                            onDoubleTap: () {
                              if (_isTouchUser) {
                                // 📱 手機：雙擊才是「暫停 / 播放」！
                                playerCtrl.player.playOrPause();
                              } else {
                                // 💻 電腦滑鼠：雙擊快速切換全螢幕
                                //playerCtrl.toggleFullScreen();
                              }
                            },
                            // 💥 3. 滑動快進：只有觸控手機才允許滑動！
                            onHorizontalDragStart: (details) {
                              if (!_isTouchUser) return;
                              dragStartX = details.localPosition.dx;
                              dragStartTime = playerCtrl.player.state.position;
                            },
                            onHorizontalDragUpdate: (details) {
                              if (!_isTouchUser) return;
                              if (dragStartX == null || dragStartTime == null) return;

                              final deltaX = details.localPosition.dx - dragStartX!;
                              final offsetSec = (deltaX / 10).toInt();
                              final total = playerCtrl.player.state.duration;

                              var target = dragStartTime! + Duration(seconds: offsetSec);
                              if (target < Duration.zero) target = Duration.zero;
                              if (target > total) target = total;

                              dragTargetTime = target;

                              final sign = offsetSec >= 0 ? '+' : '-';
                              final absOffset = Duration(seconds: offsetSec.abs());
                              setState(() {
                                skipDisplay =
                                    "${_formatDuration(target)} / ${_formatDuration(total)}\n$sign${_formatDuration(absOffset)}";
                              });
                            },
                            onHorizontalDragEnd: (_) {
                              if (!_isTouchUser) return;
                              if (dragTargetTime != null) {
                                playerCtrl.player.seek(dragTargetTime!);
                              }
                              setState(() {
                                skipDisplay = "";
                                dragStartX = null;
                                dragStartTime = null;
                                dragTargetTime = null;
                              });
                            },
                          ),
                        ),
                      ),

                      // 1.4 跳轉提示 HUD
                      if (skipDisplay.isNotEmpty)
                        Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black87,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white12,
                                width: 1,
                              ),
                            ),
                            child: Text(
                              skipDisplay,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                height: 1.4,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),

                      // 1.5 控制層 (淡入淡出動畫)
                      AnimatedOpacity(
                        opacity: showControls ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 300),
                        child: IgnorePointer(
                          ignoring: !showControls,
                          child: ControlsOverlay(
                            playerCtrl: playerCtrl,
                            danmuCtrl: danmuCtrl,
                            isSidebarOpen: isSidebarOpen,
                            onToggleSidebar: () =>
                                setState(() => isSidebarOpen = !isSidebarOpen),
                            onToggleDanmuSettings: () => setState(
                              () => isDanmuSettingsOpen = !isDanmuSettingsOpen,
                            ),
                            onInteraction: resetHideTimer,
                          ),
                        ),
                      ),

                      // 1.6 彈幕設定面板
                      if (isDanmuSettingsOpen && showControls)
                        Positioned(
                          left: 20,
                          bottom: 100,
                          child: DanmuSettingsPanel(
                            danmuCtrl: danmuCtrl,
                            onClose: () =>
                                setState(() => isDanmuSettingsOpen = false),
                            onInteraction: resetHideTimer,
                          ),
                        ),
                      // 💥 1.7 影片資訊面板 (按下 I 鍵顯示)
                      if (isVideoInfoOpen)
                        Positioned.fill(
                          child: Container(
                            color: Colors.black45, // 半透明背景遮罩
                            child: VideoInfoDialog(
                              playerCtrl: playerCtrl,
                              onClose: () =>
                                  setState(() => isVideoInfoOpen = false),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // ================= 2. 側邊抽屜本體 (💥 AnimatedPositioned 必須是 Stack 直屬子元件) =================
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  top: 0,
                  bottom: 0,
                  right: isSidebarOpen ? 0 : -drawerWidth,
                  width: drawerWidth,
                  child: PlaylistDrawer(
                    controller: playerCtrl,
                    onClose: () => setState(() => isSidebarOpen = false),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
