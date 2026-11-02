// services/storage_service.dart

import 'dart:convert';

import '../models/video_item.dart';

import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  // 💥 1. 儲存單部影片進度 (以唯一路徑為 Key)
  static Future<void> saveProgress(String pathOrName, double time, double duration) async {
    if (time <= 0 || duration <= 0) return;
    
    final prefs = await SharedPreferences.getInstance();
    final data = jsonEncode({
      'time': time,
      'duration': duration,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    });
    await prefs.setString('progress:$pathOrName', data);
  }

  // 💥 2. 讀取單部影片進度
  static Future<Map<String, dynamic>?> loadProgress(String pathOrName) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('progress:$pathOrName');
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  static Future<void> savePlaylist(
    List<VideoItem> playlist,
    int currentIndex, {
    String? loopMode, // 👈 傳入模式字串 (playlist / one / off)
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final data = playlist
        .map(
          (item) => {
            'videoPath': item.videoFile.path,
            'xmlPath': item.xmlFile?.path,
            'name': item.name,
          },
        )
        .toList();

    await prefs.setString('saved_playlist', jsonEncode(data));
    await prefs.setInt('saved_playlist_index', currentIndex);
    if (loopMode != null) {
      await prefs.setString('saved_loop_mode', loopMode); // 👈 存入
    }
  }

  // 💥 2. 讀取時，一併取回上次的 loopMode
  static Future<Map<String, dynamic>> loadPlaylist() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('saved_playlist');
    final index = prefs.getInt('saved_playlist_index') ?? -1;
    final loopMode = prefs.getString('saved_loop_mode'); // 👈 取出

    if (raw == null) {
      return {
        'items': <Map<String, dynamic>>[],
        'index': -1,
        'loopMode': loopMode,
      };
    }

    try {
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      return {'items': list, 'index': index, 'loopMode': loopMode};
    } catch (_) {
      return {
        'items': <Map<String, dynamic>>[],
        'index': -1,
        'loopMode': loopMode,
      };
    }
  }

  static Future<void> saveFolderLibrary({
    required List<Map<String, dynamic>> foldersData,
    required String? currentVideoPath,
    required String loopMode,
    required bool isShuffle,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_folders', jsonEncode(foldersData));
    if (currentVideoPath != null) {
      await prefs.setString('saved_current_video_path', currentVideoPath);
    }
    await prefs.setString('saved_loop_mode', loopMode);
    await prefs.setBool('saved_is_shuffle', isShuffle);
  }

  // 💥 讀取上次的資料夾結構
  static Future<Map<String, dynamic>> loadFolderLibrary() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('saved_folders');
    final currentVideoPath = prefs.getString('saved_current_video_path');
    final loopMode = prefs.getString('saved_loop_mode');
    final isShuffle = prefs.getBool('saved_is_shuffle') ?? false;

    if (raw == null)
      return {
        'folders': [],
        'currentVideoPath': null,
        'loopMode': loopMode,
        'isShuffle': isShuffle,
      };

    try {
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      return {
        'folders': list,
        'currentVideoPath': currentVideoPath,
        'loopMode': loopMode,
        'isShuffle': isShuffle,
      };
    } catch (_) {
      return {
        'folders': [],
        'currentVideoPath': null,
        'loopMode': loopMode,
        'isShuffle': isShuffle,
      };
    }
  }

  // 💥 1. 儲存彈幕設定 (對齊 player.js 的 save_status)
  static Future<void> saveDanmuSettings({
    required bool isEnabled,
    required double speed,
    required double size,
    required double opacity,
    required double range,
    required int limit,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('danmu_enabled', isEnabled);
    await prefs.setDouble('danmu_speed', speed);
    await prefs.setDouble('danmu_size', size);
    await prefs.setDouble('danmu_opacity', opacity);
    await prefs.setDouble('danmu_range', range);
    await prefs.setInt('danmu_limit', limit);
  }

  // 💥 2. 讀取彈幕設定 (對齊 player.js 的 saved_xxx)
  static Future<Map<String, dynamic>> loadDanmuSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'isEnabled': prefs.getBool('danmu_enabled') ?? true,
      'speed': prefs.getDouble('danmu_speed') ?? 1.0,
      'size': prefs.getDouble('danmu_size') ?? 24.0,
      'opacity': prefs.getDouble('danmu_opacity') ?? 1.0,
      'range': prefs.getDouble('danmu_range') ?? 1.0,
      'limit': prefs.getInt('danmu_limit') ?? 200,
    };
  }
}
