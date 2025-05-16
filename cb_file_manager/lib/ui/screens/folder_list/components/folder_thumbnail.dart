import 'dart:io';
import 'package:flutter/material.dart';
import 'package:eva_icons_flutter/eva_icons_flutter.dart';
import 'package:cb_file_manager/helpers/folder_thumbnail_service.dart';
import 'package:cb_file_manager/widgets/lazy_video_thumbnail.dart';

/// Widget for displaying folder thumbnail
class FolderThumbnail extends StatefulWidget {
  final Directory folder;
  final double size;

  const FolderThumbnail({
    Key? key,
    required this.folder,
    this.size = 80,
  }) : super(key: key);

  @override
  State<FolderThumbnail> createState() => _FolderThumbnailState();
}

class _FolderThumbnailState extends State<FolderThumbnail> {
  final FolderThumbnailService _thumbnailService = FolderThumbnailService();
  String? _thumbnailPath;
  bool _isLoading = true;
  bool _loadFailed = false;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _loadThumbnail();
  }

  @override
  void didUpdateWidget(FolderThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.folder.path != widget.folder.path) {
      _loadThumbnail();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> _loadThumbnail() async {
    if (_disposed) return;

    setState(() {
      _isLoading = true;
      _loadFailed = false;
    });

    try {
      final path =
          await _thumbnailService.getFolderThumbnail(widget.folder.path);

      if (_disposed) return;

      setState(() {
        _thumbnailPath = path;
        _isLoading = false;
      });

      debugPrint('Loaded thumbnail for folder: ${widget.folder.path}');
      debugPrint('Thumbnail path: ${_thumbnailPath ?? "null"}');
    } catch (e) {
      debugPrint('Error loading thumbnail: $e');
      if (!_disposed) {
        setState(() {
          _thumbnailPath = null;
          _isLoading = false;
          _loadFailed = true;
        });
      }
    }
  }

  bool _isVideoPath(String? path) {
    if (path == null) return false;
    return path.startsWith("video::");
  }

  String _getVideoPath(String path) {
    if (!path.startsWith("video::")) return path;

    final parts = path.split("::");
    if (parts.length >= 3) {
      return parts[1];
    }
    return path.substring(7);
  }

  String _getThumbnailPath(String path) {
    if (!path.startsWith("video::")) return path;

    final parts = path.split("::");
    if (parts.length >= 3) {
      return parts[2];
    }
    return path.substring(7);
  }

  @override
  Widget build(BuildContext context) {
    // Use a RepaintBoundary with a key based on the folder path to prevent repainting
    return RepaintBoundary(
      key: ValueKey('thumbnail-${widget.folder.path}'),
      child: _buildThumbnailContent(),
    );
  }

  Widget _buildThumbnailContent() {
    if (_isLoading) {
      return Center(
        child: SizedBox(
          width: widget.size * 0.5,
          height: widget.size * 0.5,
          child: const CircularProgressIndicator(
            strokeWidth: 2,
          ),
        ),
      );
    }

    // Default folder icon when no thumbnail
    if (_thumbnailPath == null || _loadFailed) {
      return Center(
        child: Icon(
          EvaIcons.folderOutline,
          size: widget.size * 0.7,
          color: Colors.amber[700],
        ),
      );
    }

    final bool isVideo = _isVideoPath(_thumbnailPath);
    final String videoPath = _getVideoPath(_thumbnailPath!);
    final String thumbnailPath = _getThumbnailPath(_thumbnailPath!);

    try {
      if (isVideo) {
        if (!File(videoPath).existsSync()) {
          debugPrint('Video file does not exist: $videoPath');
          return Center(
            child: Icon(
              EvaIcons.folderOutline,
              size: widget.size * 0.7,
              color: Colors.amber[700],
            ),
          );
        }

        return Container(
          width: double.infinity,
          height: double.infinity,
          margin: const EdgeInsets.all(1),
          decoration: BoxDecoration(
            border: Border.all(
              color: Colors.amber[600]!,
              width: 1.5,
            ),
          ),
          // Use AspectRatio to maintain proper video aspect ratio
          child: Stack(
            fit: StackFit.expand,
            children: [
              AspectRatio(
                aspectRatio: 16 / 9, // Standard video aspect ratio
                child: LazyVideoThumbnail(
                  videoPath: videoPath,
                  width: double.infinity,
                  height: double.infinity,
                  keepAlive: true,
                  fallbackBuilder: () => Container(
                    color: Colors.blueGrey[900],
                    child: Center(
                      child: Icon(
                        EvaIcons.videoOutline,
                        size: widget.size * 0.4,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 4,
                bottom: 4,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Icon(
                    Icons.play_arrow,
                    color: Colors.white,
                    size: widget.size * 0.25 < 16 ? widget.size * 0.25 : 16,
                  ),
                ),
              ),
            ],
          ),
        );
      } else {
        final file = File(thumbnailPath);
        if (!file.existsSync()) {
          debugPrint('Image file does not exist: $thumbnailPath');
          return Center(
            child: Icon(
              EvaIcons.folderOutline,
              size: widget.size * 0.7,
              color: Colors.amber[700],
            ),
          );
        }

        return Container(
          width: double.infinity,
          height: double.infinity,
          margin: const EdgeInsets.all(1),
          decoration: BoxDecoration(
            border: Border.all(
              color: Colors.amber[600]!,
              width: 1.5,
            ),
          ),
          child: AspectRatio(
            aspectRatio: 1, // Square aspect ratio for images
            child: Image.file(
              file,
              fit: BoxFit.contain, // Use contain to respect aspect ratio
              width: double.infinity,
              height: double.infinity,
              filterQuality: FilterQuality.medium,
              errorBuilder: (context, error, stackTrace) {
                debugPrint('Image loading error: $error');
                return Center(
                  child: Icon(
                    EvaIcons.folderOutline,
                    size: widget.size * 0.7,
                    color: Colors.amber[700],
                  ),
                );
              },
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error creating image widget: $e');
      return Center(
        child: Icon(
          EvaIcons.folderOutline,
          size: widget.size * 0.7,
          color: Colors.amber[700],
        ),
      );
    }
  }
}

// Helper function to determine if we're on desktop
bool get isDesktopPlatform =>
    Platform.isWindows || Platform.isMacOS || Platform.isLinux;
