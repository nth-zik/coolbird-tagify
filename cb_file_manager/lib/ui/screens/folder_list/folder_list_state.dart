import 'dart:io';

import 'package:equatable/equatable.dart';

// Define view modes
enum ViewMode { list, grid }

// Define sort options
enum SortOption {
  nameAsc,
  nameDesc,
  dateAsc,
  dateDesc,
  sizeAsc,
  sizeDesc,
  typeAsc
}

// Define media types for search
enum MediaType { image, video, audio, document }

class FolderListState extends Equatable {
  final Directory currentPath;
  final List<FileSystemEntity> folders;
  final List<FileSystemEntity> files;
  final List<FileSystemEntity> filteredFiles;
  final List<FileSystemEntity> searchResults;
  final String? currentFilter;
  final String? currentSearchTag;
  final String? currentSearchQuery;
  final MediaType? currentMediaSearch;
  final bool isSearchByName;
  final bool isSearchByMedia;
  final bool isGlobalSearch; // New property for global tag search
  final bool searchRecursive;
  final bool isLoading;
  final String? error;

  // View and sort settings
  final ViewMode viewMode;
  final SortOption sortOption;

  // Map to store file paths and their associated tags
  final Map<String, List<String>> fileTags;

  // Set of all unique tags in the current directory
  final Set<String> allUniqueTags;

  // File stats cache to avoid repeatedly calling stat()
  final Map<String, FileStat> fileStatsCache;

  // Grid zoom level (number of items per row, smaller means larger thumbnails)
  final int gridZoomLevel;

  FolderListState(String currentPath)
      : this.currentPath = Directory(currentPath),
        this.folders = const [],
        this.files = const [],
        this.filteredFiles = const [],
        this.searchResults = const [],
        this.currentFilter = null,
        this.currentSearchTag = null,
        this.currentSearchQuery = null,
        this.currentMediaSearch = null,
        this.isSearchByName = false,
        this.isSearchByMedia = false,
        this.isGlobalSearch = false, // Initialize as false
        this.searchRecursive = false,
        this.isLoading = false,
        this.error = null,
        this.fileTags = const {},
        this.allUniqueTags = const {},
        this.viewMode = ViewMode.list,
        this.sortOption = SortOption.nameAsc,
        this.fileStatsCache = const {},
        this.gridZoomLevel = 3; // Default to 3 items per row

  FolderListState._({
    required this.currentPath,
    required this.folders,
    required this.files,
    required this.filteredFiles,
    required this.searchResults,
    this.currentFilter,
    this.currentSearchTag,
    this.currentSearchQuery,
    this.currentMediaSearch,
    required this.isSearchByName,
    required this.isSearchByMedia,
    required this.isGlobalSearch, // Add to constructor
    required this.searchRecursive,
    required this.isLoading,
    this.error,
    required this.fileTags,
    required this.allUniqueTags,
    required this.viewMode,
    required this.sortOption,
    required this.fileStatsCache,
    required this.gridZoomLevel,
  });

  FolderListState copyWith({
    Directory? currentPath,
    List<FileSystemEntity>? folders,
    List<FileSystemEntity>? files,
    List<FileSystemEntity>? filteredFiles,
    List<FileSystemEntity>? searchResults,
    String? currentFilter,
    String? currentSearchTag,
    String? currentSearchQuery,
    MediaType? currentMediaSearch,
    bool? isSearchByName,
    bool? isSearchByMedia,
    bool? isGlobalSearch, // Add to copyWith
    bool? searchRecursive,
    bool? isLoading,
    String? error,
    Map<String, List<String>>? fileTags,
    Set<String>? allUniqueTags,
    ViewMode? viewMode,
    SortOption? sortOption,
    Map<String, FileStat>? fileStatsCache,
    int? gridZoomLevel,
  }) {
    return FolderListState._(
      currentPath: currentPath ?? this.currentPath,
      folders: folders ?? this.folders,
      files: files ?? this.files,
      filteredFiles: filteredFiles ?? this.filteredFiles,
      searchResults: searchResults ?? this.searchResults,
      currentFilter: currentFilter ?? this.currentFilter,
      currentSearchTag: currentSearchTag ?? this.currentSearchTag,
      currentSearchQuery: currentSearchQuery ?? this.currentSearchQuery,
      currentMediaSearch: currentMediaSearch ?? this.currentMediaSearch,
      isSearchByName: isSearchByName ?? this.isSearchByName,
      isSearchByMedia: isSearchByMedia ?? this.isSearchByMedia,
      isGlobalSearch: isGlobalSearch ?? this.isGlobalSearch, // Add to return
      searchRecursive: searchRecursive ?? this.searchRecursive,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      fileTags: fileTags ?? this.fileTags,
      allUniqueTags: allUniqueTags ?? this.allUniqueTags,
      viewMode: viewMode ?? this.viewMode,
      sortOption: sortOption ?? this.sortOption,
      fileStatsCache: fileStatsCache ?? this.fileStatsCache,
      gridZoomLevel: gridZoomLevel ?? this.gridZoomLevel,
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
        currentSearchQuery,
        currentMediaSearch,
        isSearchByName,
        isSearchByMedia,
        isGlobalSearch, // Add to props
        searchRecursive,
        isLoading,
        error,
        fileTags,
        allUniqueTags,
        viewMode,
        sortOption,
        fileStatsCache,
        gridZoomLevel,
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

  // Get cached file stats or fetch if not cached
  FileStat? getFileStats(String filePath) {
    return fileStatsCache[filePath];
  }

  // Function to get sorted list of tags for autocomplete
  List<String> getTagSuggestions(String prefix) {
    if (prefix.isEmpty) return allUniqueTags.toList();

    return allUniqueTags
        .where((tag) => tag.toLowerCase().startsWith(prefix.toLowerCase()))
        .toList()
      ..sort();
  }
}
