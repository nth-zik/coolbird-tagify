import 'package:flutter/material.dart';
import 'package:remixicon/remixicon.dart' as remix;
import 'package:cb_file_manager/ui/utils/file_type_utils.dart';

enum FileType {
  image,
  video,
  audio,
  document,
  pdf,
  archive,
  code,
  spreadsheet,
  presentation,
  text,
  apk,
  unknown
}

class FileTypeHelper {
  // Check if the file is an image based on extension
  static bool isImage(String extension) {
    return FileTypeUtils.isImageFile('file$extension');
  }

  // Check if the file is a video based on extension
  static bool isVideo(String extension) {
    return FileTypeUtils.isVideoFile('file$extension');
  }

  // Check if the file is an audio based on extension
  static bool isAudio(String extension) {
    return FileTypeUtils.isAudioFile('file$extension');
  }

  // Check if the file is a document based on extension
  static bool isDocument(String extension) {
    return FileTypeUtils.isDocumentFile('file$extension');
  }

  // Get file type based on extension
  static FileType getFileType(String extension) {
    if (extension.isEmpty) return FileType.unknown;

    final lowercaseExt = extension.toLowerCase();

    if (isImage(lowercaseExt)) {
      return FileType.image;
    } else if (isVideo(lowercaseExt)) {
      return FileType.video;
    } else if (isAudio(lowercaseExt)) {
      return FileType.audio;
    } else if (isDocument(lowercaseExt)) {
      return FileType.document;
    } else if (lowercaseExt == '.pdf') {
      return FileType.pdf;
    } else if (['.zip', '.rar', '.7z', '.tar', '.gz'].contains(lowercaseExt)) {
      return FileType.archive;
    } else if (['.xls', '.xlsx', '.csv', '.ods'].contains(lowercaseExt)) {
      return FileType.spreadsheet;
    } else if (['.ppt', '.pptx', '.odp'].contains(lowercaseExt)) {
      return FileType.presentation;
    } else if (['.txt', '.md', '.json', '.xml'].contains(lowercaseExt)) {
      return FileType.text;
    } else if ([
      '.js',
      '.html',
      '.css',
      '.py',
      '.java',
      '.c',
      '.cpp',
      '.h',
      '.cs',
      '.php',
      '.rb',
      '.dart',
      '.swift',
      '.kt'
    ].contains(lowercaseExt)) {
      return FileType.code;
    } else if (lowercaseExt == '.apk') {
      return FileType.apk;
    } else if ([
      '.aab',
      '.ipa',
      '.exe',
      '.msi',
      '.deb',
      '.rpm',
      '.dmg',
    ].contains(lowercaseExt)) {
      // Add executable/app package formats
      return FileType
          .unknown; // We still categorize as unknown but they will be shown
    }

    // Return unknown for ANY file extension, never hide files
    return FileType.unknown;
  }

  // Get icon for file type
  static IconData getIconForFileType(FileType type) {
    switch (type) {
      case FileType.image:
        return remix.Remix.image_line;
      case FileType.video:
        return remix.Remix.video_line;
      case FileType.audio:
        return remix.Remix.music_2_line;
      case FileType.document:
        return remix.Remix.file_text_line;
      case FileType.pdf:
        return remix.Remix.file_3_line;
      case FileType.archive:
        return remix.Remix.archive_2_line;
      case FileType.code:
        return remix.Remix.code_line;
      case FileType.spreadsheet:
        return remix.Remix.grid_line;
      case FileType.presentation:
        return remix.Remix.computer_line;
      case FileType.text:
        return remix.Remix.file_text_line;
      case FileType.apk:
        return remix.Remix.smartphone_line;
      case FileType.unknown:
      default:
        return remix.Remix.file_3_line;
    }
  }

  // Get color for file type
  static Color getColorForFileType(FileType type) {
    switch (type) {
      case FileType.image:
        return Colors.green;
      case FileType.video:
        return Colors.red;
      case FileType.audio:
        return Colors.blue;
      case FileType.document:
        return Colors.indigo;
      case FileType.pdf:
        return Colors.red.shade700;
      case FileType.archive:
        return Colors.amber.shade700;
      case FileType.code:
        return Colors.teal;
      case FileType.spreadsheet:
        return Colors.green.shade700;
      case FileType.presentation:
        return Colors.orange;
      case FileType.text:
        return Colors.blueGrey;
      case FileType.apk:
        return Colors.green;
      case FileType.unknown:
      default:
        return Colors.grey;
    }
  }
}
