import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'dart:collection';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path/path.dart' as path;
import 'package:ffmpeg_helper/ffmpeg_helper.dart';
import 'package:cb_file_manager/helpers/user_preferences.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

// Import the native Windows thumbnail provider
import 'fc_native_video_thumbnail.dart';

/// A simpler implementation of video thumbnail generation using video_thumbnail package
/// and ffmpeg_helper for Windows, with proper error handling and debugging
class VideoThumbnailHelper {
  // LRU cache for file paths - stores mapping of video path to thumbnail path
  static final LinkedHashMap<String, String> _fileCache =
      LinkedHashMap<String, String>();

  // Request queue for limiting concurrent thumbnail generation
  static final _processingQueue = <_ThumbnailRequest>[];
  static final _pendingQueue = <_ThumbnailRequest>[];

  // Maximum number of concurrent FFmpeg processes
  static const int _maxConcurrentProcesses = 2;

  // If we're currently processing the queue
  static bool _isProcessingQueue = false;

  // Priority management
  static const int _visiblePriority =
      100; // Higher priority for visible thumbnails
  static const int _prefetchPriority = 10; // Medium priority for prefetch
  static const int _defaultPriority =
      0; // Default priority for background loading

  // Cache size limits
  static const int _maxFileCacheSize = 500;

  // Settings to control thumbnail quality and size
  static const int thumbnailQuality = 70;
  static const int maxThumbnailSize = 200;

  // Flag to detect Windows platform
  static bool get _isWindows => Platform.isWindows;

  // Flag to check if FFmpeg is initialized
  static bool _ffmpegInitialized = false;

  // Last cleanup timestamp to avoid frequent cleanups
  static DateTime _lastCleanupTime = DateTime.now();

  // Current directory being viewed - used to cancel thumbnails when changing directories
  static String _currentDirectory = '';

  // Flag to enable verbose debugging
  static bool _verboseLogging = false;

  // Path to the cache index file
  static String? _cacheIndexFilePath;

  // Flag to track if the cache is initialized
  static bool _cacheInitialized = false;

  /// Enable or disable verbose logging
  static void setVerboseLogging(bool enabled) {
    _verboseLogging = enabled;
  }

  /// Log a message with optional verbose mode
  static void _log(String message, {bool forceShow = false}) {
    if (_verboseLogging || forceShow) {
      debugPrint(message);
    }
  }

  /// Initialize cache from disk - call this early in app startup
  static Future<void> initializeCache() async {
    if (_cacheInitialized) return;

    await _loadCacheFromDisk();
    _cacheInitialized = true;

    // Start a timer to periodically save cache to disk
    Timer.periodic(const Duration(minutes: 5), (_) {
      _saveCacheToDisk();
    });
  }

  /// Set the current directory - will cancel pending requests for other directories
  static void setCurrentDirectory(String dirPath) {
    if (_currentDirectory == dirPath) return;

    _log(
        'VideoThumbnail: Changing directory from "${_currentDirectory}" to "$dirPath"',
        forceShow: true);
    _currentDirectory = dirPath;

    // Cancel thumbnail generation for files not in this directory
    cancelThumbnailsNotInDirectory(dirPath);
  }

  /// Cancel all pending thumbnails not in the specified directory
  static void cancelThumbnailsNotInDirectory(String dirPath) {
    if (dirPath.isEmpty) return;

    int canceledCount = 0;

    // Filter the pending queue to keep only the current directory files
    final List<_ThumbnailRequest> requestsToRemove = [];

    for (final request in _pendingQueue) {
      final requestDir = path.dirname(request.videoPath);
      if (requestDir != dirPath) {
        if (!request.completer.isCompleted) {
          request.completer.complete(null);
        }
        requestsToRemove.add(request);
        canceledCount++;
      }
    }

    _pendingQueue.removeWhere((req) => requestsToRemove.contains(req));

    _log(
        'VideoThumbnail: Canceled $canceledCount pending thumbnails for other directories',
        forceShow: true);
  }

  /// Initialize the FFmpeg helper, especially important for Windows
  static Future<bool> initializeFFmpeg() async {
    if (_ffmpegInitialized) return true;

    try {
      debugPrint('VideoThumbnailHelper: Initializing FFmpeg...');

      // Initialize the FFmpeg helper - method name has changed in newer version
      await FFMpegHelper.instance.initialize();

      // For Windows, we need to ensure FFmpeg is set up
      if (_isWindows) {
        // Method name has changed in newer version
        final isInstalled = await FFMpegHelper.instance.isFFMpegPresent();
        if (!isInstalled) {
          debugPrint(
              'VideoThumbnailHelper: FFmpeg not installed, downloading...');

          // In newer version, the progress callback signature has changed
          bool success = await FFMpegHelper.instance.setupFFMpegOnWindows(
            onProgress: (progress) {
              // New version uses double instead of FFMpegProgress type
              debugPrint('FFmpeg download progress: ${progress}%');
            },
          );

          if (!success) {
            debugPrint(
                'VideoThumbnailHelper: Failed to setup FFmpeg on Windows');
            return false;
          }

          debugPrint(
              'VideoThumbnailHelper: FFmpeg successfully installed on Windows');
        } else {
          debugPrint(
              'VideoThumbnailHelper: FFmpeg already installed on Windows');
        }
      }

      _ffmpegInitialized = true;
      debugPrint('VideoThumbnailHelper: FFmpeg initialized successfully');
      return true;
    } catch (e, stackTrace) {
      debugPrint('VideoThumbnailHelper: Error initializing FFmpeg: $e');
      debugPrint('VideoThumbnailHelper: Stack trace: $stackTrace');
      return false;
    }
  }

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

  /// Add an item to the file cache with LRU management
  static void _addToFileCache(String key, String value) {
    // First verify that the file actually exists
    final file = File(value);
    if (!file.existsSync()) {
      _log(
          'VideoThumbnail: Warning - Attempted to cache non-existent file: $value');
      return;
    }

    // Remove the item if it already exists to update its position in the LRU order
    _fileCache.remove(key);

    // Check if cache is full, remove oldest item
    if (_fileCache.length >= _maxFileCacheSize) {
      final oldestKey = _fileCache.keys.first;
      _fileCache.remove(oldestKey);
      _log('VideoThumbnail: Removed oldest item from file cache: $oldestKey');
    }

    // Add the new item
    _fileCache[key] = value;
    _log('VideoThumbnail: Added to file cache: $key => $value');
  }

  /// Clean up old temporary thumbnail files
  static Future<void> _cleanupOldTempFiles() async {
    // Only perform cleanup once per hour
    final now = DateTime.now();
    if (now.difference(_lastCleanupTime).inHours < 1) {
      return;
    }

    _lastCleanupTime = now;

    try {
      final tempDir = await getTemporaryDirectory();
      final directory = Directory(tempDir.path);

      final files = directory
          .listSync()
          .whereType<File>()
          .where((file) => path.basename(file.path).startsWith('thumb_'))
          .toList();

      // Keep only recently used thumbnails and delete others
      for (final file in files) {
        if (!_fileCache.values.contains(file.path)) {
          try {
            // Check if file is older than 24 hours
            final stat = await file.stat();
            if (now.difference(stat.modified).inHours > 24) {
              await file.delete();
              debugPrint(
                  'VideoThumbnail: Deleted old temporary file: ${file.path}');
            }
          } catch (e) {
            debugPrint('VideoThumbnail: Error deleting old temp file: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('VideoThumbnail: Error during temp files cleanup: $e');
    }
  }

  /// Process the thumbnail generation queue
  static Future<void> _processQueue() async {
    if (_isProcessingQueue) return;
    _isProcessingQueue = true;

    try {
      while (_processingQueue.length < _maxConcurrentProcesses &&
          _pendingQueue.isNotEmpty) {
        // Sort pending queue by priority (higher first)
        _pendingQueue.sort((a, b) => b.priority.compareTo(a.priority));

        // Take highest priority request
        final request = _pendingQueue.removeAt(0);
        _processingQueue.add(request);

        // Start processing without awaiting (will be handled by completer)
        _processRequest(request).then((_) {
          _processingQueue.remove(request);
          // Continue processing queue
          _processQueue();
        });
      }
    } finally {
      _isProcessingQueue = false;
    }
  }

  /// Process a single thumbnail request
  static Future<void> _processRequest(_ThumbnailRequest request) async {
    try {
      String? thumbnailPath;

      // Check for cache hit first
      thumbnailPath = await _checkCacheForThumbnail(request.videoPath);

      // If not in cache, generate thumbnail
      if (thumbnailPath == null) {
        thumbnailPath = await _generateThumbnailInternal(request.videoPath);
      }

      // Complete the future with result
      request.completer.complete(thumbnailPath);
    } catch (e, stackTrace) {
      debugPrint('VideoThumbnail: Error processing thumbnail request: $e');
      debugPrint('VideoThumbnail: Stack trace: $stackTrace');
      request.completer.completeError(e, stackTrace);
    }
  }

  /// Request a thumbnail generation (adds to queue and returns a Future)
  static Future<String?> _requestThumbnail(String videoPath,
      {int priority = _defaultPriority}) {
    // Create a completer to handle the async result
    final completer = Completer<String?>();

    // Add to pending queue
    _pendingQueue.add(_ThumbnailRequest(
      videoPath: videoPath,
      priority: priority,
      completer: completer,
      timestamp: DateTime.now(),
    ));

    // Start queue processing
    _processQueue();

    return completer.future;
  }

  /// Internal method to generate a thumbnail
  static Future<String?> _generateThumbnailInternal(String videoPath) async {
    // Make sure the video file path is valid and exists
    File videoFile = File(videoPath);
    if (!videoFile.existsSync()) {
      debugPrint(
          'VideoThumbnail: Error - Video file does not exist at path: $videoPath');
      return null;
    }

    try {
      // Generate a unique filename for the thumbnail based on video path
      final thumbnailPath = await _generateThumbnailPath(videoPath);
      debugPrint('VideoThumbnail: Will save thumbnail to: $thumbnailPath');

      // Check if thumbnail already exists
      if (File(thumbnailPath).existsSync()) {
        _addToFileCache(videoPath, thumbnailPath);
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

      // Get timestamp preference from user preferences
      final timestampSeconds =
          await _calculateTimestampFromPercentage(videoPath);
      debugPrint(
          'VideoThumbnail: Using timestamp at $timestampSeconds seconds');
      // Try Windows native thumbnail extraction first (highest priority on Windows)
      if (_isWindows) {
        try {
          debugPrint(
              'VideoThumbnail: Trying Windows native thumbnail extraction');

          // Check if the format is supported by Windows thumbnail API
          if (FcNativeVideoThumbnail.isSupportedFormat(videoPath)) {
            final nativeThumbnailPath =
                await FcNativeVideoThumbnail.generateThumbnail(
              videoPath: videoPath,
              outputPath: thumbnailPath,
              width: maxThumbnailSize,
              format: 'jpg',
              timeSeconds:
                  timestampSeconds, // Pass the timestamp to extract frame at specific time
            );

            if (nativeThumbnailPath != null) {
              _addToFileCache(videoPath, nativeThumbnailPath);
              debugPrint(
                  'VideoThumbnail: Successfully generated thumbnail with Windows native API at timestamp ${timestampSeconds}s: $nativeThumbnailPath');
              return nativeThumbnailPath;
            } else {
              debugPrint(
                  'VideoThumbnail: Windows native thumbnail extraction failed, trying fallback methods');
            }
          } else {
            debugPrint(
                'VideoThumbnail: Format not supported by Windows native thumbnail API, trying fallback methods');
          }
        } catch (e) {
          debugPrint(
              'VideoThumbnail: Error using Windows native thumbnail API: $e, trying fallback methods');
        }
      }

      // Fallback to video_thumbnail package
      debugPrint(
          'VideoThumbnail: Generating thumbnail for: $absoluteVideoPath');

      // Generate the thumbnail using video_thumbnail library
      final thumbnailFile = await VideoThumbnail.thumbnailFile(
        video: absoluteVideoPath,
        thumbnailPath: thumbnailPath,
        imageFormat: ImageFormat.JPEG,
        quality: thumbnailQuality,
        maxHeight: maxThumbnailSize,
        maxWidth: maxThumbnailSize,
        timeMs: timestampSeconds *
            1000, // Convert seconds to milliseconds for video_thumbnail
      );

      if (thumbnailFile != null) {
        _addToFileCache(videoPath, thumbnailFile);
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

      // Occasionally clean up old temp files
      unawaited(_cleanupOldTempFiles());
    } catch (e, stackTrace) {
      debugPrint('VideoThumbnail: Error generating thumbnail: $e');
      debugPrint('VideoThumbnail: Stack trace: $stackTrace');
    }

    return null;
  }

  /// Check if a thumbnail exists in cache
  static Future<String?> _checkCacheForThumbnail(String videoPath) async {
    // First check in-memory cache
    if (_fileCache.containsKey(videoPath)) {
      final cachedPath = _fileCache[videoPath];
      if (cachedPath != null) {
        final file = File(cachedPath);
        if (file.existsSync() && file.lengthSync() > 0) {
          _log('VideoThumbnail: Cache hit for $videoPath at $cachedPath');
          return cachedPath;
        } else {
          // Remove invalid cache entry
          _log('VideoThumbnail: Removing invalid cache entry for $videoPath');
          _fileCache.remove(videoPath);
        }
      }
    }

    // Check if thumbnail file exists in temp directory with expected naming
    try {
      final tempDir = await getTemporaryDirectory();
      final filename = _createCacheFilename(videoPath);
      final expectedPath = path.join(tempDir.path, filename);

      final file = File(expectedPath);
      if (file.existsSync() && file.lengthSync() > 0) {
        _log('VideoThumbnail: Found thumbnail file on disk: $expectedPath');
        // Add to in-memory cache
        _addToFileCache(videoPath, expectedPath);
        return expectedPath;
      }
    } catch (e) {
      _log('VideoThumbnail: Error checking disk cache: $e');
    }

    return null;
  }

  /// Create a consistent filename from a video path
  static String _createCacheFilename(String videoPath) {
    // Generate a consistent hash using MD5
    final bytes = utf8.encode(videoPath);
    final digest = md5.convert(bytes);
    return 'thumb_${digest.toString()}.jpg';
  }

  /// Generate thumbnail path for a video
  static Future<String> _generateThumbnailPath(String videoPath) async {
    final String filename = _createCacheFilename(videoPath);
    final tempDir = await getTemporaryDirectory();
    return path.join(tempDir.path, filename);
  }

  /// Save the in-memory cache to disk for persistence
  static Future<void> _saveCacheToDisk() async {
    try {
      if (_cacheIndexFilePath == null) {
        final tempDir = await getTemporaryDirectory();
        _cacheIndexFilePath =
            path.join(tempDir.path, 'thumbnail_cache_index.json');
      }

      // Convert cache to a serializable format
      final cacheData = <String, String>{};
      for (final entry in _fileCache.entries) {
        cacheData[entry.key] = entry.value;
      }

      // Convert to JSON
      final jsonData = jsonEncode(cacheData);

      // Save to file
      await File(_cacheIndexFilePath!).writeAsString(jsonData);

      _log(
          'VideoThumbnail: Saved cache index with ${_fileCache.length} entries to disk');
    } catch (e) {
      debugPrint('VideoThumbnail: Error saving cache to disk: $e');
    }
  }

  /// Load the cache from disk
  static Future<void> _loadCacheFromDisk() async {
    try {
      // Clear existing cache
      _fileCache.clear();

      if (_cacheIndexFilePath == null) {
        final tempDir = await getTemporaryDirectory();
        _cacheIndexFilePath =
            path.join(tempDir.path, 'thumbnail_cache_index.json');
      }

      final indexFile = File(_cacheIndexFilePath!);
      if (!indexFile.existsSync()) {
        _log(
            'VideoThumbnail: No cache index file found at ${_cacheIndexFilePath}');
        return;
      }

      // Read and parse JSON
      final jsonData = await indexFile.readAsString();
      final cacheData = jsonDecode(jsonData) as Map<String, dynamic>;

      // Verify entries and add valid ones to cache
      int validCount = 0;
      for (final entry in cacheData.entries) {
        final thumbnailPath = entry.value as String;
        final file = File(thumbnailPath);

        if (file.existsSync() && file.lengthSync() > 0) {
          _fileCache[entry.key] = thumbnailPath;
          validCount++;
        }
      }

      _log(
          'VideoThumbnail: Loaded $validCount valid cache entries from disk (out of ${cacheData.length})',
          forceShow: true);
    } catch (e) {
      debugPrint('VideoThumbnail: Error loading cache from disk: $e');
    }
  }

  /// Get an estimated video duration or use a default value
  static Future<int> _getEstimatedVideoDuration(String videoPath) async {
    try {
      // Try to get file size as a rough indicator of video length
      final videoFile = File(videoPath);
      if (await videoFile.exists()) {
        final fileSize = await videoFile.length();

        // Very rough estimate: 1MB ≈ 10 seconds of video (varies greatly by codec)
        // This is just a heuristic and not very accurate
        final estimatedSeconds = (fileSize / (1024 * 1024) * 10).round();
        final clampedDuration =
            estimatedSeconds.clamp(30, 600); // Between 30s and 10min

        debugPrint(
            'VideoThumbnail: Estimated duration based on file size: $clampedDuration seconds');
        return clampedDuration;
      }
    } catch (e) {
      debugPrint('VideoThumbnail: Error estimating duration: $e');
    }

    // Default fallback duration
    return 60; // Assume 1 minute
  }

  /// Calculate timestamp based on percentage and estimated duration
  static Future<int> _calculateTimestampFromPercentage(String videoPath) async {
    // Get user preference for thumbnail position (as percentage)
    final userPrefs = UserPreferences();
    await userPrefs.init();
    final percentage = userPrefs.getVideoThumbnailPercentage();

    // Get an estimated duration
    final estimatedDuration = await _getEstimatedVideoDuration(videoPath);

    // Calculate timestamp based on percentage
    int timestampSeconds = ((percentage / 100) * estimatedDuration).round();

    // Ensure the timestamp is at least 1 second but not beyond estimated duration
    timestampSeconds = timestampSeconds.clamp(1, estimatedDuration - 1);
    debugPrint(
        'VideoThumbnail: Using $percentage% = $timestampSeconds seconds (estimated)');

    return timestampSeconds;
  }

  /// Generate a thumbnail for a video file (public API with queue system)
  static Future<String?> generateThumbnail(String videoPath,
      {bool isPriority = false, bool forceRegenerate = false}) async {
    // Make sure the cache is initialized
    if (!_cacheInitialized) {
      await initializeCache();
    }

    // First check if this is a supported video format
    if (!isSupportedVideoFormat(videoPath)) {
      debugPrint('VideoThumbnail: Unsupported video format: $videoPath');
      return null;
    }

    // Check cache only if not forcing regeneration
    if (!forceRegenerate) {
      // Try to get from cache first
      final cachedPath = await _checkCacheForThumbnail(videoPath);
      if (cachedPath != null) {
        final file = File(cachedPath);
        // Double-check that the file actually exists and is not empty
        if (file.existsSync() && file.lengthSync() > 0) {
          return cachedPath;
        } else {
          debugPrint(
              'VideoThumbnail: Cached thumbnail is invalid, will regenerate');
          // Remove the invalid entry from cache
          _fileCache.remove(videoPath);
        }
      }
    } else {
      debugPrint(
          'VideoThumbnail: Force regenerating thumbnail for: $videoPath');
      // If forcing regeneration, remove any existing entries
      _fileCache.remove(videoPath);
    }

    debugPrint('VideoThumbnail: Requesting thumbnail for: $videoPath');

    // Determine priority level based on importance
    final priority = isPriority ? _visiblePriority : _defaultPriority;

    // Add to queue and get future result
    final result = await _requestThumbnail(videoPath, priority: priority);

    // Save cache to disk after new thumbnails are generated
    _saveCacheToDisk();

    return result;
  }

  /// Generate a thumbnail directly as Uint8List data from file
  static Future<Uint8List?> generateThumbnailData(String videoPath,
      {bool isPriority = false}) async {
    // First check if this is a supported video format
    if (!isSupportedVideoFormat(videoPath)) {
      debugPrint('VideoThumbnail: Unsupported video format: $videoPath');
      return null;
    }

    debugPrint('VideoThumbnail: Generating thumbnail data for: $videoPath');

    try {
      // First get thumbnail file path through cache or generation
      final thumbnailPath =
          await generateThumbnail(videoPath, isPriority: isPriority);

      if (thumbnailPath != null) {
        // Read the thumbnail from file
        try {
          final File thumbnailFile = File(thumbnailPath);
          if (thumbnailFile.existsSync()) {
            final bytes = await thumbnailFile.readAsBytes();
            if (bytes.isNotEmpty) {
              debugPrint(
                  'VideoThumbnail: Successfully loaded thumbnail data from file: ${bytes.length} bytes');
              return bytes;
            }
          }
        } catch (e) {
          debugPrint('VideoThumbnail: Error reading thumbnail file: $e');
        }
      }
    } catch (e, stackTrace) {
      debugPrint('VideoThumbnail: Error generating thumbnail data: $e');
      debugPrint('VideoThumbnail: Stack trace: $stackTrace');
    }

    return null;
  }

  /// Request a thumbnail with prefetch priority (medium priority)
  static Future<String?> prefetchThumbnail(String videoPath) async {
    if (!isSupportedVideoFormat(videoPath)) {
      return null;
    }

    // Use prefetch priority level
    return _requestThumbnail(videoPath, priority: _prefetchPriority);
  }

  /// Build a widget to display a video thumbnail with lazy loading
  static Widget buildVideoThumbnail({
    required String videoPath,
    Widget Function()? fallbackBuilder,
    double width = 200,
    double height = 150,
    BoxFit fit = BoxFit.cover,
    bool isPriority = false,
    bool forceRegenerate = false,
  }) {
    final defaultFallback = () => Container(
          color: Colors.grey[300],
          child: const Center(
            child: Icon(Icons.movie, size: 40, color: Colors.grey),
          ),
        );

    return FutureBuilder<String?>(
      // Pass the isPriority and forceRegenerate parameters to ensure fresh thumbnails
      future: generateThumbnail(videoPath,
          isPriority: isPriority, forceRegenerate: forceRegenerate),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SizedBox(
            width: width,
            height: height,
            child: fallbackBuilder?.call() ?? defaultFallback(),
          );
        }

        final thumbnailPath = snapshot.data;

        if (thumbnailPath == null || !File(thumbnailPath).existsSync()) {
          return SizedBox(
            width: width,
            height: height,
            child: fallbackBuilder?.call() ?? defaultFallback(),
          );
        }

        return SizedBox(
          width: width,
          height: height,
          child: Image.file(
            File(thumbnailPath),
            fit: fit,
            errorBuilder: (context, error, stackTrace) {
              debugPrint('Error loading thumbnail: $error');
              return fallbackBuilder?.call() ?? defaultFallback();
            },
          ),
        );
      },
    );
  }

  /// Clear all caches and queues
  static Future<void> clearCache() async {
    debugPrint('VideoThumbnail: Clearing all thumbnail caches...');

    // Clear in-memory caches
    _fileCache.clear();

    // Cancel and clear all pending requests
    for (final request in _pendingQueue) {
      if (!request.completer.isCompleted) {
        request.completer.complete(null);
      }
    }
    _pendingQueue.clear();

    // Also cancel active processing requests
    for (final request in _processingQueue) {
      if (!request.completer.isCompleted) {
        request.completer.complete(null);
      }
    }
    _processingQueue.clear();

    debugPrint('VideoThumbnail: In-memory caches and queues cleared');

    // Clear Flutter's image cache to ensure complete refresh
    try {
      // This works even if PaintingBinding is null, it won't throw
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      debugPrint('VideoThumbnail: Flutter image cache cleared');
    } catch (e) {
      debugPrint('VideoThumbnail: Error clearing Flutter image cache: $e');
    }

    // Delete all thumbnail files from temporary directory
    try {
      final tempDir = await getTemporaryDirectory();
      final directory = Directory(tempDir.path);

      final thumbnailFiles = directory
          .listSync()
          .whereType<File>()
          .where((file) => path.basename(file.path).startsWith('thumb_'))
          .toList();

      int deletedCount = 0;
      for (final file in thumbnailFiles) {
        try {
          if (await file.exists()) {
            await file.delete();
            deletedCount++;
          }
        } catch (e) {
          debugPrint(
              'VideoThumbnail: Error deleting thumbnail file ${file.path}: $e');
        }
      }

      // Delete the cache index file
      if (_cacheIndexFilePath != null) {
        final indexFile = File(_cacheIndexFilePath!);
        if (await indexFile.exists()) {
          await indexFile.delete();
          debugPrint('VideoThumbnail: Deleted cache index file');
        }
      }

      debugPrint(
          'VideoThumbnail: Deleted $deletedCount thumbnail files from disk cache');
    } catch (e) {
      debugPrint(
          'VideoThumbnail: Error clearing thumbnail files from disk: $e');
    }

    // Update cleanup timestamp
    _lastCleanupTime = DateTime.now();

    // Reset cache initialization flag to force reload
    _cacheInitialized = false;
  }

  /// Clear old cache entries to free up memory (can be called periodically)
  static Future<void> trimCache() async {
    // Keep only the most recent half of the items
    if (_fileCache.length > _maxFileCacheSize / 2) {
      final keysToKeep =
          _fileCache.keys.toList().sublist(_fileCache.length ~/ 2);
      final newFileCache = LinkedHashMap<String, String>();
      for (final key in keysToKeep) {
        newFileCache[key] = _fileCache[key]!;
      }
      _fileCache.clear();
      _fileCache.addAll(newFileCache);
    }

    debugPrint(
        'VideoThumbnail: Cache trimmed - file cache: ${_fileCache.length}');

    // Clean up old thumbnail files
    await _cleanupOldTempFiles();
  }

  /// Cancel all pending thumbnail generation requests that aren't in process yet
  static void cancelPendingRequests() {
    for (final request in _pendingQueue) {
      if (!request.completer.isCompleted) {
        request.completer.complete(null);
      }
    }
    _pendingQueue.clear();
  }

  /// Promote a video path to high priority (for newly visible items)
  static void prioritizeThumbnail(String videoPath) {
    // Find the request in the pending queue and increase its priority
    for (final request in _pendingQueue) {
      if (request.videoPath == videoPath) {
        request.priority = _visiblePriority;
        break;
      }
    }
  }

  /// Check current cache stats and log them - for debugging
  static void logCacheStats() {
    debugPrint('--------- VIDEO THUMBNAIL CACHE STATS ---------',
        wrapWidth: 120);
    debugPrint('File cache size: ${_fileCache.length}/${_maxFileCacheSize}',
        wrapWidth: 120);

    if (_fileCache.isNotEmpty) {
      debugPrint('Sample file cache items (max 5):', wrapWidth: 120);
      int count = 0;
      for (final key in _fileCache.keys) {
        if (count >= 5) break;
        final value = _fileCache[key]!;
        final fileExists = File(value).existsSync() ? "exists" : "missing";
        debugPrint(' - $key => $value ($fileExists)', wrapWidth: 120);
        count++;
      }
    } else {
      debugPrint('File cache is empty', wrapWidth: 120);
    }

    debugPrint('Current directory: $_currentDirectory', wrapWidth: 120);
    debugPrint('Pending queue size: ${_pendingQueue.length}', wrapWidth: 120);
    debugPrint('Processing queue size: ${_processingQueue.length}',
        wrapWidth: 120);
    debugPrint('-----------------------------------------------',
        wrapWidth: 120);
  }

  /// Verify the thumbnail in cache exists and is valid
  static Future<bool> verifyThumbnailCache(String videoPath) async {
    bool fileInCache = false;
    bool fileExists = false;
    bool thumbnailValid = false;

    // Check if in file cache
    if (_fileCache.containsKey(videoPath)) {
      fileInCache = true;
      final cachedPath = _fileCache[videoPath];
      if (cachedPath != null) {
        final file = File(cachedPath);
        fileExists = file.existsSync();
        if (fileExists) {
          // Check if file has valid content
          try {
            final bytes = await file.readAsBytes();
            thumbnailValid =
                bytes.length > 100; // Very basic check that it's not empty
          } catch (e) {
            debugPrint('VideoThumbnail: Error reading cached file: $e');
          }
        }
      }
    }

    // Print debug info
    debugPrint('VideoThumbnail: Cache verification for: $videoPath');
    debugPrint(' - In file cache: $fileInCache');
    if (fileInCache) {
      debugPrint(' - File exists: $fileExists');
      debugPrint(' - Thumbnail valid: $thumbnailValid');
      debugPrint(' - Path: ${_fileCache[videoPath]}');
    }

    // Return true if thumbnail is in cache and valid
    return fileInCache && fileExists && thumbnailValid;
  }
}

/// Class representing a thumbnail generation request in the queue
class _ThumbnailRequest {
  final String videoPath;
  int priority;
  final Completer<String?> completer;
  final DateTime timestamp;

  _ThumbnailRequest({
    required this.videoPath,
    required this.priority,
    required this.completer,
    required this.timestamp,
  });
}
