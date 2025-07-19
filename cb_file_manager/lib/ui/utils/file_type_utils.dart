import 'dart:io';

/// Utility class for checking file types
class FileTypeUtils {
  /// Check if a file is an image based on its extension
  static bool isImageFile(String filePath) {
    final fileName = filePath.split('/').last.toLowerCase();
    return fileName.endsWith('.jpg') ||
        fileName.endsWith('.jpeg') ||
        fileName.endsWith('.png') ||
        fileName.endsWith('.gif') ||
        fileName.endsWith('.bmp') ||
        fileName.endsWith('.webp') ||
        fileName.endsWith('.tiff') ||
        fileName.endsWith('.tif') ||
        fileName.endsWith('.svg');
  }

  /// Check if a file is a video based on its extension
  static bool isVideoFile(String filePath) {
    final fileName = filePath.split('/').last.toLowerCase();
    return fileName.endsWith('.mp4') ||
        fileName.endsWith('.avi') ||
        fileName.endsWith('.mkv') ||
        fileName.endsWith('.mov') ||
        fileName.endsWith('.wmv') ||
        fileName.endsWith('.flv') ||
        fileName.endsWith('.webm') ||
        fileName.endsWith('.m4v') ||
        fileName.endsWith('.3gp') ||
        fileName.endsWith('.ogv');
  }

  /// Check if a file is an image or video (media file)
  static bool isMediaFile(String filePath) {
    return isImageFile(filePath) || isVideoFile(filePath);
  }

  /// Check if a file is an audio file
  static bool isAudioFile(String filePath) {
    final fileName = filePath.split('/').last.toLowerCase();
    return fileName.endsWith('.mp3') ||
        fileName.endsWith('.wav') ||
        fileName.endsWith('.flac') ||
        fileName.endsWith('.aac') ||
        fileName.endsWith('.ogg') ||
        fileName.endsWith('.wma') ||
        fileName.endsWith('.m4a');
  }

  /// Get the file extension from a path
  static String getFileExtension(String filePath) {
    final fileName = filePath.split('/').last;
    final lastDotIndex = fileName.lastIndexOf('.');
    if (lastDotIndex == -1) return '';
    return fileName.substring(lastDotIndex + 1).toLowerCase();
  }

  /// Get the file name without extension
  static String getFileNameWithoutExtension(String filePath) {
    final fileName = filePath.split('/').last;
    final lastDotIndex = fileName.lastIndexOf('.');
    if (lastDotIndex == -1) return fileName;
    return fileName.substring(0, lastDotIndex);
  }

  /// Check if a file is a document
  static bool isDocumentFile(String filePath) {
    final fileName = filePath.split('/').last.toLowerCase();
    return fileName.endsWith('.pdf') ||
        fileName.endsWith('.doc') ||
        fileName.endsWith('.docx') ||
        fileName.endsWith('.txt') ||
        fileName.endsWith('.rtf') ||
        fileName.endsWith('.odt') ||
        fileName.endsWith('.pages');
  }

  /// Check if a file is a spreadsheet
  static bool isSpreadsheetFile(String filePath) {
    final fileName = filePath.split('/').last.toLowerCase();
    return fileName.endsWith('.xls') ||
        fileName.endsWith('.xlsx') ||
        fileName.endsWith('.csv') ||
        fileName.endsWith('.ods') ||
        fileName.endsWith('.numbers');
  }

  /// Check if a file is a presentation
  static bool isPresentationFile(String filePath) {
    final fileName = filePath.split('/').last.toLowerCase();
    return fileName.endsWith('.ppt') ||
        fileName.endsWith('.pptx') ||
        fileName.endsWith('.odp') ||
        fileName.endsWith('.key');
  }

  /// Check if a file is an archive/compressed file
  static bool isArchiveFile(String filePath) {
    final fileName = filePath.split('/').last.toLowerCase();
    return fileName.endsWith('.zip') ||
        fileName.endsWith('.rar') ||
        fileName.endsWith('.7z') ||
        fileName.endsWith('.tar') ||
        fileName.endsWith('.gz') ||
        fileName.endsWith('.bz2');
  }

  /// Get the file type category
  static String getFileTypeCategory(String filePath) {
    if (isImageFile(filePath)) return 'image';
    if (isVideoFile(filePath)) return 'video';
    if (isAudioFile(filePath)) return 'audio';
    if (isDocumentFile(filePath)) return 'document';
    if (isSpreadsheetFile(filePath)) return 'spreadsheet';
    if (isPresentationFile(filePath)) return 'presentation';
    if (isArchiveFile(filePath)) return 'archive';
    return 'other';
  }

  // Get human-readable file type label
  static String getFileTypeLabel(String extension) {
    if (extension.isEmpty) return 'Tệp tin';

    // Remove the dot if present
    if (extension.startsWith('.')) {
      extension = extension.substring(1);
    }

    final upperExtension = extension.toUpperCase();

    switch (upperExtension) {
      case 'JPG':
      case 'JPEG':
        return 'Ảnh JPEG';
      case 'PNG':
        return 'Ảnh PNG';
      case 'GIF':
        return 'Ảnh GIF';
      case 'BMP':
        return 'Ảnh BMP';
      case 'TIFF':
        return 'Ảnh TIFF';
      case 'WEBP':
        return 'Ảnh WebP';
      case 'SVG':
        return 'Ảnh SVG';
      case 'MP4':
        return 'Video MP4';
      case 'AVI':
        return 'Video AVI';
      case 'MOV':
        return 'Video MOV';
      case 'WMV':
        return 'Video WMV';
      case 'FLV':
        return 'Video FLV';
      case 'MKV':
        return 'Video MKV';
      case 'MP3':
        return 'Âm thanh MP3';
      case 'WAV':
        return 'Âm thanh WAV';
      case 'AAC':
        return 'Âm thanh AAC';
      case 'FLAC':
        return 'Âm thanh FLAC';
      case 'OGG':
        return 'Âm thanh OGG';
      case 'PDF':
        return 'Tài liệu PDF';
      case 'DOCX':
      case 'DOC':
        return 'Tài liệu Word';
      case 'XLSX':
      case 'XLS':
        return 'Bảng tính Excel';
      case 'PPTX':
      case 'PPT':
        return 'Bài thuyết trình PowerPoint';
      case 'TXT':
        return 'Tệp văn bản';
      case 'RTF':
        return 'Tài liệu RTF';
      case 'ZIP':
        return 'Tệp nén ZIP';
      case 'RAR':
        return 'Tệp nén RAR';
      case '7Z':
        return 'Tệp nén 7Z';
      default:
        return 'Tệp $upperExtension';
    }
  }
}
