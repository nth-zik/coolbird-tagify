import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:cb_file_manager/helpers/ui/frame_timing_optimizer.dart';
import 'package:cb_file_manager/ui/screens/folder_list/folder_list_state.dart';
import 'package:cb_file_manager/ui/screens/folder_list/components/index.dart'
    as folder_list_components;
import 'package:cb_file_manager/bloc/selection/selection.dart';
import 'package:cb_file_manager/ui/tab_manager/core/tabbed_folder/tabbed_folder_drag_selection_controller.dart';
import 'package:cb_file_manager/ui/utils/fluent_background.dart';

/// Static factory class for building file list views in different modes
class FileListViewBuilder {
  /// Build the appropriate view based on the current view mode
  static Widget build({
    required FolderListState state,
    required SelectionState selectionState,
    required bool isDesktopPlatform,
    required Function(String) onNavigateToPath,
    required Function(File, bool) onFileTap,
    required Function(String, {bool shiftSelect, bool ctrlSelect})
        toggleFileSelection,
    required Function(String, {bool shiftSelect, bool ctrlSelect})
        toggleFolderSelection,
    required VoidCallback clearSelection,
    required TabbedFolderDragSelectionController dragSelectionController,
    required bool showFileTags,
    required Function(BuildContext, String, List<String>) showDeleteTagDialog,
    required Function(BuildContext, String) showAddTagToFileDialog,
    required VoidCallback toggleSelectionMode,
    required ColumnVisibility columnVisibility,
    required Function(BuildContext, Offset) showContextMenu,
  }) {
    // Apply frame timing optimizations before heavy list/grid operations
    FrameTimingOptimizer().optimizeBeforeHeavyOperation();

    // Use separate builders for each view type to prevent complete tree rebuilds
    if (state.viewMode == ViewMode.grid) {
      return _buildGridView(
        state: state,
        selectionState: selectionState,
        isDesktopPlatform: isDesktopPlatform,
        onNavigateToPath: onNavigateToPath,
        onFileTap: onFileTap,
        toggleFileSelection: toggleFileSelection,
        toggleFolderSelection: toggleFolderSelection,
        clearSelection: clearSelection,
        dragSelectionController: dragSelectionController,
        showFileTags: showFileTags,
        showContextMenu: showContextMenu,
        toggleSelectionMode: toggleSelectionMode,
      );
    } else if (state.viewMode == ViewMode.details) {
      return _buildDetailsView(
        state: state,
        selectionState: selectionState,
        isDesktopPlatform: isDesktopPlatform,
        onNavigateToPath: onNavigateToPath,
        onFileTap: onFileTap,
        toggleFileSelection: toggleFileSelection,
        clearSelection: clearSelection,
        dragSelectionController: dragSelectionController,
        showDeleteTagDialog: showDeleteTagDialog,
        showAddTagToFileDialog: showAddTagToFileDialog,
        toggleSelectionMode: toggleSelectionMode,
        columnVisibility: columnVisibility,
        showFileTags: showFileTags,
        showContextMenu: showContextMenu,
      );
    } else {
      return _buildListView(
        state: state,
        selectionState: selectionState,
        isDesktopPlatform: isDesktopPlatform,
        onNavigateToPath: onNavigateToPath,
        onFileTap: onFileTap,
        toggleFileSelection: toggleFileSelection,
        toggleFolderSelection: toggleFolderSelection,
        clearSelection: clearSelection,
        dragSelectionController: dragSelectionController,
        showContextMenu: showContextMenu,
      );
    }
  }

  /// Build grid view for files and folders
  static Widget _buildGridView({
    required FolderListState state,
    required SelectionState selectionState,
    required bool isDesktopPlatform,
    required Function(String) onNavigateToPath,
    required Function(File, bool) onFileTap,
    required Function(String, {bool shiftSelect, bool ctrlSelect})
        toggleFileSelection,
    required Function(String, {bool shiftSelect, bool ctrlSelect})
        toggleFolderSelection,
    required VoidCallback clearSelection,
    required TabbedFolderDragSelectionController dragSelectionController,
    required bool showFileTags,
    required Function(BuildContext, Offset) showContextMenu,
    required VoidCallback toggleSelectionMode,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        FluentBackground(
          blurAmount: 8.0,
          opacity: 0.2,
          enableBlur: isDesktopPlatform,
          child: BlocBuilder<SelectionBloc, SelectionState>(
            builder: (context, selectionState) {
              return GestureDetector(
                onTap: () {
                  if (selectionState.isSelectionMode) {
                    clearSelection();
                  }
                },
                onSecondaryTapUp: (details) {
                  showContextMenu(context, details.globalPosition);
                },
                onPanStart: isDesktopPlatform
                    ? (details) {
                        dragSelectionController.start(details.localPosition);
                      }
                    : null,
                onPanUpdate: isDesktopPlatform
                    ? (details) {
                        dragSelectionController.update(details.localPosition);
                      }
                    : null,
                onPanEnd: isDesktopPlatform
                    ? (details) {
                        dragSelectionController.end();
                      }
                    : null,
                behavior: HitTestBehavior.translucent,
                child: Listener(
                  onPointerSignal: (PointerSignalEvent event) {
                    if (state.viewMode != ViewMode.grid) return;
                    if (event is PointerScrollEvent) {
                      if (RawKeyboard.instance.keysPressed
                              .contains(LogicalKeyboardKey.controlLeft) ||
                          RawKeyboard.instance.keysPressed
                              .contains(LogicalKeyboardKey.controlRight)) {
                        GestureBinding.instance.pointerSignalResolver
                            .resolve(event);
                      }
                    }
                  },
                  child: RepaintBoundary(
                    child: GridView.builder(
                      padding: const EdgeInsets.all(8.0),
                      physics: const ClampingScrollPhysics(),
                      cacheExtent: 1500,
                      addAutomaticKeepAlives: false,
                      addRepaintBoundaries: true,
                      addSemanticIndexes: false,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: state.gridZoomLevel,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        childAspectRatio: 0.8,
                      ),
                      itemCount: state.folders.length + state.files.length,
                      itemBuilder: (context, index) {
                        final String itemPath = index < state.folders.length
                            ? state.folders[index].path
                            : state.files[index - state.folders.length].path;

                        final bool isSelected =
                            selectionState.isPathSelected(itemPath);

                        return LayoutBuilder(builder:
                            (BuildContext context, BoxConstraints constraints) {
                          if (isDesktopPlatform) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              try {
                                final RenderBox? renderBox =
                                    context.findRenderObject() as RenderBox?;
                                if (renderBox != null &&
                                    renderBox.hasSize &&
                                    renderBox.attached) {
                                  final position =
                                      renderBox.localToGlobal(Offset.zero);
                                  dragSelectionController.registerItemPosition(
                                      itemPath,
                                      Rect.fromLTWH(
                                          position.dx,
                                          position.dy,
                                          renderBox.size.width,
                                          renderBox.size.height));
                                }
                              } catch (e) {
                                debugPrint('Layout error in grid view: $e');
                              }
                            });
                          }

                          if (index < state.folders.length) {
                            final folder = state.folders[index] as Directory;
                            return KeyedSubtree(
                              key: ValueKey('folder-grid-${folder.path}'),
                              child: RepaintBoundary(
                                child: FluentBackground.container(
                                  context: context,
                                  enableBlur: isDesktopPlatform,
                                  padding: EdgeInsets.zero,
                                  blurAmount: 5.0,
                                  opacity: isSelected ? 0.8 : 0.6,
                                  backgroundColor: isSelected
                                      ? Theme.of(context)
                                          .colorScheme
                                          .primaryContainer
                                          .withValues(alpha: 0.6)
                                      : Theme.of(context)
                                          .cardColor
                                          .withValues(alpha: 0.4),
                                  child: folder_list_components.FolderGridItem(
                                    key: ValueKey(
                                        'folder-grid-item-${folder.path}'),
                                    folder: folder,
                                    onNavigate: onNavigateToPath,
                                    isSelected: isSelected,
                                    toggleFolderSelection:
                                        toggleFolderSelection,
                                    isDesktopMode: isDesktopPlatform,
                                    lastSelectedPath:
                                        selectionState.lastSelectedPath,
                                    clearSelectionMode: clearSelection,
                                  ),
                                ),
                              ),
                            );
                          } else {
                            final file = state
                                .files[index - state.folders.length] as File;
                            return KeyedSubtree(
                              key: ValueKey('file-grid-${file.path}'),
                              child: RepaintBoundary(
                                child: FluentBackground.container(
                                  context: context,
                                  enableBlur: isDesktopPlatform,
                                  padding: EdgeInsets.zero,
                                  blurAmount: 5.0,
                                  opacity: isSelected ? 0.8 : 0.6,
                                  backgroundColor: isSelected
                                      ? Theme.of(context)
                                          .colorScheme
                                          .primaryContainer
                                          .withValues(alpha: 0.6)
                                      : Theme.of(context)
                                          .cardColor
                                          .withValues(alpha: 0.4),
                                  child: folder_list_components.FileGridItem(
                                    key:
                                        ValueKey('file-grid-item-${file.path}'),
                                    file: file,
                                    state: state,
                                    isSelectionMode:
                                        selectionState.isSelectionMode,
                                    isSelected: isSelected,
                                    toggleFileSelection: toggleFileSelection,
                                    toggleSelectionMode: toggleSelectionMode,
                                    onFileTap: onFileTap,
                                    isDesktopMode: isDesktopPlatform,
                                    lastSelectedPath:
                                        selectionState.lastSelectedPath,
                                    showFileTags: showFileTags,
                                  ),
                                ),
                              ),
                            );
                          }
                        });
                      },
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        dragSelectionController.buildOverlay(),
      ],
    );
  }

  /// Build details view for files and folders
  static Widget _buildDetailsView({
    required FolderListState state,
    required SelectionState selectionState,
    required bool isDesktopPlatform,
    required Function(String) onNavigateToPath,
    required Function(File, bool) onFileTap,
    required Function(String, {bool shiftSelect, bool ctrlSelect})
        toggleFileSelection,
    required VoidCallback clearSelection,
    required TabbedFolderDragSelectionController dragSelectionController,
    required Function(BuildContext, String, List<String>) showDeleteTagDialog,
    required Function(BuildContext, String) showAddTagToFileDialog,
    required VoidCallback toggleSelectionMode,
    required ColumnVisibility columnVisibility,
    required bool showFileTags,
    required Function(BuildContext, Offset) showContextMenu,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        FluentBackground(
          blurAmount: 8.0,
          opacity: 0.2,
          enableBlur: isDesktopPlatform,
          child: BlocBuilder<SelectionBloc, SelectionState>(
            builder: (context, selectionState) {
              return GestureDetector(
                onTap: () {
                  if (selectionState.isSelectionMode) {
                    clearSelection();
                  }
                },
                onSecondaryTapUp: (details) {
                  showContextMenu(context, details.globalPosition);
                },
                onPanStart: isDesktopPlatform
                    ? (details) {
                        dragSelectionController.start(details.localPosition);
                      }
                    : null,
                onPanUpdate: isDesktopPlatform
                    ? (details) {
                        dragSelectionController.update(details.localPosition);
                      }
                    : null,
                onPanEnd: isDesktopPlatform
                    ? (details) {
                        dragSelectionController.end();
                      }
                    : null,
                behavior: HitTestBehavior.translucent,
                child: RepaintBoundary(
                  child: folder_list_components.FileView(
                    files: state.files.whereType<File>().toList(),
                    folders: state.folders.whereType<Directory>().toList(),
                    state: state,
                    isSelectionMode: selectionState.isSelectionMode,
                    isGridView: false,
                    selectedFiles: selectionState.allSelectedPaths,
                    toggleFileSelection: toggleFileSelection,
                    toggleSelectionMode: toggleSelectionMode,
                    showDeleteTagDialog: showDeleteTagDialog,
                    showAddTagToFileDialog: showAddTagToFileDialog,
                    onFolderTap: onNavigateToPath,
                    onFileTap: onFileTap,
                    isDesktopMode: isDesktopPlatform,
                    lastSelectedPath: selectionState.lastSelectedPath,
                    columnVisibility: columnVisibility,
                    showFileTags: showFileTags,
                  ),
                ),
              );
            },
          ),
        ),
        dragSelectionController.buildOverlay(),
      ],
    );
  }

  /// Build list view for files and folders
  static Widget _buildListView({
    required FolderListState state,
    required SelectionState selectionState,
    required bool isDesktopPlatform,
    required Function(String) onNavigateToPath,
    required Function(File, bool) onFileTap,
    required Function(String, {bool shiftSelect, bool ctrlSelect})
        toggleFileSelection,
    required Function(String, {bool shiftSelect, bool ctrlSelect})
        toggleFolderSelection,
    required VoidCallback clearSelection,
    required TabbedFolderDragSelectionController dragSelectionController,
    required Function(BuildContext, Offset) showContextMenu,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        FluentBackground(
          blurAmount: 8.0,
          opacity: 0.2,
          enableBlur: isDesktopPlatform,
          child: BlocBuilder<SelectionBloc, SelectionState>(
            builder: (context, selectionState) {
              return GestureDetector(
                onTap: () {
                  if (selectionState.isSelectionMode) {
                    clearSelection();
                  }
                },
                onSecondaryTapUp: (details) {
                  showContextMenu(context, details.globalPosition);
                },
                onPanStart: isDesktopPlatform
                    ? (details) {
                        dragSelectionController.start(details.localPosition);
                      }
                    : null,
                onPanUpdate: isDesktopPlatform
                    ? (details) {
                        dragSelectionController.update(details.localPosition);
                      }
                    : null,
                onPanEnd: isDesktopPlatform
                    ? (details) {
                        dragSelectionController.end();
                      }
                    : null,
                behavior: HitTestBehavior.translucent,
                child: RepaintBoundary(
                  child: ListView.builder(
                    physics: const ClampingScrollPhysics(),
                    cacheExtent: 800,
                    addAutomaticKeepAlives: false,
                    addRepaintBoundaries: true,
                    addSemanticIndexes: false,
                    itemCount: state.folders.length + state.files.length,
                    itemBuilder: (context, index) {
                      final String itemPath = index < state.folders.length
                          ? state.folders[index].path
                          : state.files[index - state.folders.length].path;

                      final bool isSelected =
                          selectionState.isPathSelected(itemPath);

                      return LayoutBuilder(builder:
                          (BuildContext context, BoxConstraints constraints) {
                        if (isDesktopPlatform) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            try {
                              final RenderBox? renderBox =
                                  context.findRenderObject() as RenderBox?;
                              if (renderBox != null &&
                                  renderBox.hasSize &&
                                  renderBox.attached) {
                                final position =
                                    renderBox.localToGlobal(Offset.zero);
                                dragSelectionController.registerItemPosition(
                                    itemPath,
                                    Rect.fromLTWH(
                                        position.dx,
                                        position.dy,
                                        renderBox.size.width,
                                        renderBox.size.height));
                              }
                            } catch (e) {
                              debugPrint('Layout error in list view: $e');
                            }
                          });
                        }

                        if (index < state.folders.length) {
                          final folder = state.folders[index] as Directory;
                          return KeyedSubtree(
                            key: ValueKey("folder-${folder.path}"),
                            child: FluentBackground(
                              enableBlur: isDesktopPlatform,
                              blurAmount: 3.0,
                              opacity: isSelected ? 0.7 : 0.0,
                              backgroundColor: isSelected
                                  ? Theme.of(context)
                                      .colorScheme
                                      .primaryContainer
                                      .withValues(alpha: 0.6)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8.0),
                              child: RepaintBoundary(
                                child: folder_list_components.FolderItem(
                                  key: ValueKey("folder-item-${folder.path}"),
                                  folder: folder,
                                  onTap: onNavigateToPath,
                                  isSelected: isSelected,
                                  toggleFolderSelection: toggleFolderSelection,
                                  isDesktopMode: isDesktopPlatform,
                                  lastSelectedPath:
                                      selectionState.lastSelectedPath,
                                ),
                              ),
                            ),
                          );
                        } else {
                          final file =
                              state.files[index - state.folders.length] as File;
                          return KeyedSubtree(
                            key: ValueKey("file-${file.path}"),
                            child: FluentBackground(
                              enableBlur: isDesktopPlatform,
                              blurAmount: 3.0,
                              opacity: isSelected ? 0.7 : 0.0,
                              backgroundColor: isSelected
                                  ? Theme.of(context)
                                      .colorScheme
                                      .primaryContainer
                                      .withValues(alpha: 0.6)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8.0),
                              child: RepaintBoundary(
                                child: folder_list_components.FileItem(
                                  key: ValueKey("file-item-${file.path}"),
                                  file: file,
                                  state: state,
                                  isSelectionMode:
                                      selectionState.isSelectionMode,
                                  isSelected: isSelected,
                                  toggleFileSelection: toggleFileSelection,
                                  showDeleteTagDialog:
                                      (context, filePath, tags) {},
                                  showAddTagToFileDialog:
                                      (context, filePath) {},
                                  onFileTap: onFileTap,
                                  isDesktopMode: isDesktopPlatform,
                                  lastSelectedPath:
                                      selectionState.lastSelectedPath,
                                ),
                              ),
                            ),
                          );
                        }
                      });
                    },
                  ),
                ),
              );
            },
          ),
        ),
        dragSelectionController.buildOverlay(),
      ],
    );
  }
}
