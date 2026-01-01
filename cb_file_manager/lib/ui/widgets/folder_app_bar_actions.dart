import 'package:flutter/material.dart';
import 'package:cb_file_manager/ui/screens/folder_list/folder_list_state.dart';
import 'package:cb_file_manager/ui/components/common/shared_action_bar.dart';
import 'package:cb_file_manager/ui/screens/media_gallery/image_gallery_screen.dart';
import 'package:cb_file_manager/ui/screens/media_gallery/video_gallery_screen.dart';

/// Builder for folder app bar actions
class FolderAppBarActions {
  /// Build action widgets for the app bar
  static List<Widget> buildActions({
    required BuildContext context,
    required FolderListState folderListState,
    required String currentPath,
    required bool isNetworkPath,
    required Function(SortOption) onSortOptionSelected,
    required VoidCallback onViewModeToggled,
    required Function(ViewMode) onViewModeSelected,
    required VoidCallback onRefresh,
    required VoidCallback onSearchPressed,
    required VoidCallback onSelectionModeToggled,
    required VoidCallback onManageTagsPressed,
    required Function(int) onGridZoomChange,
    required VoidCallback onColumnSettingsPressed,
    required Function(String)? onGallerySelected,
  }) {
    return SharedActionBar.buildCommonActions(
      context: context,
      onSearchPressed: onSearchPressed,
      onSortOptionSelected: onSortOptionSelected,
      currentSortOption: folderListState.sortOption,
      viewMode: folderListState.viewMode,
      onViewModeToggled: onViewModeToggled,
      onViewModeSelected: onViewModeSelected,
      onRefresh: onRefresh,
      onGridSizePressed: folderListState.viewMode == ViewMode.grid
          ? () => SharedActionBar.showGridSizeDialog(
                context,
                currentGridSize: folderListState.gridZoomLevel,
                onApply: onGridZoomChange,
              )
          : null,
      onColumnSettingsPressed: folderListState.viewMode == ViewMode.details
          ? onColumnSettingsPressed
          : null,
      onSelectionModeToggled: onSelectionModeToggled,
      onManageTagsPressed: onManageTagsPressed,
      onGallerySelected: isNetworkPath
          ? null
          : (value) {
              if (value == 'image_gallery') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ImageGalleryScreen(
                      path: currentPath,
                      recursive: false,
                    ),
                  ),
                );
              } else if (value == 'video_gallery') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => VideoGalleryScreen(
                      path: currentPath,
                      recursive: false,
                    ),
                  ),
                ).then((result) {
                  if (onGallerySelected != null) {
                    onGallerySelected(value);
                  }
                });
              }
            },
      currentPath: currentPath,
    );
  }
}
