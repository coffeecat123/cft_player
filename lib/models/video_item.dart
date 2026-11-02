// models/video_item.dart
import 'package:cross_file/cross_file.dart';

class VideoItem {
  final XFile videoFile; // 跨平台的檔案抽象
  final XFile? xmlFile; // 跨平台的彈幕檔案
  final String name;
  double duration;
  double lastPosition;
  bool isFinished;
  int? lastUpdated;

  VideoItem({
    required this.videoFile,
    this.xmlFile,
    required this.name,
    this.duration = 0.0,
    this.lastPosition = 0.0,
    this.isFinished = false,
    this.lastUpdated,
  });
  
  String get displayName => name.replaceAll(RegExp(r'\.[^.]+$'), '');

  String get extension {
    final idx = name.lastIndexOf('.');
    return idx != -1 ? name.substring(idx) : '';
  }

  // 取得 media_kit 可以吃的路徑 (Web 是 blob: 網址，桌面與手機是本地路徑)
  String get playablePath => videoFile.path;
}
