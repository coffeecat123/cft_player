// views/widgets/playlist_drawer.dart

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../controllers/player_controller.dart';
import '../../models/video_folder.dart';
import '../../models/video_item.dart';

// 💥 扁平化項目類型抽象
sealed class _DrawerRowItem {}

class _FolderHeaderRow extends _DrawerRowItem {
  final VideoFolder folder;
  _FolderHeaderRow(this.folder);
}

class _VideoItemRow extends _DrawerRowItem {
  final VideoFolder folder;
  final VideoItem video;
  _VideoItemRow(this.folder, this.video);
}

class PlaylistDrawer extends StatefulWidget {
  final PlayerController controller;
  final VoidCallback onClose;

  const PlaylistDrawer({
    super.key,
    required this.controller,
    required this.onClose,
  });

  @override
  State<PlaylistDrawer> createState() => _PlaylistDrawerState();
}

class _PlaylistDrawerState extends State<PlaylistDrawer> {
  bool isAscending = true;

  final ScrollController _scrollController = ScrollController();
  static const double _rowHeight = 48.0; // 💥 每行固定 48px，極致流暢與精確定位

  VideoItem? _lastScrolledVideo;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onVideoChanged);
    _scrollToActive(animated: false);
  }

  @override
  void didUpdateWidget(PlaylistDrawer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onVideoChanged);
      widget.controller.addListener(_onVideoChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onVideoChanged);
    _scrollController.dispose();
    super.dispose();
  }

  void _onVideoChanged() {
    final cur = widget.controller.currentVideo;
    if (cur != null && cur != _lastScrolledVideo) {
      _lastScrolledVideo = cur;
      _scrollToActive(animated: true);
    }
  }

  // 💥 完美修復：扁平化精確置中滾動（絕不偏位、絕不卡在半路！）
  void _scrollToActive({bool animated = true}) {
    final curFolder = widget.controller.currentFolder;
    final curVideo = widget.controller.currentVideo;
    if (curFolder == null || curVideo == null) return;

    // 如果所在資料夾收合了，自動展開
    if (!curFolder.isExpanded) {
      setState(() => curFolder.isExpanded = true);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;

      // 1. 在展開的扁平清單中找出精確的行索引
      int rowIndex = 0;
      int targetRowIndex = -1;

      for (var f in widget.controller.folders) {
        rowIndex++; // 資料夾標題佔 1 行
        if (f.isExpanded) {
          for (var v in f.videos) {
            if (v == curVideo) {
              targetRowIndex = rowIndex;
              break;
            }
            rowIndex++;
          }
        }
        if (targetRowIndex != -1) break;
      }

      if (targetRowIndex == -1) return;

      // 2. 像素級精準置中！
      final viewportHeight = _scrollController.position.viewportDimension;
      final targetOffset =
          (targetRowIndex * _rowHeight) -
          (viewportHeight / 2) +
          (_rowHeight / 2);
      final maxScroll = _scrollController.position.maxScrollExtent;
      final safeOffset = targetOffset.clamp(0.0, maxScroll);

      if (animated) {
        _scrollController.animateTo(
          safeOffset,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOut,
        );
      } else {
        _scrollController.jumpTo(safeOffset);
      }
    });
  }

  void _showClearAllConfirm(BuildContext context) {
    if (widget.controller.folders.isEmpty) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xEE252525),
        title: const Text(
          "Clear All Folders?",
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        content: const Text(
          "This will remove all playlists and videos.",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            child: const Text(
              "Cancel",
              style: TextStyle(color: Colors.white60),
            ),
            onPressed: () => Navigator.pop(ctx),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text("Clear All"),
            onPressed: () {
              Navigator.pop(ctx);
              widget.controller.clearAllFolders();
            },
          ),
        ],
      ),
    );
  }

  void _showDeleteFolderConfirm(BuildContext context, VideoFolder folder) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xEE252525),
        title: Text(
          "Remove \"${folder.name}\"?",
          style: const TextStyle(color: Colors.white, fontSize: 18),
        ),
        content: Text(
          "Remove this folder (${folder.videos.length} items) from playlist?",
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            child: const Text(
              "Cancel",
              style: TextStyle(color: Colors.white60),
            ),
            onPressed: () => Navigator.pop(ctx),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text("Remove"),
            onPressed: () {
              Navigator.pop(ctx);
              widget.controller.removeFolder(folder);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        // 💥 核心機制：動態生成目前的扁平化渲染列表
        final List<_DrawerRowItem> displayRows = [];
        for (var f in widget.controller.folders) {
          displayRows.add(_FolderHeaderRow(f));
          if (f.isExpanded) {
            for (var v in f.videos) {
              displayRows.add(_VideoItemRow(f, v));
            }
          }
        }

        return Material(
          color: const Color(0xEE1E1E1E),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ================= 頂部工具列 (按鈕統一 size 32) =================
                Row(
                  children: [
                    // 新增檔案
                    IconButton(
                      icon: SvgPicture.asset(
                        'assets/icons/upload_files.svg',
                        width: 32,
                        height: 32,
                        colorFilter: const ColorFilter.mode(
                          Colors.white,
                          BlendMode.srcIn,
                        ),
                      ),
                      tooltip: "Add files",
                      onPressed: () => widget.controller.pickFiles(),
                    ),

                    // 新增資料夾
                    IconButton(
                      icon: const Icon(
                        Icons.create_new_folder_outlined,
                        color: Colors.white,
                        size: 32,
                      ),
                      tooltip: "Add folder",
                      onPressed: () => widget.controller.pickFolder(),
                    ),
                    const Spacer(),

                    // 循環模式 (Repeat: Folder / One / Off)
                    IconButton(
                      icon: Icon(
                        widget.controller.loopMode == LoopMode.one
                            ? Icons.repeat_one
                            : Icons.repeat,
                        size: 32,
                        color: widget.controller.loopMode == LoopMode.off
                            ? Colors.white38
                            : Colors.redAccent,
                      ),
                      tooltip: switch (widget.controller.loopMode) {
                        LoopMode.folder => "Repeat: Current Folder",
                        LoopMode.one => "Repeat: One",
                        LoopMode.off => "Repeat: Off",
                      },
                      onPressed: () => widget.controller.cycleLoopMode(),
                    ),

                    // 排序按鈕 (只排內部集數)
                    IconButton(
                      icon: SvgPicture.asset(
                        isAscending
                            ? 'assets/icons/sort_asc.svg'
                            : 'assets/icons/sort_desc.svg',
                        width: 32,
                        height: 32,
                        colorFilter: const ColorFilter.mode(
                          Colors.white,
                          BlendMode.srcIn,
                        ),
                      ),
                      tooltip: isAscending
                          ? "Sort: Ascending"
                          : "Sort: Descending",
                      onPressed: () {
                        setState(() => isAscending = !isAscending);
                        widget.controller.sortLibrary(isAscending);
                        _scrollToActive();
                      },
                    ),

                    // 隨機按鈕 (偽隨機抽播)
                    IconButton(
                      icon: SvgPicture.asset(
                        'assets/icons/shuffle.svg',
                        width: 32,
                        height: 32,
                        colorFilter: ColorFilter.mode(
                          widget.controller.isShuffle
                              ? Colors.redAccent
                              : Colors.white38,
                          BlendMode.srcIn,
                        ),
                      ),
                      tooltip: widget.controller.isShuffle
                          ? "Shuffle: ON"
                          : "Shuffle: OFF",
                      onPressed: () {
                        widget.controller.toggleShuffle();
                        _scrollToActive();
                      },
                    ),

                    // 一鍵清空
                    IconButton(
                      icon: const Icon(
                        Icons.delete_sweep_outlined,
                        color: Colors.white70,
                        size: 32,
                      ),
                      tooltip: "Clear all",
                      onPressed: () => _showClearAllConfirm(context),
                    ),
                  ],
                ),

                // 標題列
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      const Text(
                        "Library",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        " (${widget.controller.folders.length} folders, ${widget.controller.totalVideosCount} files)",
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),

                const Divider(color: Colors.white24, height: 1),

                // ================= 💥 完美滾動條 + 扁平虛擬清單 =================
                Expanded(
                  child: Scrollbar(
                    controller: _scrollController,
                    thumbVisibility: true, // 💥 常駐顯示 Windows 桌面級滾動條
                    radius: const Radius.circular(8),
                    thickness: 6,
                    child: ListView.builder(
                      controller: _scrollController,
                      itemCount:
                          displayRows.length, // 💥 真實扁平項目數量，滾動條比例 100% 精準！
                      itemExtent: _rowHeight, // 💥 嚴格鎖定 48px，徹底杜絕抽搐與跳動！
                      itemBuilder: (context, index) {
                        final item = displayRows[index];

                        // 1. 渲染資料夾標題行
                        if (item is _FolderHeaderRow) {
                          final folder = item.folder;
                          return InkWell(
                            onTap: () {
                              setState(
                                () => folder.isExpanded = !folder.isExpanded,
                              );
                            },
                            hoverColor: Colors.white10,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    folder.isExpanded
                                        ? Icons.keyboard_arrow_down
                                        : Icons.keyboard_arrow_right,
                                    color: Colors.white70,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(
                                    Icons.folder,
                                    color: Colors.amberAccent,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      folder.name,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    " (${folder.videos.length})",
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      color: Colors.white38,
                                      size: 18,
                                    ),
                                    tooltip: "Remove folder",
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                      minWidth: 32,
                                      minHeight: 32,
                                    ),
                                    onPressed: () => _showDeleteFolderConfirm(
                                      context,
                                      folder,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        // 2. 渲染影片項目行
                        if (item is _VideoItemRow) {
                          final folder = item.folder;
                          final video = item.video;
                          final isPlaying =
                              widget.controller.currentVideo == video;

                          return ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.only(
                              left: 32,
                              right: 8,
                            ),
                            selected: isPlaying,
                            selectedTileColor: Colors.white12,
                            title: Text(
                              video.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                color: isPlaying
                                    ? Colors.redAccent
                                    : (video.isFinished
                                          ? Colors.white38
                                          : Colors.white),
                              ),
                            ),
                            trailing: video.xmlFile != null
                                ? SvgPicture.asset(
                                    'assets/icons/danmu_on.svg',
                                    width: 16,
                                    height: 16,
                                  )
                                : null,
                            onTap: () =>
                                widget.controller.playVideo(folder, video),
                          );
                        }

                        return const SizedBox();
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
