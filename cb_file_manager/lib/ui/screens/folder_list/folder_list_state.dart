import 'dart:io';

import 'package:equatable/equatable.dart';

class FolderListState extends Equatable {
  final Directory currentPath;
  final List<FileSystemEntity> folders;
  final List<FileSystemEntity> files;
  final List<FileSystemEntity> filteredFiles;
  final List<FileSystemEntity> searchResults;
  final String? currentFilter;
  final String? currentSearchTag;
  final bool isLoading;
  final String? error;

  // Map to store file paths and their associated tags
  final Map<String, List<String>> fileTags;

  // Set of all unique tags in the current directory
  final Set<String> allUniqueTags;

  FolderListState(String currentPath)
      : this.currentPath = Directory(currentPath),
        this.folders = const [],
        this.files = const [],
        this.filteredFiles = const [],
        this.searchResults = const [],
        this.currentFilter = null,
        this.currentSearchTag = null,
        this.isLoading = false,
        this.error = null,
        this.fileTags = const {},
        this.allUniqueTags = const {};

  FolderListState._({
    required this.currentPath,
    required this.folders,
    required this.files,
    required this.filteredFiles,
    required this.searchResults,
    this.currentFilter,
    this.currentSearchTag,
    required this.isLoading,
    this.error,
    required this.fileTags,
    required this.allUniqueTags,
  });

  FolderListState copyWith({
    Directory? currentPath,
    List<FileSystemEntity>? folders,
    List<FileSystemEntity>? files,
    List<FileSystemEntity>? filteredFiles,
    List<FileSystemEntity>? searchResults,
    String? currentFilter,
    String? currentSearchTag,
    bool? isLoading,
    String? error,
    Map<String, List<String>>? fileTags,
    Set<String>? allUniqueTags,
  }) {
    return FolderListState._(
      currentPath: currentPath ?? this.currentPath,
      folders: folders ?? this.folders,
      files: files ?? this.files,
      filteredFiles: filteredFiles ?? this.filteredFiles,
      searchResults: searchResults ?? this.searchResults,
      currentFilter: currentFilter ?? this.currentFilter,
      currentSearchTag: currentSearchTag ?? this.currentSearchTag,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      fileTags: fileTags ?? this.fileTags,
      allUniqueTags: allUniqueTags ?? this.allUniqueTags,
    );
  }

  @override
  List<Object?> get props => [
        currentPath,
        folders,
        files,
        filteredFiles,
        searchResults,
        currentFilter,
        currentSearchTag,
        isLoading,
        error,
        fileTags,
        allUniqueTags
      ];

  // Helper method to load tags for a given file
  List<String> getTagsForFile(String filePath) {
    return fileTags[filePath] ?? [];
  }

  // Helper method to find files by tag
  List<FileSystemEntity> getFilesByTag(String tag) {
    List<FileSystemEntity> result = [];
    fileTags.forEach((path, tags) {
      if (tags.contains(tag)) {
        final file = File(path);
        if (file.existsSync()) {
          result.add(file);
        }
      }
    });
    return result;
  }

  // Helper method to get all unique tags across all files
  Set<String> get allTags {
    return allUniqueTags;
  }
}
