import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path/path.dart' as path;

/// A simpler implementation of video thumbnail generation using video_thumbnail package
/// Optimized for Windows with proper error handling and debugging
class VideoThumbnailHelper {
  // Cache to store already generated thumbnails
  static final Map<String, String> _fileCache = {};
  static final Map<String, Uint8List> _memoryCache = {};

  // Settings to control thumbnail quality and size
  static const int thumbnailQuality = 70;
  static const int maxThumbnailSize = 200;

  // Flag to detect Windows platform
  static bool get _isWindows => Platform.isWindows;

  /// Check if a file is likely to be a supported video format
  static bool isSupportedVideoFormat(String filePath) {
    final lowercasePath = filePath.toLowerCase();

    // List of common video extensions that are typically supported
    final supportedExtensions = [
      '.mp4',
      '.mov',
      '.avi',
      '.mkv',
      '.wmv',
      '.flv',
      '.webm',
      '.mpg',
      '.mpeg',
      '.m4v',
      '.3gp'
    ];

    return supportedExtensions.any((ext) => lowercasePath.endsWith(ext));
  }

  /// Generate a thumbnail for a video file and return the path to the thumbnail
  static Future<String?> generateThumbnail(String videoPath) async {
    // First check if this is a supported video format
    if (!isSupportedVideoFormat(videoPath)) {
      debugPrint('VideoThumbnail: Unsupported video format: $videoPath');
      return null;
    }

    debugPrint('VideoThumbnail: Generating thumbnail for: $videoPath');

    // Check if the thumbnail is already in the cache
    if (_fileCache.containsKey(videoPath)) {
      final cachedPath = _fileCache[videoPath];
      if (cachedPath != null && File(cachedPath).existsSync()) {
        debugPrint('VideoThumbnail: Using cached thumbnail at: $cachedPath');
        return cachedPath;
      } else {
        _fileCache.remove(videoPath);
      }
    }

    // Make sure the video file path is valid and exists
    File videoFile = File(videoPath);
    if (!videoFile.existsSync()) {
      debugPrint(
          'VideoThumbnail: Error - Video file does not exist at path: $videoPath');
      return null;
    }

    try {
      // Generate a unique filename for the thumbnail based on video path
      final String uniqueId = videoPath.hashCode.toString();
      final tempDir = await getTemporaryDirectory();
      final thumbnailPath = path.join(tempDir.path, 'thumb_$uniqueId.jpg');
      debugPrint('VideoThumbnail: Will save thumbnail to: $thumbnailPath');

      // Check if thumbnail already exists
      if (File(thumbnailPath).existsSync()) {
        _fileCache[videoPath] = thumbnailPath;
        debugPrint(
            'VideoThumbnail: Using existing thumbnail at: $thumbnailPath');
        return thumbnailPath;
      }

      // Get absolute path and fix path formatting for Windows
      String absoluteVideoPath = videoFile.absolute.path;
      if (_isWindows) {
        // Ensure Windows paths use the correct format
        absoluteVideoPath = absoluteVideoPath.replaceAll('\\', '/');
        debugPrint(
            'VideoThumbnail: Windows path formatted: $absoluteVideoPath');
      }

      debugPrint(
          'VideoThumbnail: Generating thumbnail for: $absoluteVideoPath');

      // Generate the thumbnail
      final thumbnailFile = await VideoThumbnail.thumbnailFile(
        video: absoluteVideoPath,
        thumbnailPath: thumbnailPath,
        imageFormat: ImageFormat.JPEG,
        quality: thumbnailQuality,
        maxHeight: maxThumbnailSize,
        maxWidth: maxThumbnailSize,
      );

      if (thumbnailFile != null) {
        _fileCache[videoPath] = thumbnailFile;
        debugPrint(
            'VideoThumbnail: Successfully generated thumbnail at: $thumbnailFile');

        // Verify the thumbnail was actually created
        if (File(thumbnailFile).existsSync()) {
          return thumbnailFile;
        } else {
          debugPrint(
              'VideoThumbnail: Warning - Thumbnail file reported as created but doesn\'t exist');
          return null;
        }
      } else {
        debugPrint('VideoThumbnail: Thumbnail generation returned null');
      }
    } catch (e, stackTrace) {
      debugPrint('VideoThumbnail: Error generating thumbnail: $e');
      debugPrint('VideoThumbnail: Stack trace: $stackTrace');
    }

    return null;
  }

  /// Generate a thumbnail directly as memory data
  static Future<Uint8List?> generateThumbnailData(String videoPath) async {
    // First check if this is a supported video format
    if (!isSupportedVideoFormat(videoPath)) {
      debugPrint('VideoThumbnail: Unsupported video format: $videoPath');
      return null;
    }

    debugPrint('VideoThumbnail: Generating thumbnail data for: $videoPath');

    // Check if the thumbnail is already in memory cache
    if (_memoryCache.containsKey(videoPath)) {
      debugPrint('VideoThumbnail: Using memory cached thumbnail');
      return _memoryCache[videoPath];
    }

    // Make sure the video file path is valid and exists
    File videoFile = File(videoPath);
    if (!videoFile.existsSync()) {
      debugPrint(
          'VideoThumbnail: Error - Video file does not exist at path: $videoPath');
      return null;
    }

    try {
      // For Windows, use a two-step approach which is more reliable
      if (_isWindows) {
        // Step 1: Generate file-based thumbnail
        final thumbnailPath = await generateThumbnail(videoPath);
        if (thumbnailPath != null) {
          // Step 2: Read the thumbnail into memory
          try {
            final File thumbnailFile = File(thumbnailPath);
            if (thumbnailFile.existsSync()) {
              final bytes = await thumbnailFile.readAsBytes();
              if (bytes.isNotEmpty) {
                _memoryCache[videoPath] = bytes;
                debugPrint(
                    'VideoThumbnail: Successfully loaded thumbnail from file: ${bytes.length} bytes');
                return bytes;
              }
            }
          } catch (e) {
            debugPrint('VideoThumbnail: Error reading thumbnail file: $e');
          }
        }
      }

      // Direct memory approach (fallback or for non-Windows platforms)
      debugPrint('VideoThumbnail: Trying direct memory approach');

      // Get absolute path and fix path formatting for Windows
      String absoluteVideoPath = videoFile.absolute.path;
      if (_isWindows) {
        absoluteVideoPath = absoluteVideoPath.replaceAll('\\', '/');
      }

      final uint8list = await VideoThumbnail.thumbnailData(
        video: absoluteVideoPath,
        imageFormat: ImageFormat.JPEG,
        quality: thumbnailQuality,
        maxHeight: maxThumbnailSize,
        maxWidth: maxThumbnailSize,
      );

      if (uint8list != null && uint8list.isNotEmpty) {
        debugPrint(
            'VideoThumbnail: Successfully generated thumbnail data of size: ${uint8list.length} bytes');
        _memoryCache[videoPath] = uint8list;
        return uint8list;
      } else {
        debugPrint(
            'VideoThumbnail: Thumbnail data generation returned null or empty');
      }
    } catch (e, stackTrace) {
      debugPrint('VideoThumbnail: Error generating thumbnail data: $e');
      debugPrint('VideoThumbnail: Stack trace: $stackTrace');
    }

    return null;
  }

  /// Build a widget to display a video thumbnail
  static Widget buildVideoThumbnail({
    required String videoPath,
    double width = 300,
    double height = 300,
    required Widget Function() fallbackBuilder,
  }) {
    debugPrint('VideoThumbnail: Building thumbnail widget for: $videoPath');

    return FutureBuilder<Uint8List?>(
      future: generateThumbnailData(videoPath),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          if (snapshot.hasData &&
              snapshot.data != null &&
              snapshot.data!.isNotEmpty) {
            debugPrint('VideoThumbnail: Thumbnail loaded successfully');
            return Image.memory(
              snapshot.data!,
              width: width,
              height: height,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                debugPrint(
                    'VideoThumbnail: Error displaying thumbnail: $error');
                return fallbackBuilder();
              },
            );
          } else if (snapshot.hasError) {
            debugPrint(
                'VideoThumbnail: Error in FutureBuilder: ${snapshot.error}');
          } else {
            debugPrint('VideoThumbnail: No thumbnail data available');
          }
        } else if (snapshot.connectionState == ConnectionState.waiting) {
          debugPrint('VideoThumbnail: Waiting for thumbnail...');
        }

        // Show fallback while loading or if error occurs
        return Container(
          width: width,
          height: height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              fallbackBuilder(),
              if (snapshot.connectionState == ConnectionState.waiting)
                Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  /// Clear all caches
  static void clearCache() {
    _fileCache.clear();
    _memoryCache.clear();
    debugPrint('VideoThumbnail: All caches cleared');
  }
}
