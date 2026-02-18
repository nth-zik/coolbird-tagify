import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../screens/folder_list/folder_list_bloc.dart';
import '../screens/folder_list/folder_list_event.dart';
import '../tab_manager/core/tab_manager.dart';
import '../tab_manager/core/tab_paths.dart';

/// Manages lifecycle events for tabbed folder screens
///
/// Handles:
/// - Tab activation/deactivation logic
/// - Path synchronization with TabManager
/// - Content reloading when tab becomes active
/// - Widget update handling
class TabLifecycleManager {
  /// Handles didChangeDependencies lifecycle event
  ///
  /// Synchronizes tab path and reloads content when tab becomes active
  static void handleDidChangeDependencies({
    required BuildContext context,
    required String tabId,
    required String currentPath,
    required FolderListBloc folderListBloc,
    required bool isMounted,
    required Function(String) onPathUpdate,
  }) {
    debugPrint(
        '🟡 [TabLifecycleManager] handleDidChangeDependencies called for tab: $tabId');
    debugPrint('🟡 [TabLifecycleManager] Current path: $currentPath');

    // Set up a listener for TabManagerBloc state changes
    final tabBloc = BlocProvider.of<TabManagerBloc>(context);
    final activeTab = tabBloc.state.activeTab;

    debugPrint(
        '🟡 [TabLifecycleManager] Active tab: ${activeTab?.id}, Active tab path: ${activeTab?.path}');

    if (activeTab != null &&
        activeTab.id == tabId &&
        activeTab.path != currentPath) {
      debugPrint(
          '🟡 [TabLifecycleManager] Path mismatch detected, updating path from $currentPath to ${activeTab.path}');
      // Only update if the path has actually changed
      onPathUpdate(activeTab.path);
    }

    // Only reload if the tab is active AND content is actually missing or outdated
    if (activeTab != null && activeTab.id == tabId) {
      // Check if we actually need to reload
      final currentState = folderListBloc.state;
      final shouldReload = currentState.currentPath.path != currentPath ||
          (currentState.folders.isEmpty &&
              currentState.files.isEmpty &&
              currentState.searchResults.isEmpty &&
              !currentState.isLoading &&
              currentPath.isNotEmpty &&
              !currentPath.startsWith('#search?tag=') &&
              !isDrivesPath(currentPath));

      debugPrint('🟡 [TabLifecycleManager] Should reload: $shouldReload');
      debugPrint(
          '🟡 [TabLifecycleManager] Current state path: ${currentState.currentPath.path}');
      debugPrint(
          '🟡 [TabLifecycleManager] Folders: ${currentState.folders.length}, Files: ${currentState.files.length}');
      debugPrint(
          '🟡 [TabLifecycleManager] Is loading: ${currentState.isLoading}');

      if (shouldReload) {
        debugPrint(
            '🟡 [TabLifecycleManager] Scheduling reload for path: $currentPath');
        // Add a small delay to ensure proper state synchronization
        Future.delayed(const Duration(milliseconds: 50), () {
          if (isMounted) {
            debugPrint(
                '🟡 [TabLifecycleManager] Tab $tabId became active, reloading content for path: $currentPath');

            // Don't try to load virtual paths as directories.
            if (currentPath.startsWith('#') || currentPath.isEmpty) {
              debugPrint(
                  '🟡 [TabLifecycleManager] Skipping directory load for virtual path: $currentPath');
              return;
            }

            debugPrint(
                '🟡 [TabLifecycleManager] Triggering FolderListLoad for: $currentPath');
            folderListBloc.add(FolderListLoad(currentPath));
          }
        });
      }
    }
  }

  /// Handles didUpdateWidget lifecycle event
  ///
  /// Updates path when widget properties change
  static void handleDidUpdateWidget({
    required String oldPath,
    required String newPath,
    required String currentPath,
    required Function(String) onPathUpdate,
  }) {
    // If the path prop changes from parent, update our current path
    // and reload the folder list with the new path
    if (newPath != oldPath && newPath != currentPath) {
      onPathUpdate(newPath);
    }
  }
}
