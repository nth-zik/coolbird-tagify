import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cb_file_manager/config/languages/app_localizations.dart';
import 'package:cb_file_manager/helpers/media/video_thumbnail_helper.dart';
import 'package:cb_file_manager/ui/tab_manager/core/tab_manager.dart';
import 'package:cb_file_manager/ui/screens/folder_list/folder_list_bloc.dart';
import 'package:cb_file_manager/ui/screens/folder_list/folder_list_event.dart';
import 'package:cb_file_manager/ui/tab_manager/core/tab_data.dart';

/// Controller for handling navigation operations in tabbed folder screens
class NavigationController {
  final String tabId;
  final TabManagerBloc tabManagerBloc;
  final FolderListBloc folderListBloc;
  final Function(String) onPathChanged;
  final Function() onSaveLastAccessedFolder;

  NavigationController({
    required this.tabId,
    required this.tabManagerBloc,
    required this.folderListBloc,
    required this.onPathChanged,
    required this.onSaveLastAccessedFolder,
  });

  /// Navigate to a specific path
  void navigateToPath(
    BuildContext context,
    String path,
    TextEditingController pathController,
    Function(String) clearKeyboardFocus,
  ) {
    // Stop any ongoing thumbnail processing to prevent UI lag
    VideoThumbnailHelper.stopAllProcessing();
    final l10n = AppLocalizations.of(context)!;

    // Clear keyboard focus
    clearKeyboardFocus(path);

    // Update path controller
    pathController.text = path;

    // Clear any search or filter state when navigating
    folderListBloc.add(const ClearSearchAndFilters());

    // Update the tab's path in the TabManager
    tabManagerBloc.add(UpdateTabPath(tabId, path));

    debugPrint('Navigating to path: $path');
    debugPrint('Tab ID: $tabId');

    // Debug: Check navigation history after adding
    final updatedTab = tabManagerBloc.state.tabs.firstWhere(
      (tab) => tab.id == tabId,
      orElse: () => TabData(id: '', name: '', path: ''),
    );
    debugPrint(
        'Navigation history after adding: ${updatedTab.navigationHistory}');
    debugPrint(
        'Navigation history length: ${updatedTab.navigationHistory.length}');

    // Update the folder list to show the new path
    folderListBloc.add(FolderListLoad(path));

    // Save this folder as last accessed
    onSaveLastAccessedFolder();

    // Update the tab name based on the new path
    final pathParts = path.split(Platform.pathSeparator);
    final lastPart = pathParts.lastWhere((part) => part.isNotEmpty,
        orElse: () => l10n.rootFolder);
    final tabName = lastPart.isEmpty ? l10n.rootFolder : lastPart;

    // Update tab name if needed
    tabManagerBloc.add(UpdateTabName(tabId, tabName));

    // Notify path changed
    onPathChanged(path);
  }

  /// Handle path submission when user manually edits the path
  void handlePathSubmit(
    BuildContext context,
    String path,
    String currentPath,
    TextEditingController pathController,
  ) {
    // Handle empty path as drive selection view
    if (path.isEmpty && Platform.isWindows) {
      onPathChanged('');
      pathController.text = '';
      return;
    }

    // Check if path exists
    final directory = Directory(path);
    directory.exists().then((exists) {
      if (exists) {
        navigateToPath(
          context,
          path,
          pathController,
          (_) {}, // Empty keyboard focus clear
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.pathNotAccessible),
            backgroundColor: Colors.red,
          ),
        );
        // Revert to current path
        pathController.text = currentPath;
      }
    });
  }

  /// Handle back button press for Android
  Future<bool> handleBackButton(
    BuildContext context,
    String currentPath,
    TextEditingController pathController,
  ) async {
    try {
      debugPrint('=== _handleBackButton called ===');
      debugPrint('Hardware back button pressed!');
      debugPrint('Back button pressed - current path: $currentPath');

      // Stop any ongoing thumbnail processing when navigating
      VideoThumbnailHelper.stopAllProcessing();

      // First check if we're currently showing search results
      final folderListState = folderListBloc.state;
      if (folderListState.isSearchActive) {
        // Clear search results and reload current directory
        folderListBloc.add(const ClearSearchAndFilters());
        folderListBloc.add(FolderListLoad(currentPath));
        return false; // Don't exit app, we cleared the search
      }

      // Check if we can navigate back in the folder hierarchy
      final currentTab = tabManagerBloc.state.tabs.firstWhere(
        (tab) => tab.id == tabId,
        orElse: () => TabData(id: '', name: '', path: ''),
      );

      debugPrint('Current tab path: ${currentTab.path}');
      debugPrint('Navigation history: ${currentTab.navigationHistory}');
      debugPrint(
          'Navigation history length: ${currentTab.navigationHistory.length}');
      debugPrint(
          'Can navigate back: ${tabManagerBloc.canTabNavigateBack(tabId)}');

      if (tabManagerBloc.canTabNavigateBack(tabId)) {
        final previousPath = tabManagerBloc.getTabPreviousPath(tabId);
        debugPrint('Previous path: $previousPath');
        if (previousPath != null) {
          // Handle empty path case for Windows drive view
          if (previousPath.isEmpty && Platform.isWindows) {
            onPathChanged('');
            pathController.text = '';
            // Update the tab name to indicate we're showing drives
            tabManagerBloc.add(
                UpdateTabName(tabId, AppLocalizations.of(context)!.drivesTab));
            return false; // Don't exit app, we're navigating to drives view
          }

          // Regular path navigation - use the bloc method
          final newPath = tabManagerBloc.backNavigationToPath(tabId);
          debugPrint('Back navigation result: $newPath');
          if (newPath != null) {
            debugPrint('Successfully navigating back to: $newPath');
            onPathChanged(newPath);
            pathController.text = newPath;
            folderListBloc.add(FolderListLoad(newPath));
            debugPrint('=== Back navigation completed successfully ===');
            return false; // Don't exit app, we navigated back
          } else {
            debugPrint('Back navigation failed - newPath is null');
          }
        }
      }

      // For mobile, if we're at root directory, show exit confirmation
      if (Platform.isAndroid || Platform.isIOS) {
        if (currentPath.isEmpty ||
            currentPath == '/storage/emulated/0' ||
            currentPath == '/storage/self/primary') {
          // Show exit confirmation dialog
          debugPrint('At root directory on mobile - showing exit confirmation');
          final shouldExit = await _showExitConfirmation(context);
          debugPrint('Exit confirmation result: $shouldExit');
          return shouldExit;
        }
      }

      // If we can't navigate back in tab, check if we can pop the navigator
      if (Navigator.of(context).canPop()) {
        debugPrint('Popping navigator route');
        Navigator.of(context).pop();
        return false; // Don't exit app
      }

      // If we're at the root and can't navigate back, don't allow back
      debugPrint('At root directory - preventing back navigation');
      return false; // Don't exit app, just prevent back navigation
    } catch (e) {
      debugPrint('Error in _handleBackButton: $e');
      return false; // Don't exit app on error, just prevent back navigation
    }
  }

  /// Show exit confirmation dialog for mobile
  Future<bool> _showExitConfirmation(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.exitApplicationTitle),
        content: Text(l10n.exitApplicationConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: Text(l10n.exit),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// Centralized method to update path and reload folder contents
  void updatePath(
    String newPath,
    TextEditingController pathController,
    String? currentFilter,
    String? currentSearchTag,
  ) {
    // Stop any ongoing thumbnail processing to prevent UI lag
    VideoThumbnailHelper.stopAllProcessing();

    pathController.text = newPath;

    // If navigating to a hash-based tag search, don't clear search
    // and don't try to load it as a directory. The screen handles it.
    if (newPath.startsWith('#search?tag=')) {
      return;
    }

    // Clear any search or filter state when navigating to a normal path
    if (currentFilter != null || currentSearchTag != null) {
      folderListBloc.add(const ClearSearchAndFilters());
    }

    // Load the folder contents with the new path
    folderListBloc.add(FolderListLoad(newPath));

    // Save as last accessed folder
    onSaveLastAccessedFolder();

    // Notify path changed
    onPathChanged(newPath);
  }

  /// Handle result from gallery screens (Video/Image Gallery)
  void handleGalleryResult(BuildContext context, dynamic result) {
    if (result != null && result is Map<String, dynamic>) {
      if (result['action'] == 'openFolder') {
        final folderPath = result['folderPath'] as String;
        debugPrint('Gallery returned openFolder request: $folderPath');

        final l10n = AppLocalizations.of(context)!;
        final folderName = folderPath.split(RegExp(r'[\\\\/]+')).lastWhere(
            (part) => part.isNotEmpty,
            orElse: () => l10n.rootFolder);

        // Open new tab with the folder - using TabNavigator utility
        // Note: This requires importing the tab navigator utility
        // For now, we'll use the TabManagerBloc directly
        tabManagerBloc.add(AddTab(path: folderPath, name: folderName));
      }
    }
  }

  /// Handle mouse back button press
  void handleMouseBackButton(
    BuildContext context,
    String currentPath,
    TextEditingController pathController,
  ) {
    // First check if we're currently showing search results
    final folderListState = folderListBloc.state;
    if (folderListState.isSearchActive) {
      // Clear search results and reload current directory
      folderListBloc.add(const ClearSearchAndFilters());
      folderListBloc.add(FolderListLoad(currentPath));
      return; // Don't navigate back, we're just clearing the search
    }

    if (tabManagerBloc.canTabNavigateBack(tabId)) {
      // Get previous path
      final previousPath = tabManagerBloc.getTabPreviousPath(tabId);

      if (previousPath != null) {
        // Handle empty path case for Windows drive view
        if (previousPath.isEmpty && Platform.isWindows) {
          onPathChanged('');
          pathController.text = '';
          // Update the tab name to indicate we're showing drives
          tabManagerBloc.add(
              UpdateTabName(tabId, AppLocalizations.of(context)!.drivesTab));
        } else {
          // Regular path navigation
          onPathChanged(previousPath);
          pathController.text = previousPath;
        }

        // Use direct method call instead of BLoC event
        tabManagerBloc.backNavigationToPath(tabId);

        // Load the folder content
        folderListBloc.add(FolderListLoad(previousPath));
      }
    }
  }

  /// Handle mouse forward button press
  void handleMouseForwardButton(
    BuildContext context,
    String currentPath,
    TextEditingController pathController,
  ) {
    if (tabManagerBloc.canTabNavigateForward(tabId)) {
      // Get next path
      final nextPath = tabManagerBloc.getTabNextPath(tabId);

      if (nextPath != null) {
        // Handle empty path case for Windows drive view
        if (nextPath.isEmpty && Platform.isWindows) {
          onPathChanged('');
          pathController.text = '';
          // Update the tab name to indicate we're showing drives
          tabManagerBloc.add(
              UpdateTabName(tabId, AppLocalizations.of(context)!.drivesTab));
        } else {
          // Regular path navigation
          onPathChanged(nextPath);
          pathController.text = nextPath;
        }

        // Instead of using GoForwardInTabHistory, directly use the forwardNavigationToPath method
        // This will avoid the unregistered event handler error
        final String? actualPath =
            tabManagerBloc.forwardNavigationToPath(tabId);

        // If navigation was successful, load the folder content
        if (actualPath != null) {
          folderListBloc.add(FolderListLoad(actualPath));
        }
      }
    }
  }
}
