// controllers/danmu_controller.dart

import 'dart:math';
import 'package:flutter/material.dart';
import '../models/danmu_item.dart';
import '../services/storage_service.dart'; // 💥 引入 storage_service

class DanmuController extends ChangeNotifier {
  static const double baseSpeed = 100.0;

  final repaintNotifier = ChangeNotifier();

  List<DanmuItem> _allDanmus = [];
  final List<DanmuItem> activeDanmus = [];
  final List<DanmuItem> _danmuBuffer = [];
  List<double> linePositions = [];

  List<DanmuItem> get allDanmus => _allDanmus;

  double containerWidth = 1920;
  double containerHeight = 1080;
  
  // 預設參數 (會被本機儲存的設定覆蓋)
  double danmuSize = 24.0;
  double danmuSpeed = 1.0;
  double danmuRange = 1.0;
  int danmuLimit = 200;
  double opacity = 1.0;
  bool isDanmuEnabled = true;

  int _lastDanmuTime = 0;
  double _densityInterval = 1000.0;
  final Random _random = Random();
  int _cursor = 0;

  // 💥 核心：建構子自動讀取本機快取！
  DanmuController() {
    _loadSavedSettings();
  }

  Future<void> _loadSavedSettings() async {
    final settings = await StorageService.loadDanmuSettings();
    isDanmuEnabled = settings['isEnabled'] as bool;
    danmuSpeed = settings['speed'] as double;
    danmuSize = settings['size'] as double;
    opacity = settings['opacity'] as double;
    danmuRange = settings['range'] as double;
    danmuLimit = settings['limit'] as int;

    updateLinePositions();
    updateDensity();
    notifyListeners();
    repaintNotifier.notifyListeners();
  }

  // 💥 輔助方法：統一非同步背景存檔
  void _saveSettings() {
    StorageService.saveDanmuSettings(
      isEnabled: isDanmuEnabled,
      speed: danmuSpeed,
      size: danmuSize,
      opacity: opacity,
      range: danmuRange,
      limit: danmuLimit,
    );
  }

  void toggleDanmu() {
    isDanmuEnabled = !isDanmuEnabled;
    _saveSettings(); // 存檔
    notifyListeners();
    repaintNotifier.notifyListeners();
  }

  void init(List<DanmuItem> list, Size size) {
    clear(); // 💥 先徹底清空乾淨
    _allDanmus = list; // 💥 再載入新彈幕
    resize(size);
    notifyListeners();
  }

   void clear() {
    // 💥 核心修正：徹底清空整部影片的彈幕庫，絕不殘留上一部影片的資料！
    _allDanmus.clear(); 
    activeDanmus.clear();
    _danmuBuffer.clear();
    _cursor = 0;
    _lastDanmuTime = 0;
    notifyListeners();
    repaintNotifier.notifyListeners();
  }

  void resize(Size size) {
    if (containerWidth == size.width && containerHeight == size.height) return;
    containerWidth = size.width;
    containerHeight = size.height;
    updateLinePositions();
    updateDensity();
  }

  void updateLinePositions() {
    final availableHeight = containerHeight * danmuRange;
    const double lineSpacing = 8.0;
    final totalLineHeight = danmuSize + lineSpacing;

    final maxLines = max(1, (availableHeight / totalLineHeight).floor());
    linePositions = List.generate(
      maxLines,
      (i) => i * totalLineHeight + (lineSpacing / 2),
    );
  }

  void updateDensity() {
    final actualSpeed = baseSpeed * danmuSpeed;
    final avgDuration = containerWidth / actualSpeed;
    final maxPerSecond = danmuLimit / avgDuration;
    _densityInterval = maxPerSecond > 0 ? (1000.0 / maxPerSecond) : 1000.0;
  }

  // 💥 所有設定變動時，除了即時渲染外，一律自動背景存檔！
  void setSpeed(double val) {
    danmuSpeed = val;
    updateDensity();
    _saveSettings();
    notifyListeners();
  }

  void setSize(double val) {
    danmuSize = val;
    updateLinePositions();
    for (var d in activeDanmus) {
      d.initPainter(danmuSize);
    }
    _saveSettings();
    notifyListeners();
  }

  void setOpacity(double val) {
    opacity = val;
    _saveSettings();
    notifyListeners();
    repaintNotifier.notifyListeners();
  }

  void setRange(double val) {
    danmuRange = val;
    updateLinePositions();
    _saveSettings();
    notifyListeners();
  }

  void setLimit(int val) {
    danmuLimit = val;
    updateDensity();
    _saveSettings();
    notifyListeners();
  }

  void onSeek(double targetTime) {
    activeDanmus.clear();
    _danmuBuffer.clear();
    for (var d in _allDanmus) {
      d.shown = false;
    }
    _cursor = _allDanmus.indexWhere((d) => d.time >= targetTime - 0.5);
    if (_cursor == -1) _cursor = _allDanmus.length;

    _triggerDanmus(targetTime);
    _lastDanmuTime = 0;
    repaintNotifier.notifyListeners();
  }

  void tick(double dt, double currentVideoTime) {
    if (activeDanmus.isNotEmpty) {
      final actualSpeed = baseSpeed * danmuSpeed;
      for (var d in activeDanmus) {
        d.x -= actualSpeed * dt;
      }
      activeDanmus.removeWhere((d) => d.x + d.width < 0);
      
      if (isDanmuEnabled) {
        repaintNotifier.notifyListeners();
      }
    }

    if (!isDanmuEnabled) return;

    _triggerDanmus(currentVideoTime);
    _processBuffer();
  }

  void _triggerDanmus(double time) {
    while (_cursor < _allDanmus.length) {
      final d = _allDanmus[_cursor];
      if (d.time > time) break;

      if (!d.shown && d.time >= time - 1.0) {
        _danmuBuffer.add(d);
        d.shown = true;
      }
      _cursor++;
    }
  }

  void _processBuffer() {
    if (_danmuBuffer.isEmpty || activeDanmus.length >= danmuLimit) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastDanmuTime < _densityInterval) return;

    if (_danmuBuffer.length > 200) {
      _danmuBuffer.removeRange(0, _danmuBuffer.length ~/ 2);
    }

    final line = _getNonOverlappingLine();
    if (line != null && _danmuBuffer.isNotEmpty) {
      final d = _danmuBuffer.removeAt(0);
      d.y = line;
      d.initPainter(danmuSize);
      d.x = containerWidth;
      activeDanmus.add(d);
      _lastDanmuTime = now;
    }
  }

  double? _getNonOverlappingLine() {
    if (linePositions.isEmpty) updateLinePositions();

    final rightEdgeThreshold = danmuSize * 1.5;

    final occupied = <double, List<DanmuItem>>{};
    for (var dm in activeDanmus) {
      if (dm.y != null) {
        occupied.putIfAbsent(dm.y!, () => []).add(dm);
      }
    }

    final availableLines = <double>[];
    for (var line in linePositions) {
      final dms = occupied[line];
      if (dms == null || dms.isEmpty) {
        availableLines.add(line);
      } else {
        final lastDm = dms.last;
        final rightEdge = lastDm.x + lastDm.width;

        if (rightEdge < containerWidth - rightEdgeThreshold) {
          availableLines.add(line);
        }
      }
    }

    if (availableLines.isNotEmpty) {
      final u = _random.nextDouble();
      final index = (pow(u, 2.0) * availableLines.length).floor().clamp(0, availableLines.length - 1);
      return availableLines[index];
    }
    return null;
  }
}