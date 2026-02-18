part of 'tabbed_folder_list_screen.dart';

extension _TabbedFolderListMobileActions on _TabbedFolderListScreenState {
  // Register mobile actions controller to connect mobile action buttons with this screen
  void _registerMobileActionsControllerImpl() {
    final controller = MobileFileActionsController.forTab(widget.tabId);

    // Register callbacks
    controller.onSearchPressed = () => _showSearchTip(context);
    controller.onSearchSubmitted = (query) => _handleMobileSearch(query);
    controller.onSortOptionSelected = (option) {
      _folderListBloc.add(SetSortOption(option));
      saveSortSetting(option, _currentPath);
    };
    controller.onViewModeToggled = _setViewMode;
    controller.onBack = _handleMouseBackButton;
    controller.onForward = _handleMouseForwardButton;
    controller.onRefresh = _refreshFileList;
    controller.onGridSizePressed = () => SharedActionBar.showGridSizeDialog(
          context,
          currentGridSize: _folderListBloc.state.gridZoomLevel,
          onApply: handleGridZoomChange,
          sizeMode: GridSizeMode.referenceWidth,
        );
    controller.onSelectionModeToggled = _toggleSelectionMode;
    controller.onManageTagsPressed = () {
      tab_components.showManageTagsDialog(
        context,
        _folderListBloc.state.allTags.toList(),
        _folderListBloc.state.currentPath.path,
      );
    };
    // Set initial state
    controller.currentSortOption = _folderListBloc.state.sortOption;
    controller.currentViewMode = _folderListBloc.state.viewMode;
    controller.currentGridSize = _folderListBloc.state.gridZoomLevel;
    controller.currentPath = _currentPath;
    controller.actionBarProfile = _isDrivesPathValue(_currentPath)
        ? MobileActionBarProfile.drivesMinimal
        : MobileActionBarProfile.full;

    // Update controller state when bloc state changes
    _folderListBloc.stream.listen((state) {
      controller.currentSortOption = state.sortOption;
      controller.currentViewMode = state.viewMode;
      controller.currentGridSize = state.gridZoomLevel;
      controller.currentPath = _currentPath;
      controller.actionBarProfile = _isDrivesPathValue(_currentPath)
          ? MobileActionBarProfile.drivesMinimal
          : MobileActionBarProfile.full;
    });
  }

  // Handle mobile inline search
  void _handleMobileSearchImpl(String? query) {
    if (query == null || query.isEmpty) {
      // Clear search
      _folderListBloc.add(const ClearSearchAndFilters());
      return;
    }

    // Get recursive setting from controller
    final controller = MobileFileActionsController.forTab(widget.tabId);
    final isRecursive = controller.isRecursiveSearch;

    // Check if it's a tag search (contains # character)
    if (query.contains('#')) {
      // Extract tags from query
      final tags = query
          .split(' ')
          .where((word) => word.startsWith('#'))
          .map((tag) => tag.substring(1).trim())
          .where((tag) => tag.isNotEmpty)
          .toList();

      if (tags.isEmpty) return;

      // Search by tag (local only for mobile, no recursive for tags)
      if (tags.length == 1) {
        _folderListBloc.add(SearchByTag(tags.first));
      } else {
        _folderListBloc.add(SearchByMultipleTags(tags));
      }
    } else {
      // Search by filename with recursive option
      _folderListBloc.add(SearchByFileName(query, recursive: isRecursive));
    }
  }
}
