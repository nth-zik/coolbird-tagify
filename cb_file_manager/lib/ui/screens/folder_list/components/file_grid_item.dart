import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';

import 'package:cb_file_manager/ui/screens/folder_list/folder_list_state.dart';
import 'package:cb_file_manager/ui/screens/media_gallery/video_gallery_screen.dart';
import 'package:cb_file_manager/ui/screens/media_gallery/image_viewer_screen.dart';
import 'package:cb_file_manager/helpers/frame_timing_optimizer.dart';
import 'package:cb_file_manager/helpers/tag_manager.dart';
import 'package:flutter/material.dart';
import 'package:eva_icons_flutter/eva_icons_flutter.dart';
import 'package:cb_file_manager/ui/widgets/lazy_video_thumbnail.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cb_file_manager/ui/screens/folder_list/folder_list_bloc.dart';
import 'package:cb_file_manager/ui/screens/folder_list/folder_list_event.dart';
import 'package:cb_file_manager/ui/dialogs/open_with_dialog.dart';
import 'package:cb_file_manager/helpers/external_app_helper.dart';
import 'package:cb_file_manager/helpers/file_icon_helper.dart';
import 'package:cb_file_manager/config/app_theme.dart';
import 'package:cb_file_manager/ui/widgets/tag_chip.dart';
import 'package:cb_file_manager/ui/components/shared_file_context_menu.dart';
import 'package:flutter/services.dart'; // Import for keyboard key detection
import 'package:cb_file_manager/ui/widgets/thumbnail_loader.dart';

// Top-level helper functions for _MemoizedFileContent stability
String _topLevelBasename(File file) {
  return file.path.split(Platform.pathSeparator).last;
}

String _topLevelFormatFileSize(int size) {
  if (size < 1024) {
    return '$size B';
  } else if (size < 1024 * 1024) {
    return '${(size / 1024).toStringAsFixed(1)} KB';
  } else if (size < 1024 * 1024 * 1024) {
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  } else {
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

// Global singleton để quản lý và cache dữ liệu thumbnail
class ThumbnailCache {
  static final ThumbnailCache _instance = ThumbnailCache._internal();
  factory ThumbnailCache() => _instance;
  ThumbnailCache._internal();

  final Map<String, Widget> _thumbnailWidgets = {};
  // Removed _thumbnailBytes and _generatingThumbnails as they are not directly used by FileGridItem's ThumbnailCache instance strategy

  Widget? getCachedThumbnailWidget(String path) => _thumbnailWidgets[path];
  void cacheWidgetThumbnail(String path, Widget thumbnailWidget) {
    _thumbnailWidgets[path] = thumbnailWidget;
  }

  // These methods might be used by LazyVideoThumbnail or other parts, keep them if necessary for those.
  // For _ThumbnailWidget's direct caching, we only need get and cache for the Widget itself.
  final Set<String> _generatingThumbnails =
      {}; // Keep if LazyVideoThumbnail or other parts use it
  bool isGeneratingThumbnail(String path) =>
      _generatingThumbnails.contains(path);
  void markGeneratingThumbnail(String path) => _generatingThumbnails.add(path);
  void markThumbnailGenerated(String path) =>
      _generatingThumbnails.remove(path);

  void removeThumbnail(String path) {
    // Used if an item is deleted, for example
    _thumbnailWidgets.remove(path);
    _generatingThumbnails.remove(path);
  }

  void clearCache() {
    _thumbnailWidgets.clear();
    _generatingThumbnails.clear();
  }
}

class FileGridItem extends StatefulWidget {
  final File file;
  final FolderListState state;
  final bool isSelectionMode;
  final bool isSelected;
  final Function(String, {bool shiftSelect, bool ctrlSelect})
      toggleFileSelection;
  final Function() toggleSelectionMode;
  final Function(File, bool)? onFileTap;
  final Function()? onThumbnailGenerated; // Callback when thumbnail is ready
  final Function(BuildContext, String)? showAddTagToFileDialog;
  final Function(BuildContext, String, List<String>)? showDeleteTagDialog;
  final bool isDesktopMode;
  final String? lastSelectedPath;

  const FileGridItem({
    Key? key,
    required this.file,
    required this.state,
    required this.isSelectionMode,
    required this.isSelected,
    required this.toggleFileSelection,
    required this.toggleSelectionMode,
    this.onFileTap,
    this.onThumbnailGenerated,
    this.showAddTagToFileDialog,
    this.showDeleteTagDialog,
    this.isDesktopMode = false,
    this.lastSelectedPath,
  }) : super(key: key);

  @override
  State<FileGridItem> createState() => _FileGridItemState();
}

class _FileGridItemState extends State<FileGridItem>
    with AutomaticKeepAliveClientMixin {
  late List<String> _fileTags;
  StreamSubscription? _tagChangeSubscription;

  // Use a ValueNotifier for hovering state to avoid rebuilding the entire widget
  final ValueNotifier<bool> _isHoveringNotifier = ValueNotifier<bool>(false);

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _fileTags = widget.state.getTagsForFile(widget.file.path);
    _tagChangeSubscription = TagManager.onTagChanged.listen(_onTagChanged);
  }

  void _onTagChanged(String changedFilePath) {
    if (changedFilePath == widget.file.path ||
        changedFilePath == "global:tag_deleted") {
      final newTags = widget.state.getTagsForFile(widget.file.path);
      if (mounted && !_areTagListsEqual(newTags, _fileTags)) {
        setState(() {
          _fileTags = newTags;
        });
      }
    }
  }

  @override
  void dispose() {
    _tagChangeSubscription?.cancel();
    _isHoveringNotifier.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(FileGridItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newTags = widget.state.getTagsForFile(widget.file.path);
    if (mounted && !_areTagListsEqual(newTags, _fileTags)) {
      setState(() {
        _fileTags = newTags;
      });
    }
  }

  bool _areTagListsEqual(List<String> list1, List<String> list2) {
    if (list1.length != list2.length) return false;
    final sortedList1 = List<String>.from(list1)..sort();
    final sortedList2 = List<String>.from(list2)..sort();
    for (int i = 0; i < sortedList1.length; i++) {
      if (sortedList1[i] != sortedList2[i]) return false;
    }
    return true;
  }

  void _handleFileSelectionTap() {
    final HardwareKeyboard keyboard = HardwareKeyboard.instance;
    final bool isShiftPressed = keyboard.isShiftPressed;
    final bool isCtrlPressed =
        keyboard.isControlPressed || keyboard.isMetaPressed;
    widget.toggleFileSelection(widget.file.path,
        shiftSelect: isShiftPressed, ctrlSelect: isCtrlPressed);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    FrameTimingOptimizer().optimizeImageRendering();

    final extension = widget.file.path.split('.').last.toLowerCase();
    final bool isVideo =
        ['mp4', 'avi', 'mov', 'mkv', 'webm', 'flv', 'wmv'].contains(extension);
    final bool isImage =
        ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'].contains(extension);
    final bool isPreviewable = isImage || isVideo;

    // Use ValueListenableBuilder for hover state to avoid rebuilding everything
    return ValueListenableBuilder<bool>(
      valueListenable: _isHoveringNotifier,
      builder: (context, isHovering, _) {
        final Color cardColor = widget.isSelected
            ? Theme.of(context).primaryColor.withOpacity(0.15)
            : isHovering && widget.isDesktopMode
                ? Theme.of(context).hoverColor
                : Theme.of(context).cardColor;

        final BoxShadow? shadow = widget.isSelected
            ? BoxShadow(
                color: Theme.of(context).primaryColor.withOpacity(0.4),
                blurRadius: 4,
                offset: Offset(0, 1))
            : isHovering && widget.isDesktopMode
                ? const BoxShadow(
                    color: Color(0x1A000000),
                    blurRadius: 4,
                    offset: Offset(0, 1))
                : null;

        return RepaintBoundary(
          child: GestureDetector(
            onSecondaryTap: () => _showFileContextMenu(context, isVideo),
            child: MouseRegion(
              onEnter: (_) => _isHoveringNotifier.value = true,
              onExit: (_) => _isHoveringNotifier.value = false,
              cursor: SystemMouseCursors.click,
              child: Container(
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(8.0),
                  boxShadow: shadow != null ? [shadow] : null,
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  children: [
                    // Content doesn't need to be rebuilt when selection changes
                    RepaintBoundary(
                      child: _MemoizedFileContent(
                        key: ValueKey('content_${widget.file.path}'),
                        file: widget.file,
                        isVideo: isVideo,
                        isImage: isImage,
                        isPreviewable: isPreviewable,
                        fileTags: _fileTags,
                        onThumbnailGenerated: widget.onThumbnailGenerated,
                        getFileSize: _topLevelFormatFileSize,
                        basename: _topLevelBasename,
                      ),
                    ),
                    // Interactive layer
                    Positioned.fill(
                      child: _FileInteractionLayer(
                        onTap: () {
                          if (widget.isSelectionMode || widget.isDesktopMode) {
                            _handleFileSelectionTap();
                          } else {
                            _openFile(isVideo, isImage);
                          }
                        },
                        onDoubleTap: () {
                          if (widget.isDesktopMode && !widget.isSelectionMode) {
                            _openFile(isVideo, isImage);
                          }
                        },
                        onLongPress: () {
                          if (!widget.isSelectionMode) {
                            widget.toggleSelectionMode();
                            widget.toggleFileSelection(widget.file.path,
                                shiftSelect: false, ctrlSelect: false);
                          } else {
                            _handleFileSelectionTap();
                          }
                        },
                      ),
                    ),
                    // Selection border - separate layer to avoid rebuilding content
                    if (widget.isSelected)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(
                                  color: Theme.of(context).primaryColor,
                                  width: 2),
                              borderRadius: BorderRadius.circular(7.0),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showFileContextMenu(BuildContext context, bool isVideo) {
    final bool isImage = widget.file.path.toLowerCase().endsWith('.jpg') ||
        widget.file.path.toLowerCase().endsWith('.jpeg') ||
        widget.file.path.toLowerCase().endsWith('.png') ||
        widget.file.path.toLowerCase().endsWith('.gif') ||
        widget.file.path.toLowerCase().endsWith('.webp') ||
        widget.file.path.toLowerCase().endsWith('.bmp');

    showFileContextMenu(
      context: context,
      file: widget.file,
      fileTags: _fileTags,
      isVideo: isVideo,
      isImage: isImage,
      showAddTagToFileDialog: widget.showAddTagToFileDialog,
    );
  }

  void _openFile(bool isVideo, bool isImage) {
    if (widget.onFileTap != null) {
      widget.onFileTap!(widget.file, isVideo);
    } else if (isVideo) {
      if (!context.mounted) return;
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => VideoPlayerFullScreen(file: widget.file)));
    } else if (isImage) {
      if (!context.mounted) return;
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => ImageViewerScreen(file: widget.file)));
    } else {
      ExternalAppHelper.openFileWithApp(widget.file.path, 'shell_open')
          .then((success) {
        if (!success && context.mounted) {
          showDialog(
              context: context,
              builder: (context) => OpenWithDialog(filePath: widget.file.path));
        }
      });
    }
  }
}

// Separate widget for interaction layer to avoid rebuilding content
class _FileInteractionLayer extends StatelessWidget {
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;
  final VoidCallback onLongPress;

  const _FileInteractionLayer({
    required this.onTap,
    required this.onDoubleTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      onLongPress: onLongPress,
    );
  }
}

class _MemoizedFileContent extends StatefulWidget {
  final File file;
  final bool isVideo;
  final bool isImage;
  final bool isPreviewable;
  final List<String> fileTags;
  final Function()? onThumbnailGenerated;
  final String Function(int) getFileSize;
  final String Function(File) basename;

  const _MemoizedFileContent({
    Key? key,
    required this.file,
    required this.isVideo,
    required this.isImage,
    required this.isPreviewable,
    required this.fileTags,
    this.onThumbnailGenerated,
    required this.getFileSize,
    required this.basename,
  }) : super(key: key);

  @override
  State<_MemoizedFileContent> createState() => _MemoizedFileContentState();
}

class _MemoizedFileContentState extends State<_MemoizedFileContent>
    with AutomaticKeepAliveClientMixin {
  Future<FileStat>? _fileStatFuture;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _fileStatFuture = widget.file.stat();
  }

  @override
  void didUpdateWidget(_MemoizedFileContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.file.path != oldWidget.file.path) {
      _fileStatFuture = widget.file.stat();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: _ThumbnailWidget(
            key: ValueKey(
                'thumb_${widget.file.path}'), // Key for _ThumbnailWidget itself
            file: widget.file,
            isVideo: widget.isVideo,
            isImage: widget.isImage,
            isPreviewable: widget.isPreviewable,
            onThumbnailGenerated: widget.onThumbnailGenerated,
          ),
        ),
        Flexible(
          flex: 2,
          child: Container(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.basename(widget.file),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 2),
                _buildFileSizeInfo(),
                if (widget.fileTags.isNotEmpty) _buildTagsInfo(context),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFileSizeInfo() {
    return FutureBuilder<FileStat>(
      future: _fileStatFuture, // Use the memoized future
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return Text(widget.getFileSize(snapshot.data!.size),
              style: const TextStyle(fontSize: 10));
        }
        return const Text('Loading...', style: TextStyle(fontSize: 10));
      },
    );
  }

  Widget _buildTagsInfo(BuildContext context) {
    return Flexible(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(EvaIcons.bookmarkOutline,
              size: 12, color: AppTheme.primaryBlue),
          const SizedBox(width: 4),
          Flexible(
            child: widget.fileTags.length == 1
                ? TagChip(
                    tag: widget.fileTags.first,
                    isCompact: true,
                    onTap: () {
                      final bloc = BlocProvider.of<FolderListBloc>(context,
                          listen: false);
                      bloc.add(SearchByTag(widget.fileTags.first));
                    },
                  )
                : Text(
                    '${widget.fileTags.length} ${widget.fileTags.length == 1 ? 'tag' : 'tags'}',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 10, color: AppTheme.primaryBlue),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ThumbnailWidget extends StatefulWidget {
  final File file;
  final bool isVideo;
  final bool isImage;
  final bool isPreviewable;
  final VoidCallback? onThumbnailGenerated;

  const _ThumbnailWidget({
    Key? key,
    required this.file,
    required this.isVideo,
    required this.isImage,
    required this.isPreviewable,
    this.onThumbnailGenerated,
  }) : super(key: key);

  @override
  State<_ThumbnailWidget> createState() => _ThumbnailWidgetState();
}

class _ThumbnailWidgetState extends State<_ThumbnailWidget>
    with AutomaticKeepAliveClientMixin {
  final ThumbnailWidgetCache _thumbnailCache = ThumbnailWidgetCache();
  bool _hasNotifiedGeneration = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didUpdateWidget(covariant _ThumbnailWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.file.path != oldWidget.file.path ||
        widget.isPreviewable != oldWidget.isPreviewable ||
        widget.isImage != oldWidget.isImage ||
        widget.isVideo != oldWidget.isVideo) {
      _hasNotifiedGeneration = false;
    }
  }

  void _notifyThumbnailGenerated() {
    if (widget.onThumbnailGenerated != null && !_hasNotifiedGeneration) {
      _hasNotifiedGeneration = true;
      widget.onThumbnailGenerated!();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (!widget.isPreviewable) {
      return _buildGenericThumbnailWidget();
    }

    return RepaintBoundary(
      child: ThumbnailLoader(
        filePath: widget.file.path,
        isVideo: widget.isVideo,
        isImage: widget.isImage,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        onThumbnailLoaded: _notifyThumbnailGenerated,
        fallbackBuilder: () => _buildFallbackWidget(),
      ),
    );
  }

  Widget _buildGenericThumbnailWidget() {
    // Get icon for non-media files
    return RepaintBoundary(
      child: Center(
        child: FutureBuilder<Widget>(
          future: FileIconHelper.getIconForFile(widget.file, size: 48),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting ||
                !snapshot.hasData ||
                snapshot.hasError) {
              return _buildFallbackWidget();
            }

            WidgetsBinding.instance.addPostFrameCallback((_) {
              _notifyThumbnailGenerated();
            });

            return snapshot.data!;
          },
        ),
      ),
    );
  }

  Widget _buildFallbackWidget() {
    IconData icon;
    Color? iconColor;
    final extension = widget.file.path.split('.').last.toLowerCase();

    if (['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'].contains(extension)) {
      icon = EvaIcons.imageOutline;
      iconColor = Colors.blue;
    } else if (['mp4', 'mov', 'avi', 'mkv', 'flv', 'wmv'].contains(extension)) {
      icon = EvaIcons.videoOutline;
      iconColor = Colors.red;
    } else if (['mp3', 'wav', 'ogg', 'm4a', 'aac', 'flac']
        .contains(extension)) {
      icon = EvaIcons.musicOutline;
      iconColor = Colors.purple;
    } else if (['pdf', 'doc', 'docx', 'txt', 'xls', 'xlsx', 'ppt', 'pptx']
        .contains(extension)) {
      icon = EvaIcons.fileTextOutline;
      iconColor = Colors.indigo;
    } else {
      icon = EvaIcons.fileOutline;
      iconColor = Colors.grey;
    }

    return Container(
      color: Colors.black12,
      child: Center(
        child: Icon(icon, size: 48, color: iconColor),
      ),
    );
  }
}
