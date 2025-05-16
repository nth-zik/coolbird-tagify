import 'dart:io';
import 'dart:async'; // Thêm import cho StreamSubscription
import 'dart:ui'; // For lerpDouble
import 'package:flutter/scheduler.dart'; // For more responsive animations

import 'package:cb_file_manager/ui/screens/folder_list/file_details_screen.dart';
import 'package:cb_file_manager/ui/screens/folder_list/folder_list_state.dart';
import 'package:cb_file_manager/ui/screens/media_gallery/video_gallery_screen.dart';
import 'package:cb_file_manager/ui/screens/media_gallery/image_viewer_screen.dart';
import 'package:cb_file_manager/helpers/trash_manager.dart';
import 'package:cb_file_manager/helpers/tag_manager.dart'; // Import TagManager để lắng nghe thay đổi
import 'package:flutter/material.dart';
import 'package:eva_icons_flutter/eva_icons_flutter.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cb_file_manager/ui/screens/folder_list/folder_list_bloc.dart';
import 'package:cb_file_manager/ui/screens/folder_list/folder_list_event.dart';
import 'package:cb_file_manager/ui/dialogs/open_with_dialog.dart';
import 'package:cb_file_manager/helpers/external_app_helper.dart';
import 'package:cb_file_manager/helpers/file_icon_helper.dart';
// Import app theme
import 'package:cb_file_manager/widgets/tag_chip.dart'; // Import the new TagChip widget
import 'package:cb_file_manager/ui/components/shared_file_context_menu.dart';
import 'package:cb_file_manager/widgets/lazy_video_thumbnail.dart';
import 'package:flutter/services.dart'; // Import for keyboard key detection
import 'package:flutter/rendering.dart'; // Import for RepaintBoundary

// Add this class to disable ripple effects
class NoSplashFactory extends InteractiveInkFeatureFactory {
  @override
  InteractiveInkFeature create({
    required MaterialInkController controller,
    required RenderBox referenceBox,
    required Offset position,
    required Color color,
    required TextDirection textDirection,
    bool containedInkWell = false,
    RectCallback? rectCallback,
    BorderRadius? borderRadius,
    ShapeBorder? customBorder,
    double? radius,
    VoidCallback? onRemoved,
  }) {
    return _NoSplash(
      controller: controller,
      referenceBox: referenceBox,
    );
  }
}

class _NoSplash extends InteractiveInkFeature {
  _NoSplash({
    required MaterialInkController controller,
    required RenderBox referenceBox,
  }) : super(
          controller: controller,
          referenceBox: referenceBox,
          color: Colors.transparent,
        );

  @override
  void paintFeature(Canvas canvas, Matrix4 transform) {
    // No painting needed
  }
}

class FileItem extends StatefulWidget {
  final File file;
  final FolderListState state;
  final bool isSelectionMode;
  final bool isSelected;
  final Function(String, {bool shiftSelect, bool ctrlSelect})
      toggleFileSelection;
  final Function(BuildContext, String, List<String>) showDeleteTagDialog;
  final Function(BuildContext, String) showAddTagToFileDialog;
  final Function(File, bool)? onFileTap;
  final bool isDesktopMode;
  final String?
      lastSelectedPath; // Add parameter to track last selected file for shift-selection

  const FileItem({
    Key? key,
    required this.file,
    required this.state,
    required this.isSelectionMode,
    required this.isSelected,
    required this.toggleFileSelection,
    required this.showDeleteTagDialog,
    required this.showAddTagToFileDialog,
    this.onFileTap,
    this.isDesktopMode = false,
    this.lastSelectedPath,
  }) : super(key: key);

  @override
  State<FileItem> createState() => _FileItemState();
}

class _FileItemState extends State<FileItem> {
  late List<String> _fileTags;
  StreamSubscription? _tagChangeSubscription;
  bool _isHovering = false;

  @override
  void initState() {
    super.initState();
    _fileTags = widget.state.getTagsForFile(widget.file.path);
    // Đăng ký lắng nghe thay đổi tag
    _tagChangeSubscription = TagManager.onTagChanged.listen(_onTagChanged);
  }

  @override
  void dispose() {
    // Hủy đăng ký lắng nghe khi widget bị hủy
    _tagChangeSubscription?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(FileItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Visual selection updates are driven by widget.isSelected via ValueListenableBuilder in parent

    // Update tags if they've changed
    final newTags = widget.state.getTagsForFile(widget.file.path);
    if (!_areTagListsEqual(newTags, _fileTags)) {
      if (mounted) {
        setState(() {
          _fileTags = newTags;
        });
      }
    }
  }

  // Xử lý sự kiện thay đổi tag
  void _onTagChanged(String changedFilePath) {
    bool isTagOnlyEvent = false;
    String actualPath = changedFilePath;

    if (changedFilePath.startsWith("tag_only:")) {
      isTagOnlyEvent = true;
      actualPath = changedFilePath.substring("tag_only:".length);
    }

    if (actualPath == widget.file.path ||
        changedFilePath == "global:tag_deleted") {
      if (!isTagOnlyEvent) {
        TagManager.clearCache();
      }
      final newTags = widget.state.getTagsForFile(widget.file.path);
      if (!_areTagListsEqual(newTags, _fileTags)) {
        if (mounted) {
          setState(() {
            _fileTags = newTags;
          });
        }
      }
    }
  }

  bool _areTagListsEqual(List<String> list1, List<String> list2) {
    if (list1.length != list2.length) return false;
    list1.sort();
    list2.sort();
    for (int i = 0; i < list1.length; i++) {
      if (list1[i] != list2[i]) return false;
    }
    return true;
  }

  Future<void> _removeTagDirectly(String tag) async {
    try {
      await TagManager.removeTag(widget.file.path, tag);
      if (mounted) {
        setState(() {
          _fileTags.remove(tag);
        });
        TagManager.instance.notifyTagChanged("tag_only:" + widget.file.path);
        final bloc = BlocProvider.of<FolderListBloc>(context, listen: false);
        bloc.add(RemoveTagFromFile(widget.file.path, tag));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tag "$tag" đã được xóa'),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi xóa tag: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _openFile(bool isVideo, bool isImage) {
    if (widget.onFileTap != null) {
      widget.onFileTap!(widget.file, isVideo);
    } else if (isVideo) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VideoPlayerFullScreen(file: widget.file),
        ),
      );
    } else if (isImage) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ImageViewerScreen(file: widget.file),
        ),
      );
    } else {
      ExternalAppHelper.openFileWithApp(
        widget.file.path,
        'shell_open',
      ).then((success) {
        if (!success && mounted) {
          showDialog(
            context: context,
            builder: (context) => OpenWithDialog(filePath: widget.file.path),
          );
        }
      });
    }
  }

  // Simplified selection tap handler
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
    final String extension = widget.file.path.split('.').last.toLowerCase();
    final bool isVideo = [
      'mp4',
      'mov',
      'avi',
      'mkv',
      'flv',
      'wmv',
    ].contains(extension);
    final bool isImage = [
      'jpg',
      'jpeg',
      'png',
      'gif',
      'webp',
      'bmp',
    ].contains(extension);

    // Use widget.isSelected directly for styling
    final Color tileColor = widget.isSelected
        ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.7)
        : _isHovering && widget.isDesktopMode
            ? Theme.of(context).hoverColor
            : Theme.of(context).cardColor;

    return MouseRegion(
      onEnter: (_) {
        if (mounted) setState(() => _isHovering = true);
      },
      onExit: (_) {
        if (mounted) setState(() => _isHovering = false);
      },
      cursor: SystemMouseCursors.click,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 2.0),
        decoration: BoxDecoration(
          color: tileColor,
          borderRadius: BorderRadius.circular(4.0),
        ),
        child: RepaintBoundary(
          child: Stack(
            children: [
              _FileContentLayer(
                file: widget.file,
                fileTags: _fileTags,
                isVideo: isVideo,
                isImage: isImage,
                onRemoveTag: _removeTagDirectly,
                onAddTag: () =>
                    widget.showAddTagToFileDialog(context, widget.file.path),
                showDeleteTagDialog: widget.showDeleteTagDialog,
              ),
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    if (widget.isSelectionMode) {
                      _handleFileSelectionTap();
                    } else if (widget.isDesktopMode) {
                      _handleFileSelectionTap(); // Desktop single click selects
                    } else {
                      _openFile(isVideo, isImage); // Mobile single click opens
                    }
                  },
                  onDoubleTap: () {
                    if (widget.isDesktopMode) {
                      _openFile(isVideo, isImage);
                    }
                  },
                  onSecondaryTap: () {
                    _showContextMenu(context, isVideo, isImage);
                  },
                  onLongPress: () {
                    if (!widget.isSelectionMode && !widget.isDesktopMode) {
                      // Mobile long press enters selection mode and selects item
                      widget.toggleFileSelection(widget.file.path,
                          shiftSelect: false, ctrlSelect: false);
                    } else if (widget.isSelectionMode) {
                      _handleFileSelectionTap(); // Allow modification of selection
                    }
                    // For desktop, long press might also trigger context menu or other actions, handled by onSecondaryTap or specific listeners
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showContextMenu(BuildContext context, bool isVideo, bool isImage) {
    showFileContextMenu(
      context: context,
      file: widget.file,
      fileTags: _fileTags,
      isVideo: isVideo,
      isImage: isImage,
      showAddTagToFileDialog: widget.showAddTagToFileDialog,
    );
  }
}

// _FileContentLayer and other helper methods like _basename, _formatFileSize, _moveToTrash, _showRenameDialog, _buildLeadingWidget remain largely the same
// They do not directly manage selection state, only display data.

class _FileContentLayer extends StatelessWidget {
  final File file;
  final List<String> fileTags;
  final bool isVideo;
  final bool isImage;
  final Function(String) onRemoveTag;
  final VoidCallback onAddTag;
  final Function(BuildContext, String, List<String>) showDeleteTagDialog;

  const _FileContentLayer({
    Key? key,
    required this.file,
    required this.fileTags,
    required this.isVideo,
    required this.isImage,
    required this.onRemoveTag,
    required this.onAddTag,
    required this.showDeleteTagDialog,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final String extension = file.path.split('.').last.toLowerCase();
    IconData icon;
    Color? iconColor;

    if (['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'].contains(extension)) {
      icon = EvaIcons.imageOutline;
      iconColor = Colors.blue;
    } else if (['mp4', 'mov', 'avi', 'mkv', 'flv', 'wmv'].contains(extension)) {
      icon = EvaIcons.videoOutline;
      iconColor = Colors.red;
    } else if ([
      'mp3',
      'wav',
      'ogg',
      'm4a',
      'aac',
      'flac',
    ].contains(extension)) {
      icon = EvaIcons.musicOutline;
      iconColor = Colors.purple;
    } else if ([
      'pdf',
      'doc',
      'docx',
      'txt',
      'xls',
      'xlsx',
      'ppt',
      'pptx',
    ].contains(extension)) {
      icon = EvaIcons.fileTextOutline;
      iconColor = Colors.indigo;
    } else {
      icon = EvaIcons.fileOutline;
      iconColor = Colors.grey;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12.0, vertical: 0),
          leading: _buildLeadingWidget(isVideo, icon, iconColor),
          title: Text(
            _basename(file),
            style: const TextStyle(
              fontSize: 14,
            ),
          ),
          subtitle: FutureBuilder<FileStat>(
            future: file.stat(),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                String sizeText = _formatFileSize(snapshot.data!.size);
                return Text(
                  '${snapshot.data!.modified.toString().split('.')[0]} • $sizeText',
                );
              }
              return const Text('Loading...');
            },
          ),
          trailing: PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (String value) {
              if (value == 'tag') {
                onAddTag();
              } else if (value == 'delete_tag') {
                showDeleteTagDialog(context, file.path, fileTags);
              } else if (value == 'details') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => FileDetailsScreen(file: file),
                  ),
                );
              } else if (value == 'trash') {
                _moveToTrash(context, file); // Pass file to moveToTrash
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem(
                value: 'tag',
                child: Text('Add Tag'),
              ),
              if (fileTags.isNotEmpty)
                const PopupMenuItem(
                  value: 'delete_tag',
                  child: Text('Manage Tags'),
                ),
              const PopupMenuItem(
                value: 'details',
                child: Text('Properties'),
              ),
              const PopupMenuItem(
                value: 'trash',
                child: Text(
                  'Move to Trash',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        ),
        if (fileTags.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(
              left: 16.0,
              bottom: 8.0,
              right: 16.0,
            ),
            child: Wrap(
              spacing: 8.0,
              runSpacing: 4.0,
              children:
                  fileTags.map((tag) => _buildTagChip(tag, context)).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildTagChip(String tag, BuildContext context) {
    return TagChip(
      tag: tag,
      onTap: () {
        final bloc = BlocProvider.of<FolderListBloc>(context);
        bloc.add(SearchByTag(tag));
      },
      onDeleted: () {
        onRemoveTag(tag); // This should call _FileItemState._removeTagDirectly
      },
    );
  }

  Widget _buildLeadingWidget(bool isVideo, IconData icon, Color? iconColor) {
    if (isVideo) {
      return SizedBox(
        width: 48,
        height: 48,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LazyVideoThumbnail(
            videoPath: file.path,
            width: 48,
            height: 48,
            fallbackBuilder: () => Icon(icon, size: 32, color: iconColor),
          ),
        ),
      );
    } else if (isImage) {
      return SizedBox(
        width: 48,
        height: 48,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Image.file(
            file,
            width: 48,
            height: 48,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
                Icon(icon, size: 32, color: iconColor),
          ),
        ),
      );
    } else {
      return FutureBuilder<Widget>(
        future: FileIconHelper.getIconForFile(file, size: 32),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Icon(icon, size: 32, color: iconColor);
          }
          if (snapshot.hasData) {
            return snapshot.data!;
          }
          return Icon(icon, size: 32, color: iconColor);
        },
      );
    }
  }

  String _basename(File file) {
    return file.path.split(Platform.pathSeparator).last;
  }

  String _formatFileSize(int size) {
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

  void _moveToTrash(BuildContext context, File fileToTrash) {
    final trashManager = TrashManager();
    trashManager.moveToTrash(fileToTrash.path).then((success) {
      if (success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Moved ${_basename(fileToTrash)} to trash'),
            action: SnackBarAction(
              label: 'UNDO',
              onPressed: () {
                trashManager
                    .restoreFromTrash(fileToTrash.path)
                    .then((restored) {
                  if (restored && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text('Restored ${_basename(fileToTrash)}')),
                    );
                  }
                });
              },
            ),
          ),
        );
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to move ${_basename(fileToTrash)} to trash'),
            backgroundColor: Colors.red,
          ),
        );
      }
    });
  }
}
