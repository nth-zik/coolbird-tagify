import 'dart:io';

import 'package:cb_file_manager/helpers/ui/frame_timing_optimizer.dart';
import 'package:cb_file_manager/ui/screens/media_gallery/image_gallery_screen.dart';
import 'package:cb_file_manager/ui/screens/media_gallery/video_gallery_screen.dart';
import '../../../components/common/shared_action_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cb_file_manager/helpers/core/user_preferences.dart';
import 'package:remixicon/remixicon.dart' as remix;
import 'package:cb_file_manager/ui/widgets/thumbnail_loader.dart';
import 'package:cb_file_manager/ui/widgets/app_progress_indicator.dart';
import 'package:cb_file_manager/ui/utils/file_type_utils.dart';
import '../tab_manager.dart';
import 'package:cb_file_manager/ui/utils/fluent_background.dart';

// Import folder list components with explicit alias
import '../../../screens/folder_list/folder_list_bloc.dart';
import '../../../screens/folder_list/folder_list_event.dart';
import '../../../screens/folder_list/folder_list_state.dart';

// Import selection bloc
import 'package:cb_file_manager/bloc/selection/selection.dart';

// Import our new components with a clear namespace
import '../../components/index.dart' as tab_components;
import '../tab_data.dart';
import 'tabbed_folder_drag_selection_controller.dart';
import 'tabbed_folder_keyboard_controller.dart';
import 'package:cb_file_manager/ui/screens/system_screen_router.dart';

import '../../../components/common/screen_scaffold.dart';
import '../../mobile/mobile_file_actions_controller.dart';
import 'package:cb_file_manager/ui/utils/platform_utils.dart';

// Import extracted foundation components
import 'package:cb_file_manager/ui/controllers/file_operations_handler.dart';
import 'package:cb_file_manager/ui/controllers/lazy_loading_manager.dart';
import 'package:cb_file_manager/ui/menus/folder_background_context_menu.dart';
import 'package:cb_file_manager/ui/mixins/preferences_manager_mixin.dart';
import 'package:cb_file_manager/ui/controllers/search_filter_manager.dart';
import 'package:cb_file_manager/ui/controllers/refresh_controller.dart';
import 'package:cb_file_manager/ui/controllers/navigation_controller.dart';
import 'package:cb_file_manager/ui/controllers/selection_coordinator.dart';
import 'package:cb_file_manager/ui/controllers/tab_lifecycle_manager.dart';
import 'package:cb_file_manager/ui/controllers/tag_search_initializer.dart';
import 'package:cb_file_manager/ui/controllers/app_bar_actions_builder.dart';

// Import extracted view layer components
import 'package:cb_file_manager/ui/widgets/file_list_view_builder.dart';
import 'package:cb_file_manager/ui/controllers/dialog_manager.dart';
import 'package:cb_file_manager/ui/widgets/folder_content_builder.dart';
import 'package:cb_file_manager/ui/widgets/refreshable_file_list_view.dart';

part 'tabbed_folder_list_screen.mobile_actions.dart';
part 'tabbed_folder_list_screen.refresh.dart';

/// A modified version of FolderListScreen that works with the tab system
class TabbedFolderListScreen extends StatefulWidget {
  final String path;
  final String tabId;
  final bool showAppBar; // Thêm tham số để kiểm soát việc hiển thị AppBar
  final String? searchTag; // Add parameter for tag search
  final bool globalTagSearch; // Add parameter to control global vs local search

  const TabbedFolderListScreen({
    Key? key,
    required this.path,
    required this.tabId,
    this.showAppBar = true, // Mặc định là hiển thị AppBar
    this.searchTag, // Optional tag to search for
    this.globalTagSearch = false, // Default to local search
  }) : super(key: key);

  @override
  State<TabbedFolderListScreen> createState() => _TabbedFolderListScreenState();
}

class _TabbedFolderListScreenState extends State<TabbedFolderListScreen>
    with PreferencesManagerMixin {
  late TextEditingController _searchController;
  late TextEditingController _tagController;
  late TextEditingController _pathController;
  String? _currentFilter;
  String? _currentSearchTag;

  // Add flag for lazy loading drives
  bool _isLazyLoadingDrives = false;

  // Replace ValueNotifier with SelectionBloc
  late SelectionBloc _selectionBloc;

  // Trạng thái hiển thị thanh tìm kiếm
  bool _showSearchBar = false;

  // Current path displayed in this tab
  String _currentPath = '';
  // Flag to indicate whether we're in path editing mode

  // View and sort preferences are now managed by PreferencesManagerMixin
  // late ViewMode _viewMode;
  // late int _gridZoomLevel;
  // late ColumnVisibility _columnVisibility;
  // late bool _showFileTags;

  // Refresh state
  bool _isRefreshing = false;

  // Create the bloc instance at the class level
  late FolderListBloc _folderListBloc;

  // RefreshController instance
  late RefreshController _refreshController;

  // Navigation and Selection controllers
  late NavigationController _navigationController;
  late SelectionCoordinator _selectionCoordinator;

  // Override the getter required by PreferencesManagerMixin
  @override
  FolderListBloc get folderListBloc => _folderListBloc;

  // Global search toggle for tag search
  bool isGlobalSearch = false;

  // Flag to track if we're handling a path update to avoid duplicate loads
  bool _isHandlingPathUpdate = false;

  late final TabbedFolderDragSelectionController _dragSelectionController;
  late final TabbedFolderKeyboardController _keyboardController;

  // Flag to track if there are background thumbnail tasks
  bool _hasPendingThumbnails = false;

  // Add a method to check if there are any video/image files in the current state
  bool _hasVideoOrImageFiles(FolderListState state) {
    return state.files.any((file) => FileTypeUtils.isMediaFile(file.path));
  }

  @override
  void initState() {
    super.initState();
    _currentPath = widget.path;
    _searchController = TextEditingController();
    _tagController = TextEditingController();
    _pathController = TextEditingController(text: _currentPath);
    _keyboardController = TabbedFolderKeyboardController();

    // If this is a new tab with empty path (drive view), enable lazy loading
    if (_currentPath.isEmpty && Platform.isWindows) {
      _isLazyLoadingDrives = true;
      // Schedule drive loading after UI is built
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startLazyLoadingDrives();
      });
    }

    // Listen for thumbnail loading changes
    ThumbnailLoader.onPendingTasksChanged.listen((count) {
      final hasBackgroundTasks = count > 0;
      if (_hasPendingThumbnails != hasBackgroundTasks) {
        setState(() {
          _hasPendingThumbnails = hasBackgroundTasks;
        });
      }
    });

    // Enable hardware acceleration for smoother animations
    WidgetsBinding.instance.renderView.automaticSystemUiAdjustment = false;
    // Avoid forcing semantics here to prevent render/semantics assertions on mobile

    // Initialize the blocs
    _folderListBloc = FolderListBloc();

    // Initialize tag search using TagSearchInitializer
    final tagSearchConfig = TagSearchInitializer.initialize(
      searchTag: widget.searchTag,
      globalTagSearch: widget.globalTagSearch,
      path: widget.path,
      folderListBloc: _folderListBloc,
      tagController: _tagController,
      isMounted: mounted,
    );

    _currentSearchTag = tagSearchConfig.currentSearchTag;
    isGlobalSearch = tagSearchConfig.isGlobalSearch;

    // Initialize selection bloc
    _selectionBloc = SelectionBloc();
    _dragSelectionController = TabbedFolderDragSelectionController(
      folderListBloc: _folderListBloc,
      selectionBloc: _selectionBloc,
    );

    _saveLastAccessedFolder();

    // Load preferences using mixin
    loadPreferences();

    // Initialize RefreshController
    _refreshController = RefreshController(
      folderListBloc: _folderListBloc,
      tabManagerBloc: context.read<TabManagerBloc>(),
      tabId: widget.tabId,
    );

    // Initialize NavigationController
    _navigationController = NavigationController(
      tabId: widget.tabId,
      tabManagerBloc: context.read<TabManagerBloc>(),
      folderListBloc: _folderListBloc,
      onPathChanged: (String path) {
        setState(() {
          _currentPath = path;
        });
      },
      onSaveLastAccessedFolder: _saveLastAccessedFolder,
    );

    // Initialize SelectionCoordinator
    _selectionCoordinator = SelectionCoordinator(
      selectionBloc: _selectionBloc,
      folderListBloc: _folderListBloc,
      clearKeyboardFocus: () => _keyboardController.clearFocus(),
    );

    // Register mobile file actions controller for mobile UI
    if (Platform.isAndroid || Platform.isIOS) {
      _registerMobileActionsController();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Use TabLifecycleManager to handle tab lifecycle
    TabLifecycleManager.handleDidChangeDependencies(
      context: context,
      tabId: widget.tabId,
      currentPath: _currentPath,
      folderListBloc: _folderListBloc,
      isMounted: mounted,
      onPathUpdate: _updatePath,
    );
  }

  @override
  void didUpdateWidget(TabbedFolderListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Use TabLifecycleManager to handle widget updates
    TabLifecycleManager.handleDidUpdateWidget(
      oldPath: oldWidget.path,
      newPath: widget.path,
      currentPath: _currentPath,
      onPathUpdate: _updatePath,
    );
  }

  @override
  void dispose() {
    // Clean up resources
    _searchController.dispose();
    _tagController.dispose();
    _pathController.dispose();
    _folderListBloc.close();
    _selectionBloc.close();

    _dragSelectionController.dispose();
    _keyboardController.dispose();

    // Restore default settings
    WidgetsBinding.instance.renderView.automaticSystemUiAdjustment = true;

    // Remove mobile actions controller
    if (Platform.isAndroid || Platform.isIOS) {
      MobileFileActionsController.removeTab(widget.tabId);
    }

    super.dispose();
  }

  // Register mobile actions controller to connect mobile action buttons with this screen
  void _registerMobileActionsController() =>
      _registerMobileActionsControllerImpl();

  // Helper methods
  Future<void> _saveLastAccessedFolder() async {
    try {
      final directory = Directory(_currentPath);
      if (await directory.exists()) {
        final UserPreferences prefs = UserPreferences.instance;
        await prefs.init();
        await prefs.setLastAccessedFolder(_currentPath);
      }
    } catch (e) {
      debugPrint('Error saving last accessed folder: $e');
    }
  }

  // Preferences methods are now provided by PreferencesManagerMixin

  void _toggleSelectionMode({bool? forceValue}) {
    _selectionCoordinator.toggleSelectionMode(forceValue: forceValue);
  }

  void _toggleFileSelection(String filePath,
      {bool shiftSelect = false, bool ctrlSelect = false}) {
    _selectionCoordinator.toggleFileSelection(
      filePath,
      shiftSelect: shiftSelect,
      ctrlSelect: ctrlSelect,
    );
  }

  void _toggleFolderSelection(String folderPath,
      {bool shiftSelect = false, bool ctrlSelect = false}) {
    _selectionCoordinator.toggleFolderSelection(
      folderPath,
      shiftSelect: shiftSelect,
      ctrlSelect: ctrlSelect,
    );
  }

  void _clearSelection() {
    _selectionCoordinator.clearSelection();
  }

  // View mode methods are now provided by PreferencesManagerMixin
  void _toggleViewMode() => toggleViewMode();

  void _setViewMode(ViewMode mode) {
    setViewMode(mode, tabId: widget.tabId);
    // Update mobile controller state
    final controller = MobileFileActionsController.forTab(widget.tabId);
    controller.currentViewMode = mode;
  }

  void _refreshFileList() {
    setState(() {
      _isRefreshing = true;
    });

    _refreshController.refreshFileList(
      currentPath: _currentPath,
      isMounted: () => mounted,
      onRefreshComplete: () {
        if (!mounted) return;
        setState(() {
          _isRefreshing = false;
        });
      },
    );
  }

  // Handle mobile inline search
  void _handleMobileSearch(String? query) => _handleMobileSearchImpl(query);

  // Show search tip using SearchFilterManager
  Future<void> _showSearchTip(BuildContext context) async {
    await SearchFilterManager.showSearchTip(context);
    if (mounted) {
      setState(() {
        _showSearchBar = true;
      });
    }
  }

  void _navigateToPath(String path) {
    _navigationController.navigateToPath(
      context,
      path,
      _pathController,
      (p) => _keyboardController.clearFocus(),
    );
  }

  void _handlePathSubmit(String path) {
    _navigationController.handlePathSubmit(
      context,
      path,
      _currentPath,
      _pathController,
    );
  }

  void _handleGalleryResult(dynamic result) {
    _navigationController.handleGalleryResult(context, result);
  }

  Future<bool> _handleBackButton() async {
    return await _navigationController.handleBackButton(
      context,
      _currentPath,
      _pathController,
    );
  }

  void _updatePath(String newPath) {
    if (_isHandlingPathUpdate) return;
    _isHandlingPathUpdate = true;
    _navigationController.updatePath(
      newPath,
      _pathController,
      _currentFilter,
      _currentSearchTag,
    );
    _isHandlingPathUpdate = false;
  }

  // New method to handle lazy loading of drives
  void _startLazyLoadingDrives() {
    LazyLoadingManager.startLazyLoadingDrives(
      folderListBloc: _folderListBloc,
      isMounted: () => mounted,
      onComplete: () {
        if (!mounted) return;
        setState(() {
          _isLazyLoadingDrives = false;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Always listen for tab path changes so we can switch between system and folder screens
    return BlocProvider.value(
      value: _selectionBloc,
      child: BlocListener<TabManagerBloc, TabManagerState>(
        listener: (context, tabManagerState) {
          final currentTab = tabManagerState.tabs.firstWhere(
            (tab) => tab.id == widget.tabId,
            orElse: () => TabData(id: '', name: '', path: ''),
          );

          if (currentTab.id.isNotEmpty && currentTab.path != _currentPath) {
            debugPrint(
                'Tab path updated from $_currentPath to ${currentTab.path}');
            _updatePath(currentTab.path);
          }
        },
        child: _buildContentForCurrentPath(context),
      ),
    );
  }

  // Build appropriate content depending on current path. This keeps the tab listening
  // active even when showing system screens like #tags.
  Widget _buildContentForCurrentPath(BuildContext context) {
    // Drive view (Windows only)
    if (_currentPath.isEmpty && Platform.isWindows) {
      return tab_components.DriveView(
        tabId: widget.tabId,
        folderListBloc: _folderListBloc,
        onPathChanged: (String path) {
          setState(() {
            _currentPath = path;
            _pathController.text = path;
          });
        },
        onBackButtonPressed: () => _handleMouseBackButton(),
        onForwardButtonPressed: () => _handleMouseForwardButton(),
        isLazyLoading: _isLazyLoadingDrives,
      );
    }

    // Route system paths except the special inline tag-search variant
    if (_currentPath.startsWith('#') &&
        !_currentPath.startsWith('#search?tag=')) {
      final systemWidget = SystemScreenRouter.routeSystemPath(
          context, _currentPath, widget.tabId);
      if (systemWidget != null) {
        return systemWidget;
      }
    }

    // Folder/browser UI (default and for #search?tag=...)
    final bool isNetworkPath = _currentPath.startsWith('#network/');

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        debugPrint(
            'TabbedFolderListScreen PopScope onPopInvokedWithResult: didPop=$didPop, result=$result');
        if (!didPop) {
          debugPrint('Gesture navigation detected - calling _handleBackButton');
          await _handleBackButton();
        }
      },
      // Wrap with Listener to detect mouse button events
      child: Focus(
        autofocus: isDesktopPlatform,
        focusNode: _keyboardController.focusNode,
        onKeyEvent: (node, event) {
          return _keyboardController.handleKeyEvent(
            isDesktop: isDesktopPlatform,
            folderListState: _folderListBloc.state,
            selectionState: _selectionBloc.state,
            currentFilter: _currentFilter,
            onBackInTabHistory: () {
              final tabManagerBloc = context.read<TabManagerBloc>();
              if (tabManagerBloc.canTabNavigateBack(widget.tabId)) {
                tabManagerBloc.backNavigationToPath(widget.tabId);
              }
            },
            focusFolderPath: (path) => _toggleFolderSelection(path,
                shiftSelect: false, ctrlSelect: false),
            focusFilePath: (path) => _toggleFileSelection(path,
                shiftSelect: false, ctrlSelect: false),
            activateEntity: (entity) {
              if (entity is Directory) {
                _navigateToPath(entity.path);
              } else if (entity is File) {
                _onFileTap(entity, false);
              }
            },
            event: event,
          );
        },
        child: Listener(
          onPointerDown: (PointerDownEvent event) {
            if (isDesktopPlatform) {
              _keyboardController.focusNode.requestFocus();
            }
            // Mouse button 4 is usually the back button (button value is 8)
            if (event.buttons == 8) {
              _handleMouseBackButton();
            }
            // Mouse button 5 is usually the forward button (button value is 16)
            else if (event.buttons == 16) {
              _handleMouseForwardButton();
            }
          },
          child: BlocProvider<FolderListBloc>.value(
            value: _folderListBloc,
            child: BlocListener<FolderListBloc, FolderListState>(
              listener: (context, folderState) {
                // Check if there are any video/image files in the current directory
                final hasVideoOrImageFiles = _hasVideoOrImageFiles(folderState);

                // If no video/image files and we have pending thumbnails, reset the count
                if (!hasVideoOrImageFiles && _hasPendingThumbnails) {
                  debugPrint(
                      "TabbedFolderListScreen: No video/image files found, resetting pending thumbnail count");
                  ThumbnailLoader.resetPendingCount();
                  _hasPendingThumbnails = false;
                }

                // Only show tab loading when there are actual thumbnail tasks
                // Folder loading should not show in tab loading indicator
                final isLoading = _hasPendingThumbnails;

                context.read<TabManagerBloc>().add(
                      UpdateTabLoading(widget.tabId, isLoading),
                    );
              },
              child: BlocBuilder<FolderListBloc, FolderListState>(
                builder: (context, state) {
                  _currentSearchTag = state.currentSearchTag;
                  _currentFilter = state.currentFilter;

                  return _buildWithSelectionState(
                      context, state, isNetworkPath);
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  // New helper method that builds the UI with selection state from BLoC
  Widget _buildWithSelectionState(BuildContext context,
      FolderListState folderListState, bool isNetworkPath) {
    return BlocBuilder<SelectionBloc, SelectionState>(
        builder: (context, selectionState) {
      return ScreenScaffold(
        selectionState: selectionState,
        body:
            _buildBody(context, folderListState, selectionState, isNetworkPath),
        isNetworkPath: isNetworkPath,
        onClearSelection: _clearSelection,
        showRemoveTagsDialog: _showRemoveTagsDialog,
        showManageAllTagsDialog: (context) => _showManageAllTagsDialog(context),
        showDeleteConfirmationDialog: (context) =>
            _showDeleteConfirmationDialog(context),
        isDesktop: isDesktopPlatform,
        selectionModeFloatingActionButton: isNetworkPath
            ? null
            : FloatingActionButton(
                onPressed: () {
                  tab_components.showBatchAddTagDialog(
                      context, selectionState.selectedFilePaths.toList());
                },
                child: const Icon(remix.Remix.shopping_bag_3_line),
              ),
        showAppBar: widget.showAppBar,
        showSearchBar: _showSearchBar,
        searchBar: tab_components.SearchBar(
          currentPath: _currentPath,
          tabId: widget.tabId,
          onCloseSearch: () {
            setState(() {
              _showSearchBar = false;
            });
          },
        ),
        pathNavigationBar: tab_components.PathNavigationBar(
          tabId: widget.tabId,
          pathController: _pathController,
          onPathSubmitted: _handlePathSubmit,
          currentPath: _currentPath,
          isNetworkPath: isNetworkPath, // Pass network flag
        ),
        actions: _getAppBarActions(),
        floatingActionButton: FloatingActionButton(
          onPressed: _toggleSelectionMode,
          child: const Icon(remix.Remix.checkbox_line),
        ),
      );
    });
  }

  Widget _buildBody(BuildContext context, FolderListState state,
      SelectionState selectionState, bool isNetworkPath) {
    // Apply frame timing optimization before heavy UI operations
    FrameTimingOptimizer().optimizeBeforeHeavyOperation();

    if (isDesktopPlatform) {
      _keyboardController.syncFromSelection(selectionState);
    }

    // Show content as soon as we have any files/folders (lazy loading)
    // Only show skeleton when truly empty and loading
    final bool hasContent = state.folders.isNotEmpty || state.files.isNotEmpty;
    final bool shouldShowSkeleton = !hasContent &&
        state.isLoading &&
        state.error == null &&
        state.searchResults.isEmpty &&
        state.currentSearchTag == null &&
        state.currentSearchQuery == null;

    return Column(
      children: [
        // Top progress bar when loading, refreshing, or while initial content is being prepared
        if (state.isLoading || _isRefreshing)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 4.0),
            child: AppProgressIndicatorBeautiful(),
          ),
        Expanded(
          child: FluentBackground.container(
            context: context,
            enableBlur: isDesktopPlatform,
            child: shouldShowSkeleton
                ? const SizedBox.shrink() // Show an empty space while loading
                : _buildMainContent(
                    context, state, selectionState, isNetworkPath),
          ),
        ),
      ],
    );
  }

  Widget _buildMainContent(BuildContext context, FolderListState state,
      SelectionState selectionState, bool isNetworkPath) {
    // Use FolderContentBuilder for error handling and content routing
    final content = FolderContentBuilder.build(
      context,
      folderListState: state,
      selectionState: selectionState,
      currentPath: _currentPath,
      isNetworkPath: isNetworkPath,
      isDesktopPlatform: isDesktopPlatform,
      onRetry: () {
        _folderListBloc.add(FolderListLoad(_currentPath));
      },
      onNavigateToPath: _navigateToPath,
      tabId: widget.tabId,
      showFileTags: showFileTags,
      currentFilter: _currentFilter,
      currentSearchTag: _currentSearchTag,
      onFileTap: _onFileTap,
      toggleFileSelection: _toggleFileSelection,
      toggleSelectionMode: _toggleSelectionMode,
      showDeleteTagDialog: _showDeleteTagDialog,
      showAddTagToFileDialog: _showAddTagToFileDialog,
      onClearSearch: () {
        _folderListBloc.add(const ClearSearchAndFilters());
        _folderListBloc.add(FolderListLoad(_currentPath));
      },
      isGlobalSearch: isGlobalSearch,
      onBackButtonPressed: _handleMouseBackButton,
      onForwardButtonPressed: _handleMouseForwardButton,
    );

    // If content builder returns a widget (error, empty, or search results), show it
    if (content is! SizedBox) {
      return content;
    }

    // Otherwise, show the normal file list with progressive loading
    return _buildFolderAndFileListContent(
        context, state, selectionState, isNetworkPath);
  }

  Widget _buildFolderAndFileListContent(
      BuildContext context,
      FolderListState state,
      SelectionState selectionState,
      bool isNetworkPath) {
    // Use RefreshableFileListView for pull-to-refresh functionality
    return RefreshableFileListView(
      folderListState: state,
      currentPath: _currentPath,
      tabId: widget.tabId,
      folderListBloc: _folderListBloc,
      tabManagerBloc: context.read<TabManagerBloc>(),
      isMounted: () => mounted,
      onRefreshStateChanged: (isRefreshing) {
        setState(() {
          _isRefreshing = isRefreshing;
        });
      },
      child: _buildFolderAndFileList(state),
    );
  }

  Widget _buildFolderAndFileList(FolderListState state) {
    return BlocBuilder<SelectionBloc, SelectionState>(
      builder: (context, selectionState) {
        return FileListViewBuilder.build(
          state: state,
          selectionState: selectionState,
          isDesktopPlatform: isDesktopPlatform,
          onNavigateToPath: _navigateToPath,
          onFileTap: _onFileTap,
          toggleFileSelection: _toggleFileSelection,
          toggleFolderSelection: _toggleFolderSelection,
          clearSelection: _clearSelection,
          dragSelectionController: _dragSelectionController,
          showFileTags: showFileTags,
          showDeleteTagDialog: _showDeleteTagDialog,
          showAddTagToFileDialog: _showAddTagToFileDialog,
          toggleSelectionMode: _toggleSelectionMode,
          columnVisibility: columnVisibility,
          showContextMenu: _showContextMenu,
        );
      },
    );
  }

  // Helper methods for dialog calls - now using DialogManager
  void _showAddTagToFileDialog(BuildContext context, String filePath) {
    DialogManager.showAddTagToFile(context, filePath);
  }

  void _showDeleteTagDialog(
      BuildContext context, String filePath, List<String> tags) {
    DialogManager.showDeleteTag(context, filePath, tags);
  }

  void _showRemoveTagsDialog(BuildContext context) {
    final selectionState = context.read<SelectionBloc>().state;
    DialogManager.showRemoveTags(
        context, selectionState.selectedFilePaths.toList());
  }

  void _showManageAllTagsDialog(BuildContext context) {
    final selectionState = context.read<SelectionBloc>().state;
    DialogManager.showManageAllTags(
      context,
      _folderListBloc.state.allTags.toList(),
      _currentPath,
      selectedFiles: selectionState.isSelectionMode &&
              selectionState.selectedFilePaths.isNotEmpty
          ? selectionState.selectedFilePaths.toList()
          : null,
    );
  }

  void _showDeleteConfirmationDialog(BuildContext context) {
    final selectionState = context.read<SelectionBloc>().state;
    DialogManager.showDeleteConfirmation(
      context,
      selectedFilePaths: selectionState.selectedFilePaths.toList(),
      selectedFolderPaths: selectionState.selectedFolderPaths.toList(),
      folderListBloc: _folderListBloc,
      currentPath: _currentPath,
      onClearSelection: _clearSelection,
    );
  }

  // Grid zoom change is now handled by mixin

  // Tag search dialog and handling

  // Xử lý khi người dùng click vào một file trong kết quả tìm kiếm
  void _onFileTap(File file, bool isVideo) {
    FileOperationsHandler.onFileTap(
      context: context,
      file: file,
      folderListBloc: _folderListBloc,
      currentFilter: _currentFilter,
      currentSearchTag: _currentSearchTag,
    );
  }

  // Method to handle mouse back button press
  void _handleMouseBackButton() {
    _navigationController.handleMouseBackButton(
        context, _currentPath, _pathController);
  }

  // Show context menu for the folder
  void _showContextMenu(BuildContext context, Offset position) {
    FolderBackgroundContextMenu.show(
      context: context,
      globalPosition: position,
      folderListBloc: _folderListBloc,
      currentPath: _currentPath,
      currentViewMode: _folderListBloc.state.viewMode,
      currentSortOption: _folderListBloc.state.sortOption,
      onViewModeChanged: _setViewMode,
      onRefresh: _refreshFileList,
      onCreateFolder: (String folderName) {
        // This callback is now handled inside FolderBackgroundContextMenu
      },
      onSortOptionSaved: (option) => saveSortSetting(option, _currentPath),
    );
  }

  // Method to handle mouse forward button press
  void _handleMouseForwardButton() {
    _navigationController.handleMouseForwardButton(
        context, _currentPath, _pathController);
  }

  List<Widget> _getAppBarActions() {
    // Use AppBarActionsBuilder to build actions based on selection state
    final selectionState = _selectionBloc.state;
    final folderListState = _folderListBloc.state;

    return AppBarActionsBuilder.buildActions(
      context: context,
      selectionState: selectionState,
      folderListState: folderListState,
      currentPath: _currentPath,
      isNetworkPath: _currentPath.startsWith('#network/'),
      onSortOptionSelected: (SortOption option) {
        _folderListBloc.add(SetSortOption(option));
        saveSortSetting(option, _currentPath);
      },
      onViewModeToggled: _toggleViewMode,
      onViewModeSelected: _setViewMode,
      onRefresh: _refreshFileList,
      onSearchPressed: () => _showSearchTip(context),
      onSelectionModeToggled: _toggleSelectionMode,
      onManageTagsPressed: () {
        tab_components.showManageTagsDialog(
          context,
          folderListState.allTags.toList(),
          folderListState.currentPath.path,
        );
      },
      onGridZoomChange: handleGridZoomChange,
      onColumnSettingsPressed: () {
        showColumnVisibilityDialog(context);
      },
      onGalleryResult: _handleGalleryResult,
    );
  }
}
