import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:cb_file_manager/ui/screens/folder_list/folder_list_state.dart';
import 'package:cb_file_manager/helpers/frame_timing_optimizer.dart';
import 'package:flutter/gestures.dart'; // Import for PointerSignalEvent
import 'package:flutter/services.dart'; // Import for RawKeyboard

import 'file_item.dart';
import 'file_grid_item.dart';
import 'folder_item.dart';
import 'folder_grid_item.dart';
import 'file_details_item.dart';
import 'folder_details_item.dart';

class FileView extends StatelessWidget {
  final List<File> files;
  final List<Directory> folders;
  final FolderListState state;
  final bool isSelectionMode;
  final bool isGridView;
  final List<String> selectedFiles;
  final Function(String, {bool shiftSelect, bool ctrlSelect})
      toggleFileSelection;
  final Function() toggleSelectionMode;
  final Function(BuildContext, String, List<String>) showDeleteTagDialog;
  final Function(BuildContext, String) showAddTagToFileDialog;
  final Function(String)? onFolderTap;
  final Function(File, bool)? onFileTap;
  final Function()? onThumbnailGenerated;
  final Function(int)? onZoomChanged; // Thêm callback mới cho thay đổi zoom
  final bool isDesktopMode;
  final String? lastSelectedPath;
  final ColumnVisibility columnVisibility;

  const FileView({
    Key? key,
    required this.files,
    required this.folders,
    required this.state,
    required this.isSelectionMode,
    required this.isGridView,
    required this.selectedFiles,
    required this.toggleFileSelection,
    required this.toggleSelectionMode,
    required this.showDeleteTagDialog,
    required this.showAddTagToFileDialog,
    this.onFolderTap,
    this.onFileTap,
    this.onThumbnailGenerated,
    this.onZoomChanged, // Thêm parameter
    this.isDesktopMode = false,
    this.lastSelectedPath,
    this.columnVisibility = const ColumnVisibility(),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Optimize frame timing before building view
    FrameTimingOptimizer().optimizeBeforeHeavyOperation();

    if (isGridView) {
      return _buildGridView();
    } else if (state.viewMode == ViewMode.details) {
      return _buildDetailsView();
    } else {
      return _buildListView();
    }
  }

  Widget _buildListView() {
    // Optimize scrolling with frame timing
    FrameTimingOptimizer().optimizeScrolling();

    return ListView.builder(
      // Add better scrolling physics for smoother scrolling
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      // Add caching for better performance during scrolling
      cacheExtent: 500,
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      itemCount: folders.length + files.length,
      itemBuilder: (context, index) {
        // Use RepaintBoundary to reduce rendering load during scrolling
        return RepaintBoundary(
          child: index < folders.length
              ? FolderItem(folder: folders[index], onTap: onFolderTap)
              : FileItem(
                  file: files[index - folders.length],
                  state: state,
                  isSelectionMode: isSelectionMode,
                  isSelected: selectedFiles
                      .contains(files[index - folders.length].path),
                  toggleFileSelection: toggleFileSelection,
                  showDeleteTagDialog: showDeleteTagDialog,
                  showAddTagToFileDialog: showAddTagToFileDialog,
                  onFileTap: onFileTap,
                  isDesktopMode: isDesktopMode,
                  lastSelectedPath: lastSelectedPath,
                ),
        );
      },
    );
  }

  Widget _buildDetailsView() {
    // Optimize scrolling with frame timing
    FrameTimingOptimizer().optimizeScrolling();

    // Define text style for headers once to be reused
    const TextStyle headerStyle = TextStyle(
      fontWeight: FontWeight.bold,
      color: Colors.black87,
    );

    // Debug selection count
    print(
        "FileView _buildDetailsView - Selected files count: ${selectedFiles.length}");

    return Column(
      children: [
        // Column headers for details view with info tooltip
        Stack(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
              ),
              child: Row(
                children: [
                  // Name column (always visible)
                  Expanded(
                    flex: 3,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 10.0, horizontal: 12.0),
                      child: Row(
                        children: [
                          Text(
                            'Tên',
                            style: headerStyle,
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.arrow_downward,
                              size: 16, color: Colors.black87),
                        ],
                      ),
                    ),
                  ),

                  // Type column
                  if (columnVisibility.type)
                    Expanded(
                      flex: 2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 10.0, horizontal: 12.0),
                        child: Text(
                          'Loại',
                          style: headerStyle,
                        ),
                      ),
                    ),

                  // Size column
                  if (columnVisibility.size)
                    Expanded(
                      flex: 1,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 10.0, horizontal: 12.0),
                        child: Text(
                          'Kích thước',
                          style: headerStyle,
                        ),
                      ),
                    ),

                  // Date modified column
                  if (columnVisibility.dateModified)
                    Expanded(
                      flex: 2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 10.0, horizontal: 12.0),
                        child: Text(
                          'Ngày sửa đổi',
                          style: headerStyle,
                        ),
                      ),
                    ),

                  // Date created column
                  if (columnVisibility.dateCreated)
                    Expanded(
                      flex: 2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 10.0, horizontal: 12.0),
                        child: Text(
                          'Ngày tạo',
                          style: headerStyle,
                        ),
                      ),
                    ),

                  // Attributes column
                  if (columnVisibility.attributes)
                    Expanded(
                      flex: 1,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 10.0, horizontal: 12.0),
                        child: Text(
                          'Thuộc tính',
                          style: headerStyle,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Add info button with tooltip about customizing columns
            Positioned(
              right: 8,
              top: 8,
              child: Tooltip(
                message:
                    'Nhấn nút cài đặt cột ở thanh công cụ trên cùng để tùy chỉnh các cột hiển thị',
                child: Icon(
                  Icons.info_outline,
                  size: 16,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
          ],
        ),

        // List of files and folders
        Expanded(
          child: ListView.builder(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            cacheExtent: 500,
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            itemCount: folders.length + files.length,
            itemBuilder: (context, index) {
              // Add alternating row colors to make it look more like a details table
              final bool isEvenRow = index % 2 == 0;
              final Color rowColor = isEvenRow
                  ? Colors.transparent
                  : Colors.grey.withOpacity(0.03);

              return Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 2.0, horizontal: 12.0),
                decoration: BoxDecoration(
                  color: rowColor,
                ),
                child: RepaintBoundary(
                  child: index < folders.length
                      ? FolderDetailsItem(
                          folder: folders[index],
                          onTap: onFolderTap,
                          isSelected:
                              selectedFiles.contains(folders[index].path),
                          columnVisibility: columnVisibility,
                          toggleFolderSelection: toggleFileSelection,
                          isDesktopMode: isDesktopMode,
                          lastSelectedPath: lastSelectedPath,
                        )
                      : FileDetailsItem(
                          file: files[index - folders.length],
                          state: state,
                          isSelected: selectedFiles
                              .contains(files[index - folders.length].path),
                          columnVisibility: columnVisibility,
                          toggleFileSelection: toggleFileSelection,
                          showDeleteTagDialog: showDeleteTagDialog,
                          showAddTagToFileDialog: showAddTagToFileDialog,
                          onTap: onFileTap,
                          isDesktopMode: isDesktopMode,
                          lastSelectedPath: lastSelectedPath,
                        ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildGridView() {
    // Optimize scrolling with frame timing
    FrameTimingOptimizer().optimizeScrolling();

    // Wrap the GridView with a Listener to detect mouse wheel events
    return Listener(
      onPointerSignal: (PointerSignalEvent event) {
        // Only process if we have a zoom handler
        if (onZoomChanged == null) return;

        // Handle mouse wheel events with Ctrl key
        if (event is PointerScrollEvent) {
          if (RawKeyboard.instance.keysPressed
                  .contains(LogicalKeyboardKey.controlLeft) ||
              RawKeyboard.instance.keysPressed
                  .contains(LogicalKeyboardKey.controlRight)) {
            final int direction = event.scrollDelta.dy > 0 ? 1 : -1;
            onZoomChanged!(direction);
            GestureBinding.instance.pointerSignalResolver.resolve(event);
          }
        }
      },
      child: GridView.builder(
        // Add better scrolling physics for smoother scrolling
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        // Add caching for better scroll performance
        cacheExtent: 1000,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: state.gridZoomLevel,
          childAspectRatio: 0.8,
          crossAxisSpacing: 8.0,
          mainAxisSpacing: 8.0,
        ),
        padding: const EdgeInsets.all(8.0),
        itemCount: folders.length + files.length,
        itemBuilder: (context, index) {
          // Use RepaintBoundary for better rendering performance
          return RepaintBoundary(
            child: index < folders.length
                ? FolderGridItem(
                    folder: folders[index],
                    onNavigate: onFolderTap ?? (_) {},
                    isSelected: selectedFiles.contains(folders[index].path),
                    toggleFolderSelection: toggleFileSelection,
                    isDesktopMode: isDesktopMode,
                    lastSelectedPath: lastSelectedPath,
                  )
                : FileGridItem(
                    file: files[index - folders.length],
                    state: state,
                    isSelected: selectedFiles
                        .contains(files[index - folders.length].path),
                    toggleFileSelection: toggleFileSelection,
                    toggleSelectionMode: toggleSelectionMode,
                    isSelectionMode: isSelectionMode,
                    onFileTap: onFileTap,
                    isDesktopMode: isDesktopMode,
                    lastSelectedPath: lastSelectedPath,
                    onThumbnailGenerated: onThumbnailGenerated,
                  ),
          );
        },
      ),
    );
  }
}
