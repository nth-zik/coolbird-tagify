import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cb_file_manager/helpers/tag_manager.dart';

import 'folder_list_event.dart';
import 'folder_list_state.dart';

class FolderListBloc extends Bloc<FolderListEvent, FolderListState> {
  FolderListBloc() : super(FolderListState("/")) {
    on<FolderListInit>(_onFolderListInit);
    on<FolderListLoad>(_onFolderListLoad);
    on<FolderListFilter>(_onFolderListFilter);
    on<AddTagToFile>(_onAddTagToFile);
    on<RemoveTagFromFile>(_onRemoveTagFromFile);
    on<SearchByTag>(_onSearchByTag);
    on<LoadTagsFromFile>(_onLoadTagsFromFile);
    on<LoadAllTags>(_onLoadAllTags);
  }

  void _onFolderListInit(
      FolderListInit event, Emitter<FolderListState> emit) async {
    // Initialize with empty folders list
    emit(state.copyWith(isLoading: true));
    emit(state.copyWith(isLoading: false));
  }

  void _onFolderListLoad(
      FolderListLoad event, Emitter<FolderListState> emit) async {
    emit(state.copyWith(
      isLoading: true,
      currentPath: Directory(event.path),
    ));
    try {
      final directory = Directory(event.path);
      if (await directory.exists()) {
        List<FileSystemEntity> contents = await directory.list().toList();

        // Separate folders and files
        final List<FileSystemEntity> folders = [];
        final List<FileSystemEntity> files = [];

        for (var entity in contents) {
          if (entity is Directory) {
            folders.add(entity);
          } else if (entity is File) {
            // Skip tag files
            if (!entity.path.endsWith('.tags')) {
              files.add(entity);
            }
          }
        }

        // Load tags for all files
        Map<String, List<String>> fileTags = {};
        for (var file in files) {
          if (file is File) {
            final tags = await TagManager.getTags(file.path);
            if (tags.isNotEmpty) {
              fileTags[file.path] = tags;
            }
          }
        }

        emit(state.copyWith(
          isLoading: false,
          folders: folders,
          files: files,
          fileTags: fileTags,
        ));

        // Load all unique tags in this directory (async)
        add(LoadAllTags(event.path));
      } else {
        emit(state.copyWith(
            isLoading: false, error: "Directory does not exist"));
      }
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  void _onFolderListFilter(
      FolderListFilter event, Emitter<FolderListState> emit) async {
    // Filter files by type (videos, images, etc.)
    if (event.fileType == null) {
      emit(state.copyWith(currentFilter: null, filteredFiles: []));
      return;
    }

    emit(state.copyWith(
      isLoading: true,
      currentFilter: event.fileType,
    ));

    try {
      final List<FileSystemEntity> filteredFiles = state.files.where((file) {
        if (file is File) {
          String extension = file.path.split('.').last.toLowerCase();
          switch (event.fileType) {
            case 'image':
              return ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp']
                  .contains(extension);
            case 'video':
              return ['mp4', 'mov', 'avi', 'mkv', 'flv', 'wmv']
                  .contains(extension);
            case 'audio':
              return ['mp3', 'wav', 'ogg', 'm4a', 'aac', 'flac']
                  .contains(extension);
            case 'document':
              return ['pdf', 'doc', 'docx', 'txt', 'xls', 'xlsx', 'ppt', 'pptx']
                  .contains(extension);
            default:
              return true;
          }
        }
        return false;
      }).toList();

      emit(state.copyWith(
        isLoading: false,
        filteredFiles: filteredFiles,
      ));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  void _onAddTagToFile(
      AddTagToFile event, Emitter<FolderListState> emit) async {
    try {
      // Use TagManager to add the tag
      final success = await TagManager.addTag(event.filePath, event.tag);

      if (success) {
        // Update state with new tags
        final tags = await TagManager.getTags(event.filePath);

        // Create a copy of the current fileTags map
        final Map<String, List<String>> updatedFileTags =
            Map.from(state.fileTags);
        updatedFileTags[event.filePath] = tags;

        emit(state.copyWith(fileTags: updatedFileTags));

        // Also update all unique tags
        final currentDir = state.currentPath.path;
        add(LoadAllTags(currentDir));
      }
    } catch (e) {
      emit(state.copyWith(error: "Error adding tag: ${e.toString()}"));
    }
  }

  void _onRemoveTagFromFile(
      RemoveTagFromFile event, Emitter<FolderListState> emit) async {
    try {
      // Use TagManager to remove the tag
      final success = await TagManager.removeTag(event.filePath, event.tag);

      if (success) {
        // Update state with new tags
        final tags = await TagManager.getTags(event.filePath);

        // Create a copy of the current fileTags map
        final Map<String, List<String>> updatedFileTags =
            Map.from(state.fileTags);

        if (tags.isEmpty) {
          updatedFileTags.remove(event.filePath);
        } else {
          updatedFileTags[event.filePath] = tags;
        }

        emit(state.copyWith(fileTags: updatedFileTags));

        // Also update all unique tags
        final currentDir = state.currentPath.path;
        add(LoadAllTags(currentDir));
      }
    } catch (e) {
      emit(state.copyWith(error: "Error removing tag: ${e.toString()}"));
    }
  }

  void _onSearchByTag(SearchByTag event, Emitter<FolderListState> emit) async {
    emit(state.copyWith(isLoading: true));

    try {
      // Use TagManager to search for files with the given tag
      final matchingFiles =
          await TagManager.findFilesByTag(state.currentPath.path, event.tag);

      emit(state.copyWith(
        isLoading: false,
        searchResults: matchingFiles,
        currentSearchTag: event.tag,
      ));
    } catch (e) {
      emit(state.copyWith(
          isLoading: false, error: "Error searching by tag: ${e.toString()}"));
    }
  }

  void _onLoadTagsFromFile(
      LoadTagsFromFile event, Emitter<FolderListState> emit) async {
    try {
      final tags = await TagManager.getTags(event.filePath);

      // Only update if we have tags
      if (tags.isNotEmpty) {
        Map<String, List<String>> updatedFileTags = Map.from(state.fileTags);
        updatedFileTags[event.filePath] = tags;

        emit(state.copyWith(fileTags: updatedFileTags));
      }
    } catch (e) {
      print('Error loading tags for file: ${e.toString()}');
    }
  }

  void _onLoadAllTags(LoadAllTags event, Emitter<FolderListState> emit) async {
    try {
      final Set<String> allTags =
          await TagManager.getAllUniqueTags(event.directory);
      emit(state.copyWith(allUniqueTags: allTags));
    } catch (e) {
      print('Error loading all tags: ${e.toString()}');
    }
  }
}
