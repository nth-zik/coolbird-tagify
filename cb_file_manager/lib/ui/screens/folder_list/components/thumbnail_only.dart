import 'package:flutter/material.dart';
import 'dart:io'; // Import dart:io for FileSystemEntity
import 'package:cb_file_manager/ui/widgets/thumbnail_loader.dart';
import 'package:cb_file_manager/helpers/files/file_type_helper.dart'; // Import the helper
import 'package:path/path.dart' as p;

/// A widget that displays only the thumbnail of a file item.
/// This widget is designed to be constant and not rebuild on selection changes.
class ThumbnailOnly extends StatefulWidget {
  final FileSystemEntity file;
  final double iconSize;

  const ThumbnailOnly({
    Key? key,
    required this.file,
    this.iconSize = 48.0,
  }) : super(key: key);

  @override
  State<ThumbnailOnly> createState() => _ThumbnailOnlyState();
}

class _ThumbnailOnlyState extends State<ThumbnailOnly>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    final extension = p.extension(widget.file.path);
    final isVideo = FileTypeHelper.isVideo(extension);
    final isImage = FileTypeHelper.isImage(extension);
    final fileType = FileTypeHelper.getFileType(extension);
    final icon = FileTypeHelper.getIconForFileType(fileType);

    return RepaintBoundary(
      child: ThumbnailLoader(
        key: ValueKey('thumb-loader-${widget.file.path}'),
        filePath: widget.file.path,
        isVideo: isVideo,
        isImage: isImage,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        isPriority: true,
        borderRadius: BorderRadius.circular(8.0),
        showLoadingIndicator: true, // Enable skeleton loading
        fallbackBuilder: () => Icon(
          icon,
          size: widget.iconSize,
          color: Theme.of(context).colorScheme.secondary,
        ),
      ),
    );
  }
}
