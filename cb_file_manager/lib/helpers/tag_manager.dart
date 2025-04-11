import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as pathlib;
import 'package:path_provider/path_provider.dart';

/// A utility class for managing file tags globally
///
/// Tags are stored in a central global tags file instead of per directory
class TagManager {
  // In-memory cache to improve performance
  static final Map<String, List<String>> _tagsCache = {};

  // Global tags file name
  static const String GLOBAL_TAGS_FILENAME = 'coolbird_global_tags.json';

  // Path to the global tags file (initialized lazily)
  static String? _globalTagsPath;

  /// Initialize the global tags system by determining the storage path
  static Future<void> initialize() async {
    if (_globalTagsPath != null) return; // Already initialized

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final coolbirdDir = Directory('${appDir.path}/coolbird');

      // Create the directory if it doesn't exist
      if (!await coolbirdDir.exists()) {
        await coolbirdDir.create(recursive: true);
      }

      _globalTagsPath = '${coolbirdDir.path}/$GLOBAL_TAGS_FILENAME';
      print('Global tags path: $_globalTagsPath');
    } catch (e) {
      print('Error initializing TagManager: $e');
      // Fallback to a location in the user's home directory
      final home =
          Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
      _globalTagsPath = '$home/$GLOBAL_TAGS_FILENAME';
      print('Using fallback global tags path: $_globalTagsPath');
    }
  }

  /// Gets the path to the global tags file
  static Future<String> _getGlobalTagsFilePath() async {
    await initialize();
    return _globalTagsPath!;
  }

  /// Load all tags from the global tags file
  static Future<Map<String, dynamic>> _loadGlobalTags() async {
    final tagsFilePath = await _getGlobalTagsFilePath();
    final file = File(tagsFilePath);

    if (!await file.exists()) {
      return {};
    }

    try {
      final content = await file.readAsString();
      return json.decode(content);
    } catch (e) {
      print('Error loading global tags: $e');
      return {};
    }
  }

  /// Save all tags to the global tags file
  static Future<bool> _saveGlobalTags(Map<String, dynamic> tagsData) async {
    final tagsFilePath = await _getGlobalTagsFilePath();
    final file = File(tagsFilePath);

    try {
      await file.writeAsString(json.encode(tagsData));
      return true;
    } catch (e) {
      print('Error saving global tags: $e');
      return false;
    }
  }

  /// Gets all tags for a file
  ///
  /// Returns an empty list if no tags are found
  static Future<List<String>> getTags(String filePath) async {
    if (_tagsCache.containsKey(filePath)) {
      return List.from(_tagsCache[filePath]!);
    }

    try {
      final tagsData = await _loadGlobalTags();

      // Use the absolute file path as the key in the global tags file
      if (tagsData.containsKey(filePath)) {
        final tags = List<String>.from(tagsData[filePath]);
        _tagsCache[filePath] = tags;
        return tags;
      }

      _tagsCache[filePath] = [];
      return [];
    } catch (e) {
      print('Error reading tags for $filePath: $e');
      return [];
    }
  }

  /// Adds a tag to a file
  ///
  /// Returns true if successful, false otherwise
  static Future<bool> addTag(String filePath, String tag) async {
    if (tag.trim().isEmpty) {
      return false;
    }

    try {
      await initialize();

      Map<String, dynamic> tagsData = await _loadGlobalTags();

      if (!tagsData.containsKey(filePath)) {
        tagsData[filePath] = [];
      }

      final tags = List<String>.from(tagsData[filePath]);
      if (!tags.contains(tag)) {
        tags.add(tag);
        tagsData[filePath] = tags;

        final success = await _saveGlobalTags(tagsData);

        if (success) {
          // Update cache
          _tagsCache[filePath] = tags;
        }

        return success;
      }

      // Tag already exists
      return true;
    } catch (e) {
      print('Error adding tag to $filePath: $e');
      return false;
    }
  }

  /// Removes a tag from a file
  ///
  /// Returns true if successful, false otherwise
  static Future<bool> removeTag(String filePath, String tag) async {
    try {
      await initialize();

      Map<String, dynamic> tagsData = await _loadGlobalTags();

      if (!tagsData.containsKey(filePath)) {
        return true; // No tags for this file
      }

      final tags = List<String>.from(tagsData[filePath]);
      if (tags.contains(tag)) {
        tags.remove(tag);

        if (tags.isEmpty) {
          // Remove the file entry entirely if no tags left
          tagsData.remove(filePath);
        } else {
          tagsData[filePath] = tags;
        }

        final success = await _saveGlobalTags(tagsData);

        if (success) {
          // Update cache
          if (tags.isEmpty) {
            _tagsCache.remove(filePath);
          } else {
            _tagsCache[filePath] = tags;
          }
        }

        return success;
      }

      return true;
    } catch (e) {
      print('Error removing tag from $filePath: $e');
      return false;
    }
  }

  /// Set the full set of tags for a file (replaces existing tags)
  ///
  /// Returns true if successful, false otherwise
  static Future<bool> setTags(String filePath, List<String> tags) async {
    try {
      await initialize();

      // First validate tags (remove empty ones)
      final validTags = tags.where((tag) => tag.trim().isNotEmpty).toList();

      Map<String, dynamic> tagsData = await _loadGlobalTags();

      if (validTags.isEmpty) {
        // Remove entry if no tags
        if (tagsData.containsKey(filePath)) {
          tagsData.remove(filePath);
        }
      } else {
        tagsData[filePath] = validTags;
      }

      final success = await _saveGlobalTags(tagsData);

      if (success) {
        // Update cache
        if (validTags.isEmpty) {
          _tagsCache.remove(filePath);
        } else {
          _tagsCache[filePath] = validTags;
        }
      }

      return success;
    } catch (e) {
      print('Error setting tags for $filePath: $e');
      return false;
    }
  }

  /// Gets all unique tags across all files
  ///
  /// Returns a set of unique tags
  static Future<Set<String>> getAllUniqueTags(String directoryPath) async {
    // Note: directoryPath parameter is kept for backward compatibility
    // but is no longer used since tags are global

    final Set<String> allTags = {};

    try {
      await initialize();

      final tagsData = await _loadGlobalTags();

      for (final tags in tagsData.values) {
        if (tags is List) {
          for (final tag in tags) {
            if (tag is String) {
              allTags.add(tag);
            }
          }
        }
      }

      return allTags;
    } catch (e) {
      print('Error getting all tags: $e');
      return allTags;
    }
  }

  /// Finds all files with a specific tag
  ///
  /// Returns a list of files with the tag
  static Future<List<FileSystemEntity>> findFilesByTag(
      String directoryPath, String tag) async {
    final List<FileSystemEntity> files = [];

    try {
      await initialize();

      final tagsData = await _loadGlobalTags();

      // For each file path in the global tags data
      for (final filePath in tagsData.keys) {
        final tags = List<String>.from(tagsData[filePath]);

        // Check if this file has the requested tag
        if (tags.contains(tag)) {
          final file = File(filePath);

          // Check if the file exists and is within or under the specified directory
          if (await file.exists() && file.path.startsWith(directoryPath)) {
            files.add(file);
          }
        }
      }

      return files;
    } catch (e) {
      print('Error finding files by tag: $e');
      return files;
    }
  }

  /// Find files with a specific tag anywhere in the file system
  ///
  /// Returns a list of files with the tag
  static Future<List<FileSystemEntity>> findFilesByTagGlobally(
      String tag) async {
    final List<FileSystemEntity> files = [];

    try {
      await initialize();

      final tagsData = await _loadGlobalTags();

      // For each file path in the global tags data
      for (final filePath in tagsData.keys) {
        final tags = List<String>.from(tagsData[filePath]);

        // Check if this file has the requested tag
        if (tags.contains(tag)) {
          final file = File(filePath);

          // Check if the file exists
          if (await file.exists()) {
            files.add(file);
          }
        }
      }

      return files;
    } catch (e) {
      print('Error finding files by tag globally: $e');
      return files;
    }
  }

  /// Clears the tags cache to free memory
  static void clearCache() {
    _tagsCache.clear();
  }

  /// Migrate from directory-based tags to global tags
  ///
  /// This function scans all .tags files in the specified root directory
  /// and its subdirectories, and migrates the tags to the global tags file.
  static Future<int> migrateToGlobalTags(String rootDirectory) async {
    int migratedFileCount = 0;

    try {
      await initialize();

      final rootDir = Directory(rootDirectory);
      if (!await rootDir.exists()) {
        return 0;
      }

      // Load the current global tags data
      Map<String, dynamic> globalTags = await _loadGlobalTags();

      // Find all .tags files
      await for (final entity in rootDir.list(recursive: true)) {
        if (entity is File && pathlib.basename(entity.path) == '.tags') {
          try {
            final content = await entity.readAsString();
            final Map<String, dynamic> localTagsJson = json.decode(content);
            final String dirPath = entity.parent.path;

            // Process each file in the local tags file
            for (final fileName in localTagsJson.keys) {
              if (localTagsJson[fileName] is List) {
                final tags = List<String>.from(localTagsJson[fileName]);
                if (tags.isNotEmpty) {
                  final filePath = pathlib.join(dirPath, fileName);
                  final file = File(filePath);

                  // Only migrate if the file exists
                  if (await file.exists()) {
                    globalTags[filePath] = tags;
                    migratedFileCount++;
                  }
                }
              }
            }

            // Delete the old .tags file after migration
            await entity.delete();
          } catch (e) {
            print('Error migrating tags from ${entity.path}: $e');
          }
        }
      }

      // Save the updated global tags
      await _saveGlobalTags(globalTags);

      return migratedFileCount;
    } catch (e) {
      print('Error during tags migration: $e');
      return migratedFileCount;
    }
  }
}
