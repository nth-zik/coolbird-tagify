import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as pathlib;

/// A utility class for managing file tags
///
/// Tags are stored in a hidden .tags file in the same directory as the file
class TagManager {
  // In-memory cache to improve performance
  static final Map<String, List<String>> _tagsCache = {};

  /// Gets all tags for a file
  ///
  /// Returns an empty list if no tags are found
  static Future<List<String>> getTags(String filePath) async {
    if (_tagsCache.containsKey(filePath)) {
      return List.from(_tagsCache[filePath]!);
    }

    try {
      final tagsFile = _getTagsFilePath(filePath);
      final file = File(tagsFile);

      if (!await file.exists()) {
        _tagsCache[filePath] = [];
        return [];
      }

      final content = await file.readAsString();
      final Map<String, dynamic> tagsJson = json.decode(content);

      final fileName = pathlib.basename(filePath);
      if (tagsJson.containsKey(fileName)) {
        final tags = List<String>.from(tagsJson[fileName]);
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
      final tagsFile = _getTagsFilePath(filePath);
      final file = File(tagsFile);
      final directory = file.parent;

      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      Map<String, dynamic> tagsJson = {};

      if (await file.exists()) {
        final content = await file.readAsString();
        try {
          tagsJson = json.decode(content);
        } catch (e) {
          print('Error parsing tags file $tagsFile: $e');
          tagsJson = {};
        }
      }

      final fileName = pathlib.basename(filePath);
      if (!tagsJson.containsKey(fileName)) {
        tagsJson[fileName] = [];
      }

      final tags = List<String>.from(tagsJson[fileName]);
      if (!tags.contains(tag)) {
        tags.add(tag);
        tagsJson[fileName] = tags;

        await file.writeAsString(json.encode(tagsJson));

        // Update cache
        _tagsCache[filePath] = tags;
        return true;
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
      final tagsFile = _getTagsFilePath(filePath);
      final file = File(tagsFile);

      if (!await file.exists()) {
        return true; // No tags file, nothing to remove
      }

      final content = await file.readAsString();
      Map<String, dynamic> tagsJson;

      try {
        tagsJson = json.decode(content);
      } catch (e) {
        print('Error parsing tags file $tagsFile: $e');
        return false;
      }

      final fileName = pathlib.basename(filePath);
      if (!tagsJson.containsKey(fileName)) {
        return true; // No tags for this file
      }

      final tags = List<String>.from(tagsJson[fileName]);
      if (tags.contains(tag)) {
        tags.remove(tag);
        tagsJson[fileName] = tags;

        await file.writeAsString(json.encode(tagsJson));

        // Update cache
        _tagsCache[filePath] = tags;
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
      // First validate tags (remove empty ones)
      final validTags = tags.where((tag) => tag.trim().isNotEmpty).toList();

      final tagsFile = _getTagsFilePath(filePath);
      final file = File(tagsFile);
      final directory = file.parent;

      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      Map<String, dynamic> tagsJson = {};

      if (await file.exists()) {
        final content = await file.readAsString();
        try {
          tagsJson = json.decode(content);
        } catch (e) {
          print('Error parsing tags file $tagsFile: $e');
          tagsJson = {};
        }
      }

      final fileName = pathlib.basename(filePath);
      tagsJson[fileName] = validTags;

      await file.writeAsString(json.encode(tagsJson));

      // Update cache
      _tagsCache[filePath] = validTags;

      return true;
    } catch (e) {
      print('Error setting tags for $filePath: $e');
      return false;
    }
  }

  /// Gets all unique tags across all files in a directory and its subdirectories
  ///
  /// Returns a set of unique tags
  static Future<Set<String>> getAllUniqueTags(String directoryPath) async {
    final Set<String> allTags = {};

    try {
      final directory = Directory(directoryPath);
      if (!await directory.exists()) {
        return allTags;
      }

      await for (final entity in directory.list(recursive: true)) {
        if (entity is File && pathlib.basename(entity.path) == '.tags') {
          try {
            final content = await entity.readAsString();
            final Map<String, dynamic> tagsJson = json.decode(content);

            for (final tags in tagsJson.values) {
              if (tags is List) {
                for (final tag in tags) {
                  if (tag is String) {
                    allTags.add(tag);
                  }
                }
              }
            }
          } catch (e) {
            print('Error reading tags file ${entity.path}: $e');
          }
        }
      }

      return allTags;
    } catch (e) {
      print('Error getting all tags: $e');
      return allTags;
    }
  }

  /// Finds all files with a specific tag in a directory and its subdirectories
  ///
  /// Returns a list of files with the tag
  static Future<List<FileSystemEntity>> findFilesByTag(
      String directoryPath, String tag) async {
    final List<FileSystemEntity> files = [];

    try {
      final directory = Directory(directoryPath);
      if (!await directory.exists()) {
        return files;
      }

      await for (final entity in directory.list(recursive: true)) {
        if (entity is File && pathlib.basename(entity.path) == '.tags') {
          try {
            final content = await entity.readAsString();
            final Map<String, dynamic> tagsJson = json.decode(content);
            final String dirPath = entity.parent.path;

            for (final fileName in tagsJson.keys) {
              if (tagsJson[fileName] is List &&
                  List<String>.from(tagsJson[fileName]).contains(tag)) {
                final filePath = pathlib.join(dirPath, fileName);
                final file = File(filePath);
                if (await file.exists()) {
                  files.add(file);
                }
              }
            }
          } catch (e) {
            print('Error reading tags file ${entity.path}: $e');
          }
        }
      }

      return files;
    } catch (e) {
      print('Error finding files by tag: $e');
      return files;
    }
  }

  /// Clears the tags cache to free memory
  static void clearCache() {
    _tagsCache.clear();
  }

  /// Gets the path to the tags file for a file
  static String _getTagsFilePath(String filePath) {
    final directory = pathlib.dirname(filePath);
    return pathlib.join(directory, '.tags');
  }
}
