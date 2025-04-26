import 'dart:io';
import 'package:flutter/material.dart';
import '../helpers/video_thumbnail_helper.dart';
import 'package:visibility_detector/visibility_detector.dart'; // Add this import for VisibilityDetector

/// A widget that efficiently displays a video thumbnail with lazy loading
/// Handles viewport visibility detection to prioritize visible thumbnails
class LazyVideoThumbnail extends StatefulWidget {
  final String videoPath;
  final double width;
  final double height;
  final Widget Function() fallbackBuilder;

  const LazyVideoThumbnail({
    Key? key,
    required this.videoPath,
    this.width = 160,
    this.height = 120,
    required this.fallbackBuilder,
  }) : super(key: key);

  @override
  State<LazyVideoThumbnail> createState() => _LazyVideoThumbnailState();
}

class _LazyVideoThumbnailState extends State<LazyVideoThumbnail>
    with AutomaticKeepAliveClientMixin {
  bool _isVisible = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    // Start low-priority prefetch when widget is created
    _prefetchThumbnail();
  }

  Future<void> _prefetchThumbnail() async {
    if (!mounted) return;

    // Prefetch at low priority (won't create too many FFmpeg processes)
    await VideoThumbnailHelper.prefetchThumbnail(widget.videoPath);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return VisibilityDetector(
      key: ValueKey('video_thumb_${widget.videoPath}'),
      onVisibilityChanged: (visibilityInfo) {
        final isNowVisible = visibilityInfo.visibleFraction > 0;

        // Only take action if visibility state changes
        if (isNowVisible != _isVisible) {
          setState(() {
            _isVisible = isNowVisible;
          });

          // If becoming visible, prioritize this thumbnail
          if (isNowVisible) {
            VideoThumbnailHelper.prioritizeThumbnail(widget.videoPath);
          }
        }
      },
      child: VideoThumbnailHelper.buildVideoThumbnail(
        videoPath: widget.videoPath,
        width: widget.width,
        height: widget.height,
        isPriority: _isVisible, // Higher priority for visible thumbnails
        fallbackBuilder: widget.fallbackBuilder,
      ),
    );
  }
}

/// A grid item that displays a video thumbnail with lazy loading
/// For use in GridView to display video files
class LazyVideoGridItem extends StatelessWidget {
  final File file;
  final VoidCallback onTap;
  final double width;
  final double height;

  const LazyVideoGridItem({
    Key? key,
    required this.file,
    required this.onTap,
    this.width = 160,
    this.height = 120,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        clipBehavior: Clip.antiAlias,
        elevation: 2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: LazyVideoThumbnail(
                videoPath: file.path,
                width: width,
                height: height,
                fallbackBuilder: () => Container(
                  color: Colors.black12,
                  child: Center(
                    child: Icon(
                      Icons.movie_outlined,
                      size: 48,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                file.path.split('/').last,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              ),
            )
          ],
        ),
      ),
    );
  }
}

/// A list item that displays a video thumbnail with lazy loading
/// For use in ListView to display video files
class LazyVideoListItem extends StatelessWidget {
  final File file;
  final VoidCallback onTap;
  final double thumbnailWidth;
  final double thumbnailHeight;

  const LazyVideoListItem({
    Key? key,
    required this.file,
    required this.onTap,
    this.thumbnailWidth = 120,
    this.thumbnailHeight = 80,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final fileName = file.path.split('/').last;
    final fileExt = fileName.split('.').last.toUpperCase();

    return ListTile(
      onTap: onTap,
      leading: SizedBox(
        width: thumbnailWidth,
        height: thumbnailHeight,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LazyVideoThumbnail(
            videoPath: file.path,
            width: thumbnailWidth,
            height: thumbnailHeight,
            fallbackBuilder: () => Container(
              color: Colors.black12,
              child: Center(
                child: Text(
                  fileExt,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      title: Text(fileName),
      subtitle: FutureBuilder<FileStat>(
        future: file.stat(),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            final fileStat = snapshot.data!;
            final size = _formatFileSize(fileStat.size);
            final modified = _formatDate(fileStat.modified);
            return Text('$size • $modified');
          }
          return const Text('Loading...');
        },
      ),
      trailing: PopupMenuButton(
        itemBuilder: (context) => [
          const PopupMenuItem(
            value: 'play',
            child: Row(
              children: [
                Icon(Icons.play_arrow),
                SizedBox(width: 8),
                Text('Play'),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'info',
            child: Row(
              children: [
                Icon(Icons.info_outline),
                SizedBox(width: 8),
                Text('Properties'),
              ],
            ),
          ),
        ],
        onSelected: (value) {
          if (value == 'play') {
            onTap();
          } else if (value == 'info') {
            // Show file properties dialog
          }
        },
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String _formatDate(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }
}
