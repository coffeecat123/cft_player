// services/danmu_parser.dart
import 'package:cross_file/cross_file.dart';
import 'package:xml/xml.dart';
import 'package:flutter/material.dart';
import '../models/danmu_item.dart';

class DanmuParser {
  static Future<List<DanmuItem>> parseXml(XFile file) async {
    try {
      String content = await file.readAsString();

      // 1. 完全還原 JS: 過濾非法 XML 控制字元
      content = content.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), '');

      final document = XmlDocument.parse(content);
      final danmus = <DanmuItem>[];

      for (var node in document.findAllElements('d')) {
        final p = node.getAttribute('p')?.split(',');
        if (p == null || p.length < 4) continue;

        final time = double.tryParse(p[0]) ?? 0.0;
        final size = double.tryParse(p[2]) ?? 24.0;
        final colorInt = int.tryParse(p[3]) ?? 16777215;

        // 2. 還原 JS: B 站 #00000f 特殊白色修正
        Color color;
        if (colorInt == 15) {
          color = Colors.white;
        } else {
          color = Color(0xFF000000 | colorInt);
        }

        // 3. 還原 JS: 多餘空白處理
        final cleanedText = node.innerText.replaceAll(RegExp(r'\s+'), ' ').trim();
        if (cleanedText.isEmpty) continue;

        danmus.add(DanmuItem(
          text: cleanedText,
          time: time,
          color: color,
          size: size,
          shown: false,
        ));
      }

      // 4. 按時間排序
      danmus.sort((a, b) => a.time.compareTo(b.time));
      return danmus;
    } catch (e) {
      debugPrint("彈幕 XML 解析失敗: $e");
      return [];
    }
  }
}