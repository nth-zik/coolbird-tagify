import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cb_file_manager/ui/screens/media_gallery/video_gallery_screen.dart';
import 'package:cb_file_manager/ui/screens/media_gallery/image_viewer_screen.dart';
import 'package:cb_file_manager/ui/dialogs/open_with_dialog.dart';
import 'package:cb_file_manager/helpers/files/external_app_helper.dart';
import 'package:cb_file_manager/helpers/media/video_thumbnail_helper.dart';
import 'package:cb_file_manager/ui/utils/file_type_utils.dart';
import 'package:cb_file_manager/ui/screens/folder_list/folder_list_bloc.dart';

/// Handles file operations such as opening files with appropriate viewers
class FileOperationsHandler {
  /// Handle file tap - opens the file with the appropriate viewer based on file type
  static void onFileTap({
    required BuildContext context,
    required File file,
    required FolderListBloc folderListBloc,
    String? currentFilter,
    String? currentSearchTag,
  }) {
    // Stop any ongoing thumbnail processing when opening a file
    VideoThumbnailHelper.stopAllProcessing();

    // Check file type using utility
    final isVideo = FileTypeUtils.isVideoFile(file.path);
    final isImage = FileTypeUtils.isImageFile(file.path);

    // Open file based on file type
    if (isVideo) {
      // Open video in video player (fullscreen route on root navigator)
      Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (context) => VideoPlayerFullScreen(file: file),
        ),
      );
    } else if (isImage) {
      // Get all image files in the same directory for gallery navigation
      List<File> imageFiles = [];
      int initialIndex = 0;

      // Only process this if we're showing the folder contents (not search results)
      if (currentFilter == null &&
          currentSearchTag == null &&
          folderListBloc.state.files.isNotEmpty) {
        imageFiles = folderListBloc.state.files.whereType<File>().where((f) {
          return FileTypeUtils.isImageFile(f.path);
        }).toList();

        // Find the index of the current file in the imageFiles list
        initialIndex = imageFiles.indexWhere((f) => f.path == file.path);
        if (initialIndex < 0) initialIndex = 0;
      }

      // Open image in our enhanced image viewer with gallery support
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ImageViewerScreen(
            file: file,
            imageFiles: imageFiles.isNotEmpty ? imageFiles : null,
            initialIndex: initialIndex,
          ),
        ),
      );
    } else {
      // For other file types, open with external app
      // First try to open with the default app
      ExternalAppHelper.openFileWithApp(file.path, 'shell_open')
          .then((success) {
        if (!success && context.mounted) {
          // If that fails, show the open with dialog
          showDialog(
            context: context,
            builder: (context) => OpenWithDialog(filePath: file.path),
          );
        }
      });
    }
  }
}
