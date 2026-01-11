import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/objectbox/video_library.dart';
import '../models/objectbox/video_library_config.dart';
import '../models/objectbox/video_library_file.dart';
import '../models/objectbox/objectbox_database_provider.dart';
import '../objectbox.g.dart'; // Import generated ObjectBox code
import '../helpers/core/filesystem_utils.dart';
import '../helpers/tags/tag_manager.dart';
import 'package:path/path.dart' as path;

/// Service class for managing video libraries and their file associations
class VideoLibraryService {
  static final VideoLibraryService _instance = VideoLibraryService._internal();

  factory VideoLibraryService() => _instance;

  VideoLibraryService._internal();

  final ObjectBoxDatabaseProvider _dbProvider = ObjectBoxDatabaseProvider();
  Store? _store;
  Completer<Store>? _storeCompleter;

  Future<Store> _getStore() async {
    // If store is already initialized, return it immediately
    if (_store != null) {
      return _store!;
    }

    // If initialization is in progress, wait for it
    if (_storeCompleter != null) {
      return await _storeCompleter!.future;
    }

    // Start initialization
    _storeCompleter = Completer<Store>();
    try {
      await _dbProvider.initialize();
      _store = _dbProvider.getStore();
      _storeCompleter!.complete(_store!);
      return _store!;
    } catch (e) {
      _storeCompleter!.completeError(e);
      _storeCompleter = null; // Reset on error to allow retry
      rethrow;
    }
  }

  /// Initialize the service
  Future<void> initialize() async {
    debugPrint('VideoLibraryService: Initializing');
    _store = await _getStore();
  }

  /// Get all video libraries
  Future<List<VideoLibrary>> getAllLibraries() async {
    try {
      final store = await _getStore();
      final box = store.box<VideoLibrary>();
      return box.getAll();
    } catch (e) {
      debugPrint('Error getting all video libraries: $e');
      return [];
    }
  }

  /// Get video library by ID
  Future<VideoLibrary?> getLibraryById(int id) async {
    try {
      final store = await _getStore();
      final box = store.box<VideoLibrary>();
      return box.get(id);
    } catch (e) {
      debugPrint('Error getting video library by ID: $e');
      return null;
    }
  }

  /// Create a new video library
  Future<VideoLibrary?> createLibrary({
    required String name,
    String? description,
    String? coverImagePath,
    String? colorTheme,
    List<String>? directories,
    VideoLibraryConfig? config,
  }) async {
    try {
      final store = await _getStore();
      final libraryBox = store.box<VideoLibrary>();
      final configBox = store.box<VideoLibraryConfig>();

      // Create library
      final library = VideoLibrary(
        name: name,
        description: description,
        coverImagePath: coverImagePath,
        colorTheme: colorTheme,
      );

      final libraryId = libraryBox.put(library);
      library.id = libraryId;

      // Create config
      final libraryConfig = config ??
          VideoLibraryConfig(
            videoLibraryId: libraryId,
            directories: directories?.join(',') ?? '',
          );

      if (config == null) {
        libraryConfig.videoLibraryId = libraryId;
      }

      configBox.put(libraryConfig);

      debugPrint('Created video library: ${library.name} (ID: $libraryId)');
      return library;
    } catch (e) {
      debugPrint('Error creating video library: $e');
      return null;
    }
  }

  /// Update an existing video library
  Future<bool> updateLibrary(VideoLibrary library) async {
    try {
      final store = await _getStore();
      final box = store.box<VideoLibrary>();
      library.updateModifiedTime();
      box.put(library);
      debugPrint('Updated video library: ${library.name}');
      return true;
    } catch (e) {
      debugPrint('Error updating video library: $e');
      return false;
    }
  }

  /// Delete a video library and all its file associations
  Future<bool> deleteLibrary(int libraryId) async {
    try {
      final store = await _getStore();
      final libraryBox = store.box<VideoLibrary>();
      final configBox = store.box<VideoLibraryConfig>();
      final fileBox = store.box<VideoLibraryFile>();

      // Delete all associated files
      final fileQuery = fileBox
          .query(VideoLibraryFile_.videoLibraryId.equals(libraryId))
          .build();
      final filesToDelete = fileQuery.find();
      fileQuery.close();

      for (final file in filesToDelete) {
        fileBox.remove(file.id);
      }

      // Delete config
      final configQuery = configBox
          .query(VideoLibraryConfig_.videoLibraryId.equals(libraryId))
          .build();
      final configs = configQuery.find();
      configQuery.close();

      for (final config in configs) {
        configBox.remove(config.id);
      }

      // Delete library
      libraryBox.remove(libraryId);

      debugPrint('Deleted video library ID: $libraryId');
      return true;
    } catch (e) {
      debugPrint('Error deleting video library: $e');
      return false;
    }
  }

  /// Get all files in a video library (from directories and manual additions)
  Future<List<String>> getLibraryFiles(int libraryId) async {
    try {
      final config = await getLibraryConfig(libraryId);
      if (config == null) return [];

      final Set<String> allFiles = {};

      // Get files from directories
      if (config.directoriesList.isNotEmpty) {
        for (final dir in config.directoriesList) {
          final dirPath = dir.trim();
          if (dirPath.isEmpty) continue;

          final directory = Directory(dirPath);
          if (!directory.existsSync()) continue;

          final files = await getAllVideos(
            dirPath,
            recursive: config.includeSubdirectories,
          );

          allFiles.addAll(files.map((f) => f.path));
        }
      }

      // Get manually added files
      final store = await _getStore();
      final fileBox = store.box<VideoLibraryFile>();
      final query = fileBox
          .query(VideoLibraryFile_.videoLibraryId.equals(libraryId))
          .build();
      final manualFiles = query.find();
      query.close();

      allFiles.addAll(manualFiles.map((f) => f.filePath));

      return allFiles.toList();
    } catch (e) {
      debugPrint('Error getting library files: $e');
      return [];
    }
  }

  /// Add a single file to a library (manual addition)
  Future<bool> addFileToLibrary(int libraryId, String filePath,
      {String? caption}) async {
    try {
      final store = await _getStore();
      final box = store.box<VideoLibraryFile>();

      // Check if already exists
      final query = box
          .query(VideoLibraryFile_.videoLibraryId
              .equals(libraryId)
              .and(VideoLibraryFile_.filePath.equals(filePath)))
          .build();
      final existing = query.findFirst();
      query.close();

      if (existing != null) {
        debugPrint('File already in library: $filePath');
        return true;
      }

      final libraryFile = VideoLibraryFile(
        videoLibraryId: libraryId,
        filePath: filePath,
        caption: caption,
      );

      box.put(libraryFile);

      // Update library modified time
      final library = await getLibraryById(libraryId);
      if (library != null) {
        await updateLibrary(library);
      }

      debugPrint('Added file to library: $filePath');
      return true;
    } catch (e) {
      debugPrint('Error adding file to library: $e');
      return false;
    }
  }

  /// Add multiple files to a library
  Future<int> addFilesToLibrary(int libraryId, List<String> filePaths) async {
    int successCount = 0;
    for (final filePath in filePaths) {
      final success = await addFileToLibrary(libraryId, filePath);
      if (success) successCount++;
    }
    return successCount;
  }

  /// Add all videos from a folder to a library
  Future<int> addFolderToLibrary(int libraryId, String folderPath,
      {bool recursive = true}) async {
    try {
      final videos = await getAllVideos(folderPath, recursive: recursive);
      return await addFilesToLibrary(
          libraryId, videos.map((f) => f.path).toList());
    } catch (e) {
      debugPrint('Error adding folder to library: $e');
      return 0;
    }
  }

  /// Remove a file from a library
  Future<bool> removeFileFromLibrary(int libraryId, String filePath) async {
    try {
      final store = await _getStore();
      final box = store.box<VideoLibraryFile>();

      final query = box
          .query(VideoLibraryFile_.videoLibraryId
              .equals(libraryId)
              .and(VideoLibraryFile_.filePath.equals(filePath)))
          .build();
      final file = query.findFirst();
      query.close();

      if (file == null) return false;

      box.remove(file.id);

      // Update library modified time
      final library = await getLibraryById(libraryId);
      if (library != null) {
        await updateLibrary(library);
      }

      debugPrint('Removed file from library: $filePath');
      return true;
    } catch (e) {
      debugPrint('Error removing file from library: $e');
      return false;
    }
  }

  /// Check if a file is in a library
  Future<bool> isFileInLibrary(int libraryId, String filePath) async {
    try {
      final store = await _getStore();
      final box = store.box<VideoLibraryFile>();

      final query = box
          .query(VideoLibraryFile_.videoLibraryId
              .equals(libraryId)
              .and(VideoLibraryFile_.filePath.equals(filePath)))
          .build();
      final result = query.findFirst();
      query.close();

      return result != null;
    } catch (e) {
      debugPrint('Error checking if file in library: $e');
      return false;
    }
  }

  /// Get video library configuration
  Future<VideoLibraryConfig?> getLibraryConfig(int libraryId) async {
    try {
      final store = await _getStore();
      final box = store.box<VideoLibraryConfig>();

      final query = box
          .query(VideoLibraryConfig_.videoLibraryId.equals(libraryId))
          .build();
      final config = query.findFirst();
      query.close();

      return config;
    } catch (e) {
      debugPrint('Error getting library config: $e');
      return null;
    }
  }

  /// Update video library configuration
  Future<bool> updateLibraryConfig(VideoLibraryConfig config) async {
    try {
      final store = await _getStore();
      final box = store.box<VideoLibraryConfig>();
      box.put(config);
      debugPrint(
          'Updated library config for library: ${config.videoLibraryId}');
      return true;
    } catch (e) {
      debugPrint('Error updating library config: $e');
      return false;
    }
  }

  /// Add a directory to library config
  Future<bool> addDirectoryToLibrary(
      int libraryId, String directoryPath) async {
    try {
      final config = await getLibraryConfig(libraryId);
      if (config == null) return false;

      final dirs = config.directoriesList;
      if (!dirs.contains(directoryPath)) {
        dirs.add(directoryPath);
        config.directoriesList = dirs;
        return await updateLibraryConfig(config);
      }
      return true;
    } catch (e) {
      debugPrint('Error adding directory to library: $e');
      return false;
    }
  }

  /// Remove a directory from library config
  Future<bool> removeDirectoryFromLibrary(
      int libraryId, String directoryPath) async {
    try {
      final config = await getLibraryConfig(libraryId);
      if (config == null) return false;

      final dirs = config.directoriesList;
      dirs.remove(directoryPath);
      config.directoriesList = dirs;
      return await updateLibraryConfig(config);
    } catch (e) {
      debugPrint('Error removing directory from library: $e');
      return false;
    }
  }

  /// Get videos by tag (uses TagManager)
  Future<List<String>> getVideosByTag(String tag,
      {int? libraryId, bool globalSearch = false}) async {
    try {
      List<FileSystemEntity> taggedFiles;

      if (globalSearch || libraryId == null) {
        // Global tag search
        taggedFiles = await TagManager.findFilesByTagGlobally(tag);
      } else {
        // Search within library directories
        final config = await getLibraryConfig(libraryId);
        if (config == null || config.directoriesList.isEmpty) return [];

        final Set<FileSystemEntity> allTaggedFiles = {};
        for (final dir in config.directoriesList) {
          final files = await TagManager.findFilesByTag(dir, tag);
          allTaggedFiles.addAll(files);
        }
        taggedFiles = allTaggedFiles.toList();
      }

      // Filter to only video files
      final videoExtensions = [
        '.mp4',
        '.avi',
        '.mov',
        '.mkv',
        '.webm',
        '.wmv',
        '.flv',
        '.m4v',
        '.mpg',
        '.mpeg',
        '.3gp',
        '.ogv'
      ];

      final videoPaths = taggedFiles
          .whereType<File>()
          .where((f) =>
              videoExtensions.contains(path.extension(f.path).toLowerCase()))
          .map((f) => f.path)
          .toList();

      return videoPaths;
    } catch (e) {
      debugPrint('Error getting videos by tag: $e');
      return [];
    }
  }

  /// Search videos by name or tag
  Future<List<String>> searchVideos(String query,
      {int? libraryId, bool searchTags = true}) async {
    try {
      List<String> allVideos;

      if (libraryId != null) {
        allVideos = await getLibraryFiles(libraryId);
      } else {
        // Global search - get from all libraries
        final libraries = await getAllLibraries();
        final Set<String> allFiles = {};
        for (final library in libraries) {
          final files = await getLibraryFiles(library.id);
          allFiles.addAll(files);
        }
        allVideos = allFiles.toList();
      }

      // Filter by filename
      final queryLower = query.toLowerCase();
      final matchingVideos = allVideos
          .where((filePath) =>
              path.basename(filePath).toLowerCase().contains(queryLower))
          .toList();

      // If searching tags, also include tag matches
      if (searchTags && query.isNotEmpty) {
        final taggedVideos = await getVideosByTag(query,
            libraryId: libraryId, globalSearch: libraryId == null);
        matchingVideos.addAll(taggedVideos);
      }

      return matchingVideos.toSet().toList(); // Remove duplicates
    } catch (e) {
      debugPrint('Error searching videos: $e');
      return [];
    }
  }

  /// Refresh library (rescan directories)
  Future<void> refreshLibrary(int libraryId) async {
    try {
      final config = await getLibraryConfig(libraryId);
      if (config == null) return;

      final files = await getLibraryFiles(libraryId);
      config.updateScanStats(files.length);
      await updateLibraryConfig(config);

      debugPrint('Refreshed library $libraryId: ${files.length} files found');
    } catch (e) {
      debugPrint('Error refreshing library: $e');
    }
  }

  /// Get video count for a library
  Future<int> getLibraryVideoCount(int libraryId) async {
    final files = await getLibraryFiles(libraryId);
    return files.length;
  }

  /// Dispose resources
  void dispose() {
    debugPrint('VideoLibraryService: Disposing');
  }
}
