// models/video_folder.dart

import 'video_item.dart';

class VideoFolder {
  final String name;             // 資料夾名稱 (例如: "進擊的巨人 Season 1")
  final List<VideoItem> videos;  // 該資料夾內的影片
  bool isExpanded;               // 是否展開

  VideoFolder({
    required this.name,
    required this.videos,
    this.isExpanded = true,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'isExpanded': isExpanded,
    'videos': videos.map((v) => {
      'videoPath': v.videoFile.path,
      'xmlPath': v.xmlFile?.path,
      'name': v.name,
    }).toList(),
  };
}