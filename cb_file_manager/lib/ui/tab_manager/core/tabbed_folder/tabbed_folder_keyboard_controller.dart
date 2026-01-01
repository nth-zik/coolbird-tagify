import 'dart:io';
import 'dart:math';

import 'package:cb_file_manager/bloc/selection/selection.dart';
import 'package:cb_file_manager/ui/screens/folder_list/folder_list_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TabbedFolderKeyboardController {
  final FocusNode focusNode =
      FocusNode(debugLabel: 'tabbed-folder-list-keyboard');

  String? focusedPath;

  void dispose() {
    focusNode.dispose();
  }

  void clearFocus() {
    focusedPath = null;
  }

  void syncFromSelection(SelectionState selectionState) {
    final String? lastPath = selectionState.lastSelectedPath;
    if (lastPath != null && lastPath != focusedPath) {
      focusedPath = lastPath;
      return;
    }

    if (lastPath == null &&
        selectionState.selectedFilePaths.isEmpty &&
        selectionState.selectedFolderPaths.isEmpty) {
      focusedPath = null;
    }
  }

  KeyEventResult handleKeyEvent({
    required bool isDesktop,
    required FolderListState folderListState,
    required SelectionState selectionState,
    required String? currentFilter,
    required VoidCallback onBackInTabHistory,
    required void Function(String folderPath) focusFolderPath,
    required void Function(String filePath) focusFilePath,
    required void Function(FileSystemEntity entity) activateEntity,
    KeyEvent? event,
  }) {
    if (!isDesktop || event == null) return KeyEventResult.ignored;

    final bool isKeyPress = event is KeyDownEvent || event is KeyRepeatEvent;
    if (!isKeyPress) return KeyEventResult.ignored;

    final LogicalKeyboardKey key = event.logicalKey;

    if (key == LogicalKeyboardKey.backspace) {
      final focusedWidget = FocusManager.instance.primaryFocus?.context?.widget;
      if (focusedWidget is EditableText) {
        return KeyEventResult.ignored;
      }

      onBackInTabHistory();
      return KeyEventResult.handled;
    }

    final List<FileSystemEntity> items =
        _getNavigableItems(folderListState, currentFilter);
    if (items.isEmpty) return KeyEventResult.ignored;

    final bool isGridLayout = folderListState.viewMode == ViewMode.grid;
    final int crossAxisCount =
        isGridLayout ? max(1, folderListState.gridZoomLevel) : 1;

    int currentIndex = -1;
    if (focusedPath != null) {
      currentIndex =
          items.indexWhere((FileSystemEntity item) => item.path == focusedPath);
    }
    if (currentIndex == -1 && selectionState.lastSelectedPath != null) {
      currentIndex = items.indexWhere((FileSystemEntity item) =>
          item.path == selectionState.lastSelectedPath);
    }
    if (currentIndex == -1) {
      currentIndex = 0;
    }

    final bool hasExistingFocus =
        focusedPath != null || selectionState.lastSelectedPath != null;
    int targetIndex;

    if (key == LogicalKeyboardKey.arrowDown) {
      targetIndex = currentIndex + (isGridLayout ? crossAxisCount : 1);
    } else if (key == LogicalKeyboardKey.arrowUp) {
      targetIndex = currentIndex - (isGridLayout ? crossAxisCount : 1);
    } else if (key == LogicalKeyboardKey.arrowRight) {
      targetIndex = currentIndex + 1;
    } else if (key == LogicalKeyboardKey.arrowLeft) {
      targetIndex = currentIndex - 1;
    } else if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      if (!hasExistingFocus) {
        _focusItemAtIndex(
          items: items,
          index: currentIndex,
          focusFolderPath: focusFolderPath,
          focusFilePath: focusFilePath,
        );
        return KeyEventResult.handled;
      }
      activateEntity(items[currentIndex]);
      return KeyEventResult.handled;
    } else {
      return KeyEventResult.ignored;
    }

    final int newIndex = targetIndex.clamp(0, items.length - 1).toInt();
    _focusItemAtIndex(
      items: items,
      index: newIndex,
      focusFolderPath: focusFolderPath,
      focusFilePath: focusFilePath,
    );
    return KeyEventResult.handled;
  }

  List<FileSystemEntity> _getNavigableItems(
      FolderListState state, String? currentFilter) {
    if (state.currentSearchTag != null || state.currentSearchQuery != null) {
      return List<FileSystemEntity>.from(state.searchResults);
    }

    if (currentFilter != null && currentFilter.isNotEmpty) {
      return List<FileSystemEntity>.from(state.filteredFiles);
    }

    return [
      ...state.folders.whereType<FileSystemEntity>(),
      ...state.files.whereType<FileSystemEntity>(),
    ];
  }

  void _focusItemAtIndex({
    required List<FileSystemEntity> items,
    required int index,
    required void Function(String folderPath) focusFolderPath,
    required void Function(String filePath) focusFilePath,
  }) {
    if (index < 0 || index >= items.length) return;

    final FileSystemEntity target = items[index];
    focusedPath = target.path;

    if (target is Directory) {
      focusFolderPath(target.path);
    } else if (target is File) {
      focusFilePath(target.path);
    }
  }
}
