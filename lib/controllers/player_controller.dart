// controllers/player_controller.dart

import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:cross_file/cross_file.dart';
import 'package:file_picker/file_picker.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:window_manager/window_manager.dart';

import '../models/video_item.dart';
import '../models/video_folder.dart';
import '../services/storage_service.dart';

enum LoopMode {
  folder, // 💥 在同一個資料夾內循環 (最常用)
  one, // 單曲循環
  off, // 播完即停
}

class PlayerController extends ChangeNotifier with WindowListener {
  late final Player player;
  late final VideoController videoController;

  // 💥 核心：改以資料夾結構管理
  final List<VideoFolder> folders = [];
  final List<VideoItem> _shuffleQueue = [];
  // 💥 2. 隨機播放歷史紀錄 (支援按 '[' 回到剛才播過的那首歌)
  final List<VideoItem> _playbackHistory = [];

  VideoItem? currentVideo;
  VideoFolder? currentFolder;
  bool isFullScreen = false;
  bool isShuffle = false; // 💥 視覺不動，後台隨機
  int _lastSaveProgressTime = 0;
  LoopMode loopMode = LoopMode.folder;
  final Random _random = Random();

  PlayerController() {
    player = Player();
    videoController = VideoController(player);

    // 💥 時機 1：播放中每 3 秒自動在背景存檔一次！
    player.stream.position.listen((pos) {
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - _lastSaveProgressTime > 3000) {
        _lastSaveProgressTime = now;
        _saveCurrentProgress();
      }
    });

    // 💥 時機 2：按下暫停鍵時，立刻精準存檔！
    player.stream.playing.listen((playing) {
      if (!playing) {
        _saveCurrentProgress();
      }
      notifyListeners();
    });

    player.stream.duration.listen((_) => notifyListeners());
    player.stream.completed.listen((completed) {
      if (completed) onVideoEnded();
    });

    _initWindowSync();
    _restoreSavedLibrary();
  }

  // 扁平化取得全部影片數量
  int get totalVideosCount =>
      folders.fold(0, (sum, f) => sum + f.videos.length);

  void cycleLoopMode() {
    switch (loopMode) {
      case LoopMode.folder:
        loopMode = LoopMode.one;
        break;
      case LoopMode.one:
        loopMode = LoopMode.off;
        break;
      case LoopMode.off:
        loopMode = LoopMode.folder;
        break;
    }
    _save();
    notifyListeners();
  }

  void _resetShuffleQueue() {
    _shuffleQueue.clear();
    if (currentFolder == null || currentFolder!.videos.isEmpty) return;

    // 將該資料夾內的所有影片複製一份並打亂順序
    _shuffleQueue.addAll(currentFolder!.videos);
    _shuffleQueue.shuffle(_random);

    // 防呆：避免洗牌後第一首剛好又是目前正在播的同一首
    if (currentVideo != null &&
        _shuffleQueue.length > 1 &&
        _shuffleQueue.first == currentVideo) {
      final first = _shuffleQueue.removeAt(0);
      _shuffleQueue.add(first);
    }
  }

  // 💥 4. 取出下一首偽隨機影片
  VideoItem _getNextShuffleVideo() {
    // 如果這一輪所有影片都播過一遍了，重新裝滿抽籤池！
    if (_shuffleQueue.isEmpty) {
      _resetShuffleQueue();
    }

    if (_shuffleQueue.isEmpty) return currentVideo!;

    // 從抽籤池拿出一張籤 (保證接下來不會再被抽到)
    return _shuffleQueue.removeAt(0);
  }

  // 💥 5. 切換隨機模式開關
  void toggleShuffle() {
    isShuffle = !isShuffle;
    if (isShuffle) {
      _resetShuffleQueue();
    }
    _save();
    notifyListeners();
  }

  // 💥 播放指定資料夾內的影片
  Future<void> playVideo(
    VideoFolder folder,
    VideoItem item, {
    bool autoPlay = true,
    bool recordHistory = true,
  }) async {
    // 1. 換片前，先存舊影片的進度
    _saveCurrentProgress();

    if (recordHistory && currentVideo != null && currentVideo != item) {
      _playbackHistory.add(currentVideo!);
      if (_playbackHistory.length > 50) _playbackHistory.removeAt(0);
    }

    if (currentFolder != folder) {
      currentFolder = folder;
      _resetShuffleQueue();
    }
    currentFolder = folder;
    currentVideo = item;
    _shuffleQueue.remove(item);

    // 💥 核心修正 1：在 open 之前先讀取歷史進度！
    Duration? resumePosition;
    final saved = await StorageService.loadProgress(item.videoFile.path);
    if (saved != null) {
      final seekSec = (saved['time'] as num).toDouble();
      final durSec = (saved['duration'] as num).toDouble();

      // 如果未看完 95%，計算出起始時間；如果已經看完（>95%）則從第 0 秒開始
      if (durSec > 0 && (seekSec / durSec) < 0.95 && seekSec > 0) {
        resumePosition = Duration(milliseconds: (seekSec * 1000).toInt());
      }
    }

    // 💥 核心修正 2：直接使用 Media 原生自帶的 start 參數！
    // 底層解碼器直接以該秒數載入第一幀，就算 autoPlay: false 也 100% 精準續播！
    await player.open(
      Media(
        item.playablePath,
        start: resumePosition, // 👈 關鍵：原生起始時間！
      ),
      play: autoPlay,
    );

    _save();
    notifyListeners();
  }

  void playNext() {
    if (folders.isEmpty) return;
    if (currentFolder == null || currentVideo == null) {
      final firstFolder = folders.firstWhere(
        (f) => f.videos.isNotEmpty,
        orElse: () => folders.first,
      );
      if (firstFolder.videos.isNotEmpty) {
        playVideo(firstFolder, firstFolder.videos.first);
      }
      return;
    }

    final vids = currentFolder!.videos;
    if (vids.isEmpty) return;

    // 💥 偽隨機模式：從抽籤池中拿出一首沒播過的
    if (isShuffle) {
      final nextVid = _getNextShuffleVideo();
      playVideo(currentFolder!, nextVid);
      return;
    }

    // 順序播放模式
    final curIdx = vids.indexOf(currentVideo!);
    if (curIdx != -1 && curIdx + 1 < vids.length) {
      playVideo(currentFolder!, vids[curIdx + 1]);
    } else {
      if (loopMode == LoopMode.folder) {
        playVideo(currentFolder!, vids.first);
      } else {
        final fIdx = folders.indexOf(currentFolder!);
        final nextFIdx = (fIdx + 1) % folders.length;
        if (folders[nextFIdx].videos.isNotEmpty) {
          playVideo(folders[nextFIdx], folders[nextFIdx].videos.first);
        }
      }
    }
  }

  // 💥 8. 播放上一首 (隨機模式下精確回退到上一首播過的歌！)
  void playPrevious() {
    if (folders.isEmpty) return;

    // 💥 隨機模式下按上一首：優先從歷史紀錄回溯！
    if (isShuffle && _playbackHistory.isNotEmpty) {
      final prevVid = _playbackHistory.removeLast();
      final parentFolder = folders.firstWhere(
        (f) => f.videos.contains(prevVid),
        orElse: () => currentFolder ?? folders.first,
      );
      playVideo(parentFolder, prevVid, recordHistory: false);
      return;
    }

    if (currentFolder == null || currentVideo == null) return;
    final vids = currentFolder!.videos;
    if (vids.isEmpty) return;

    final curIdx = vids.indexOf(currentVideo!);
    if (curIdx > 0) {
      playVideo(currentFolder!, vids[curIdx - 1]);
    } else {
      if (loopMode == LoopMode.folder) {
        playVideo(currentFolder!, vids.last);
      } else {
        final fIdx = folders.indexOf(currentFolder!);
        final prevFIdx = (fIdx - 1 + folders.length) % folders.length;
        if (folders[prevFIdx].videos.isNotEmpty) {
          playVideo(folders[prevFIdx], folders[prevFIdx].videos.last);
        }
      }
    }
  }

  @override
  void onWindowClose() async {
    _saveCurrentProgress();
    _save();
  }

  // 💥 9. 影片自然播完時
  void onVideoEnded() {
    if (currentVideo != null) {
      currentVideo!.isFinished = true;
      StorageService.saveProgress(
        currentVideo!.videoFile.path,
        player.state.duration.inSeconds.toDouble(),
        player.state.duration.inSeconds.toDouble(),
      );
      notifyListeners();
    }

    if (currentFolder == null || currentFolder!.videos.isEmpty) return;

    switch (loopMode) {
      case LoopMode.off:
        break;

      case LoopMode.one:
        if (currentVideo != null) {
          playVideo(currentFolder!, currentVideo!, recordHistory: false);
        }
        break;

      case LoopMode.folder:
        // 在同一個資料夾循環：呼叫帶有偽隨機機制的 playNext()！
        playNext();
        break;
    }
  }

  // 💥 排序：資料夾外層排序，每個資料夾內部的集數也各自排序！
  void sortLibrary(bool ascending) {
    // 💥 核心修正：資料夾本身不動！只對每個資料夾「內部」的集數進行排序！
    for (var f in folders) {
      f.videos.sort(
        (a, b) =>
            ascending ? a.name.compareTo(b.name) : b.name.compareTo(a.name),
      );
    }

    _save();
    notifyListeners();
  }

  // 💥 刪除單一資料夾
  void removeFolder(VideoFolder folder) {
    folders.remove(folder);
    if (currentFolder == folder) {
      currentFolder = null;
      currentVideo = null;
      player.stop();
    }
    _save();
    notifyListeners();
  }

  // 清空所有資料夾
  void clearAllFolders() {
    folders.clear();
    currentFolder = null;
    currentVideo = null;
    player.stop();
    _save();
    notifyListeners();
  }

  // 💥 加入檔案或資料夾，自動按資料夾分組歸類
  void addFiles(List<XFile> inputFiles) {
    final Map<String, List<XFile>> folderGroups = {};

    if (!kIsWeb) {
      for (var item in inputFiles) {
        if (Directory(item.path).existsSync()) {
          // 是整個資料夾
          final dir = Directory(item.path);
          final folderName = dir.uri.pathSegments
              .where((s) => s.isNotEmpty)
              .last;
          try {
            final subFiles = dir.listSync(recursive: true).whereType<File>();
            for (var f in subFiles) {
              folderGroups.putIfAbsent(folderName, () => []).add(XFile(f.path));
            }
          } catch (_) {}
        } else {
          // 是單檔，以父資料夾名稱分組
          final f = File(item.path);
          final folderName = f.parent.uri.pathSegments
              .where((s) => s.isNotEmpty)
              .last;
          folderGroups.putIfAbsent(folderName, () => []).add(item);
        }
      }
    }

    final supportedExts = [
      '.mp4',
      '.mkv',
      '.avi',
      '.flv',
      '.mov',
      '.webm',
      '.mp3',
      '.flac',
      '.wav',
      '.m4a',
      '.aac',
      '.ogg',
      '.opus',
    ];

    folderGroups.forEach((folderName, files) {
      final mediaFiles = files
          .where(
            (f) =>
                supportedExts.any((ext) => f.name.toLowerCase().endsWith(ext)),
          )
          .toList();
      if (mediaFiles.isEmpty) return;

      // 尋找是否已有同名資料夾
      VideoFolder folder = folders.firstWhere(
        (f) => f.name == folderName,
        orElse: () {
          final newFolder = VideoFolder(name: folderName, videos: []);
          folders.add(newFolder);
          return newFolder;
        },
      );

      for (var media in mediaFiles) {
        final baseName = media.name.replaceAll(RegExp(r'\.[^.]+$'), '');
        XFile? xml;
        for (var f in files) {
          if (f.name.toLowerCase().endsWith('.xml') &&
              f.name.replaceAll(RegExp(r'\.[^.]+$'), '') == baseName) {
            xml = f;
            break;
          }
        }

        final alreadyExists = folder.videos.any((v) => v.name == media.name);
        if (!alreadyExists) {
          folder.videos.add(
            VideoItem(videoFile: media, xmlFile: xml, name: media.name),
          );
        }
      }
    });

    _save();
    notifyListeners();
  }

  Future<void> pickFolder() async {
    final String? selectedDirectory = await FilePicker.getDirectoryPath();
    if (selectedDirectory != null) {
      addFiles([XFile(selectedDirectory)]);
    }
  }

  Future<void> pickFiles() async {
    final pickedFiles = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        'mp4',
        'mkv',
        'avi',
        'mov',
        'flv',
        'webm',
        'mp3',
        'flac',
        'wav',
        'm4a',
        'aac',
        'ogg',
        'opus',
        'xml',
      ],
    );
    if (pickedFiles.isNotEmpty) {
      addFiles(pickedFiles.map((f) => f.xFile).toList());
    }
  }

  void _save() {
    StorageService.saveFolderLibrary(
      foldersData: folders.map((f) => f.toJson()).toList(),
      currentVideoPath: currentVideo?.videoFile.path,
      loopMode: loopMode.name,
      isShuffle: isShuffle,
    );
  }

  Future<void> _restoreSavedLibrary() async {
    final result = await StorageService.loadFolderLibrary();
    final rawFolders = result['folders'] as List;
    final savedVideoPath = result['currentVideoPath'] as String?;
    final savedLoopMode = result['loopMode'] as String?;
    isShuffle = result['isShuffle'] as bool;

    if (savedLoopMode != null) {
      try {
        loopMode = LoopMode.values.byName(savedLoopMode);
      } catch (_) {}
    }

    if (rawFolders.isEmpty) {
      notifyListeners();
      return;
    }

    VideoItem? targetVideo;
    VideoFolder? targetFolder;

    for (var rawF in rawFolders) {
      final name = rawF['name'] as String;
      final isExpanded = rawF['isExpanded'] as bool? ?? true;
      final rawVideos = rawF['videos'] as List;

      final List<VideoItem> vids = [];
      for (var rawV in rawVideos) {
        final videoPath = rawV['videoPath'] as String;
        final xmlPath = rawV['xmlPath'] as String?;
        final vName = rawV['name'] as String;

        if (!kIsWeb && File(videoPath).existsSync()) {
          final vid = XFile(videoPath);
          XFile? xml;
          if (xmlPath != null && File(xmlPath).existsSync())
            xml = XFile(xmlPath);

          final item = VideoItem(videoFile: vid, xmlFile: xml, name: vName);
          vids.add(item);

          if (savedVideoPath != null && videoPath == savedVideoPath) {
            targetVideo = item;
          }
        }
      }

      if (vids.isNotEmpty) {
        final folder = VideoFolder(
          name: name,
          videos: vids,
          isExpanded: isExpanded,
        );
        folders.add(folder);
        if (targetVideo != null &&
            targetFolder == null &&
            folder.videos.contains(targetVideo)) {
          targetFolder = folder;
        }
      }
    }

    if (folders.isNotEmpty) {
      targetFolder ??= folders.first;
      targetVideo ??= targetFolder.videos.first;
      await playVideo(targetFolder, targetVideo, autoPlay: false);
    }

    notifyListeners();
  }

  void _saveCurrentProgress() {
    if (currentVideo == null) return;
    final curSec = player.state.position.inMilliseconds / 1000.0;
    final durSec = player.state.duration.inMilliseconds / 1000.0;
    if (durSec <= 0 || curSec <= 0) return;

    // 如果已經看到 95% 以上，標記為已看完！
    if (curSec / durSec > 0.95) {
      currentVideo!.isFinished = true;
    }

    StorageService.saveProgress(
      currentVideo!.videoFile.path, // 用唯一路徑存檔
      curSec,
      durSec,
    );
  }

  // 視窗控制
  void _initWindowSync() async {
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.macOS ||
            defaultTargetPlatform == TargetPlatform.linux)) {
      windowManager.addListener(this);
      isFullScreen = await windowManager.isMaximized();
      notifyListeners();
    }
  }

  @override
  void onWindowMaximize() {
    isFullScreen = true;
    notifyListeners();
  }

  @override
  void onWindowUnmaximize() {
    isFullScreen = false;
    notifyListeners();
  }

  Future<void> toggleFullScreen() async {
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.macOS ||
            defaultTargetPlatform == TargetPlatform.linux)) {
      final isMax = await windowManager.isMaximized();
      if (!isMax) {
        await windowManager.maximize();
      } else {
        await windowManager.unmaximize();
      }
    }
  }

  @override
  void dispose() {
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.macOS ||
            defaultTargetPlatform == TargetPlatform.linux)) {
      windowManager.removeListener(this);
    }
    player.dispose();
    super.dispose();
  }
}
