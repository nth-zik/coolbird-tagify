import 'package:cb_file_manager/helpers/tag_manager.dart';
import 'package:flutter/material.dart';
import 'package:cb_file_manager/ui/utils/dialog_utils.dart';

/// A utility class for managing tags across multiple files at once
class BatchTagManager {
  /// Add a tag to multiple files at once
  ///
  /// Returns a map of file paths to success status
  static Future<Map<String, bool>> addTagToFiles(
      List<String> filePaths, String tag) async {
    return _processFilesWithConfirmation(
      filePaths,
      (path) => TagManager.addTag(path, tag),
      skipEmptyCheck: false,
      emptyValue: tag,
    );
  }

  /// Add a tag to multiple files with iteration confirmation
  ///
  /// Returns a map of file paths to success status
  static Future<Map<String, bool>> addTagToFilesWithConfirmation(
      BuildContext context, List<String> filePaths, String tag,
      {int confirmEvery = 10}) async {
    return _processFilesWithConfirmation(
      filePaths,
      (path) => TagManager.addTag(path, tag),
      skipEmptyCheck: false,
      emptyValue: tag,
      withConfirmation: true,
      context: context,
      confirmEvery: confirmEvery,
    );
  }

  /// Remove a tag from multiple files at once
  ///
  /// Returns a map of file paths to success status
  static Future<Map<String, bool>> removeTagFromFiles(
      List<String> filePaths, String tag) async {
    return _processFilesWithConfirmation(
      filePaths,
      (path) => TagManager.removeTag(path, tag),
      skipEmptyCheck: true,
    );
  }

  /// Remove a tag from multiple files with iteration confirmation
  ///
  /// Returns a map of file paths to success status
  static Future<Map<String, bool>> removeTagFromFilesWithConfirmation(
      BuildContext context, List<String> filePaths, String tag,
      {int confirmEvery = 10}) async {
    return _processFilesWithConfirmation(
      filePaths,
      (path) => TagManager.removeTag(path, tag),
      skipEmptyCheck: true,
      withConfirmation: true,
      context: context,
      confirmEvery: confirmEvery,
    );
  }

  /// Replace one tag with another across multiple files
  ///
  /// Returns a map of file paths to success status
  static Future<Map<String, bool>> replaceTagInFiles(
      List<String> filePaths, String oldTag, String newTag) async {
    if (newTag.trim().isEmpty) {
      // If new tag is empty, just remove the old tag
      return removeTagFromFiles(filePaths, oldTag);
    }

    return _processFilesWithConfirmation(
      filePaths,
      (path) async {
        bool success = true;
        // First check if the file has the old tag
        final tags = await TagManager.getTags(path);
        if (tags.contains(oldTag)) {
          // Remove the old tag
          success = await TagManager.removeTag(path, oldTag);
          if (success) {
            // Add the new tag
            success = await TagManager.addTag(path, newTag);
          }
        }
        return success;
      },
      skipEmptyCheck: true,
    );
  }

  /// Replace one tag with another across multiple files with iteration confirmation
  ///
  /// Returns a map of file paths to success status
  static Future<Map<String, bool>> replaceTagInFilesWithConfirmation(
      BuildContext context,
      List<String> filePaths,
      String oldTag,
      String newTag,
      {int confirmEvery = 10}) async {
    if (newTag.trim().isEmpty) {
      // If new tag is empty, just remove the old tag
      return removeTagFromFilesWithConfirmation(context, filePaths, oldTag,
          confirmEvery: confirmEvery);
    }

    return _processFilesWithConfirmation(
      filePaths,
      (path) async {
        bool success = true;
        // First check if the file has the old tag
        final tags = await TagManager.getTags(path);
        if (tags.contains(oldTag)) {
          // Remove the old tag
          success = await TagManager.removeTag(path, oldTag);
          if (success) {
            // Add the new tag
            success = await TagManager.addTag(path, newTag);
          }
        }
        return success;
      },
      skipEmptyCheck: true,
      withConfirmation: true,
      context: context,
      confirmEvery: confirmEvery,
    );
  }

  /// Helper method to process files with optional confirmation
  ///
  /// Takes a processing function that operates on a single file path
  /// and returns a success status
  static Future<Map<String, bool>> _processFilesWithConfirmation(
    List<String> filePaths,
    Future<bool> Function(String) processFn, {
    bool skipEmptyCheck = false,
    String emptyValue = '',
    bool withConfirmation = false,
    BuildContext? context,
    int confirmEvery = 10,
  }) async {
    final Map<String, bool> results = {};

    if (!skipEmptyCheck && emptyValue.trim().isEmpty) {
      // Return all failures if value is empty
      for (final path in filePaths) {
        results[path] = false;
      }
      return results;
    }

    // Process each file
    for (int i = 0; i < filePaths.length; i++) {
      final path = filePaths[i];

      // Check if we need to show confirmation dialog
      if (withConfirmation &&
          context != null &&
          i > 0 &&
          i % confirmEvery == 0) {
        final shouldContinue = await DialogUtils.showContinueIterationDialog(
          context,
          title: 'Continue Processing',
          message:
              'Processed $i of ${filePaths.length} files. Continue to iterate?',
        );

        if (!shouldContinue) {
          // Mark remaining files as not processed
          for (int j = i; j < filePaths.length; j++) {
            results[filePaths[j]] = false;
          }
          return results;
        }
      }

      try {
        final success = await processFn(path);
        results[path] = success;
      } catch (e) {
        print('Error processing file $path: $e');
        results[path] = false;
      }
    }

    return results;
  }

  /// Add multiple tags to multiple files at once
  ///
  /// Returns a map of file paths to a map of tags to success status
  static Future<Map<String, Map<String, bool>>> addTagsToFiles(
      List<String> filePaths, List<String> tags) async {
    final Map<String, Map<String, bool>> results = {};

    // Initialize results map
    for (final path in filePaths) {
      results[path] = {};
    }

    // Process each tag
    for (final tag in tags) {
      if (tag.trim().isEmpty) continue;

      final tagResults = await addTagToFiles(filePaths, tag);

      // Add results to the main results map
      for (final entry in tagResults.entries) {
        results[entry.key]![tag] = entry.value;
      }
    }

    return results;
  }

  /// Copy tags from one file to multiple other files
  static Future<Map<String, bool>> copyTagsToFiles(
      String sourceFilePath, List<String> targetFilePaths) async {
    Map<String, bool> results = {};

    try {
      // Get tags from source file
      final List<String> sourceTags = await TagManager.getTags(sourceFilePath);

      if (sourceTags.isEmpty) {
        // Nothing to copy
        for (final path in targetFilePaths) {
          results[path] = true;
        }
        return results;
      }

      // Apply all tags to each target file
      for (final path in targetFilePaths) {
        try {
          bool allSuccess = true;
          for (final tag in sourceTags) {
            final success = await TagManager.addTag(path, tag);
            if (!success) {
              allSuccess = false;
            }
          }

          results[path] = allSuccess;
        } catch (e) {
          print('Error copying tags to file $path: $e');
          results[path] = false;
        }
      }
    } catch (e) {
      print('Error in copyTagsToFiles: $e');
      for (final path in targetFilePaths) {
        results[path] = false;
      }
    }

    return results;
  }

  /// Find all common tags in a list of files
  static Future<List<String>> getCommonTags(List<String> filePaths) async {
    if (filePaths.isEmpty) return [];
    if (filePaths.length == 1) return await TagManager.getTags(filePaths[0]);

    try {
      // Get tags from first file as a starting point
      final Set<String> commonTags =
          Set.from(await TagManager.getTags(filePaths[0]));

      // Intersect with tags from all other files
      for (int i = 1; i < filePaths.length; i++) {
        final Set<String> fileTags =
            Set.from(await TagManager.getTags(filePaths[i]));
        commonTags.retainWhere((tag) => fileTags.contains(tag));

        // If there are no common tags left, we can stop early
        if (commonTags.isEmpty) break;
      }

      return commonTags.toList();
    } catch (e) {
      print('Error getting common tags: $e');
      return [];
    }
  }

  /// Get statistics about tag usage across files
  ///
  /// Returns a map of tags to the number of files they're used in
  static Future<Map<String, int>> getTagStatistics(String directory) async {
    final Map<String, int> statistics = {};

    // Get all unique tags
    final allTags = await TagManager.getAllUniqueTags(directory);

    // For each tag, count how many files have it
    for (final tag in allTags) {
      final files = await TagManager.findFilesByTag(directory, tag);
      statistics[tag] = files.length;
    }

    return statistics;
  }

  /// Clear the tag cache to free memory
  static void clearCache() {
    TagManager.clearCache();
  }

  /// Add multiple tags to a file
  ///
  /// Returns true if all tags were added successfully
  static Future<bool> addTagsToFile(String filePath, List<String> tags) async {
    bool allSucceeded = true;

    for (final tag in tags) {
      final success = await TagManager.addTag(filePath, tag);
      if (!success) {
        allSucceeded = false;
      }
    }

    return allSucceeded;
  }

  /// Replace all tags on multiple files with a new set of tags
  ///
  /// Returns a map with file paths as keys and success status as values
  static Future<Map<String, bool>> setTagsOnFiles(
      List<String> filePaths, List<String> tags) async {
    final Map<String, bool> results = {};

    for (final filePath in filePaths) {
      final success = await TagManager.setTags(filePath, tags);
      results[filePath] = success;
    }

    return results;
  }

  /// Group files by their tags
  ///
  /// Returns a map with tags as keys and lists of file paths as values
  static Future<Map<String, List<String>>> groupFilesByTags(
      List<String> filePaths) async {
    final Map<String, List<String>> tagGroups = {};

    for (final filePath in filePaths) {
      final tags = await TagManager.getTags(filePath);

      for (final tag in tags) {
        if (!tagGroups.containsKey(tag)) {
          tagGroups[tag] = [];
        }

        tagGroups[tag]!.add(filePath);
      }
    }

    return tagGroups;
  }
}
