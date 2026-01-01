import 'package:flutter/material.dart';
import 'package:cb_file_manager/helpers/core/user_preferences.dart';
import 'package:cb_file_manager/ui/screens/folder_list/folder_list_bloc.dart';
import 'package:cb_file_manager/ui/screens/folder_list/folder_list_event.dart';
import 'package:cb_file_manager/ui/screens/folder_list/folder_list_state.dart';
import 'package:cb_file_manager/helpers/files/folder_sort_manager.dart';
import 'package:cb_file_manager/ui/components/common/shared_action_bar.dart';

/// Mixin for managing user preferences related to folder list display
///
/// This mixin handles:
/// - View mode (list, grid, details)
/// - Grid zoom level
/// - Column visibility for details view
/// - File tags display
/// - Sort options
///
/// Usage:
/// ```dart
/// class MyState extends State<MyWidget> with PreferencesManagerMixin {
///   @override
///   FolderListBloc get folderListBloc => _folderListBloc;
///
///   @override
///   void initState() {
///     super.initState();
///     loadPreferences();
///   }
/// }
/// ```
mixin PreferencesManagerMixin<T extends StatefulWidget> on State<T> {
  /// The FolderListBloc instance to send events to
  FolderListBloc get folderListBloc;

  /// Current view mode (list, grid, or details)
  ViewMode viewMode = ViewMode.list; // Default to list view

  /// Current grid zoom level (number of columns in grid view)
  int gridZoomLevel = 4; // Default zoom level

  /// Column visibility settings for details view
  ColumnVisibility columnVisibility = const ColumnVisibility(); // Default visibility

  /// Whether to show file tags
  bool showFileTags = true; // Default value to prevent LateInitializationError

  /// Load all preferences from storage
  Future<void> loadPreferences() async {
    try {
      final UserPreferences prefs = UserPreferences.instance;
      await prefs.init();

      final loadedViewMode = await prefs.getViewMode();
      final sortOption = await prefs.getSortOption();
      final loadedGridZoomLevel = await prefs.getGridZoomLevel();
      final loadedColumnVisibility = await prefs.getColumnVisibility();
      final loadedShowFileTags = await prefs.getShowFileTags();

      if (mounted) {
        setState(() {
          viewMode = loadedViewMode;
          gridZoomLevel = loadedGridZoomLevel;
          columnVisibility = loadedColumnVisibility;
          showFileTags = loadedShowFileTags;
        });

        folderListBloc.add(SetViewMode(loadedViewMode));
        folderListBloc.add(SetSortOption(sortOption));
        folderListBloc.add(SetGridZoom(loadedGridZoomLevel));
      }
    } catch (e) {
      debugPrint('Error loading preferences: $e');
    }
  }

  /// Save view mode setting to storage
  Future<void> saveViewModeSetting(ViewMode mode) async {
    try {
      final UserPreferences prefs = UserPreferences.instance;
      await prefs.init();
      await prefs.setViewMode(mode);
    } catch (e) {
      debugPrint('Error saving view mode: $e');
    }
  }

  /// Save sort option setting to storage
  Future<void> saveSortSetting(SortOption option, String currentPath) async {
    try {
      final UserPreferences prefs = UserPreferences.instance;
      await prefs.init();
      await prefs.setSortOption(option);
      final folderSortManager = FolderSortManager();
      await folderSortManager.saveFolderSortOption(currentPath, option);
    } catch (e) {
      debugPrint('Error saving sort option: $e');
    }
  }

  /// Save grid zoom level setting to storage
  Future<void> saveGridZoomSetting(int zoomLevel) async {
    try {
      final UserPreferences prefs = UserPreferences.instance;
      await prefs.init();
      await prefs.setGridZoomLevel(zoomLevel);
      setState(() {
        gridZoomLevel = zoomLevel;
      });
    } catch (e) {
      debugPrint('Error saving grid zoom level: $e');
    }
  }

  /// Toggle between view modes (list -> grid -> details -> list)
  void toggleViewMode() {
    setState(() {
      // Cycle through view modes: list -> grid -> details -> list
      if (viewMode == ViewMode.list) {
        viewMode = ViewMode.grid;
      } else if (viewMode == ViewMode.grid) {
        viewMode = ViewMode.details;
      } else {
        viewMode = ViewMode.list;
      }
    });

    folderListBloc.add(SetViewMode(viewMode));
    saveViewModeSetting(viewMode);
  }

  /// Set view mode directly to a specific mode
  void setViewMode(ViewMode mode, {String? tabId}) {
    setState(() {
      viewMode = mode;
    });

    folderListBloc.add(SetViewMode(viewMode));
    saveViewModeSetting(viewMode);
  }

  /// Handle grid zoom level change
  void handleGridZoomChange(int zoomLevel) {
    folderListBloc.add(SetGridZoom(zoomLevel));
    saveGridZoomSetting(zoomLevel);
  }

  /// Handle zoom level change via mouse wheel or other input
  ///
  /// [direction] - positive to zoom in (more columns), negative to zoom out (fewer columns)
  void handleZoomLevelChange(int direction) {
    // Reverse direction: increase zoom when scrolling down (direction > 0), decrease when scrolling up (direction < 0)
    final currentZoom = gridZoomLevel;
    final newZoom = (currentZoom + direction).clamp(
      UserPreferences.minGridZoomLevel,
      UserPreferences.maxGridZoomLevel,
    );

    if (newZoom != currentZoom) {
      folderListBloc.add(SetGridZoom(newZoom));
      saveGridZoomSetting(newZoom);
    }
  }

  /// Show column visibility dialog for details view
  void showColumnVisibilityDialog(BuildContext context) {
    SharedActionBar.showColumnVisibilityDialog(
      context,
      currentVisibility: columnVisibility,
      onApply: (ColumnVisibility visibility) async {
        setState(() {
          columnVisibility = visibility;
        });

        try {
          final UserPreferences prefs = UserPreferences.instance;
          await prefs.init();
          await prefs.setColumnVisibility(visibility);
        } catch (e) {
          debugPrint('Error saving column visibility: $e');
        }
      },
    );
  }
}
