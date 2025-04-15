import 'dart:io';
import 'dart:ffi';

import 'package:cb_file_manager/helpers/io_extensions.dart';
import 'package:cb_file_manager/helpers/batch_tag_manager.dart';
import 'package:cb_file_manager/helpers/tag_manager.dart';
import 'package:cb_file_manager/ui/screens/folder_list/file_details_screen.dart';
import 'package:cb_file_manager/ui/screens/media_gallery/image_gallery_screen.dart';
import 'package:cb_file_manager/ui/screens/media_gallery/video_gallery_screen.dart';
import 'package:cb_file_manager/ui/utils/base_screen.dart';
import 'package:cb_file_manager/ui/components/shared_action_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as pathlib;
import 'package:cb_file_manager/helpers/user_preferences.dart';
import 'package:cb_file_manager/helpers/filesystem_utils.dart';
import 'package:win32/win32.dart' as win32;
import 'package:ffi/ffi.dart';
import 'tab_manager.dart';

import '../screens/folder_list/folder_list_bloc.dart';
import '../screens/folder_list/folder_list_event.dart';
import '../screens/folder_list/folder_list_state.dart';
import '../screens/folder_list/components/index.dart';

/// A modified version of FolderListScreen that works with the tab system
class TabbedFolderListScreen extends StatefulWidget {
  final String path;
  final String tabId;

  const TabbedFolderListScreen({
    Key? key,
    required this.path,
    required this.tabId,
  }) : super(key: key);

  @override
  State<TabbedFolderListScreen> createState() => _TabbedFolderListScreenState();
}

class _TabbedFolderListScreenState extends State<TabbedFolderListScreen> {
  late TextEditingController _searchController;
  late TextEditingController _tagController;
  late TextEditingController _pathController;
  String? _currentFilter;
  String? _currentSearchTag;
  bool _isSelectionMode = false;
  final Set<String> _selectedFilePaths = {};

  // Current path displayed in this tab
  String _currentPath = '';
  // Flag to indicate whether we're in path editing mode
  bool _isEditingPath = false;

  // View and sort preferences
  late ViewMode _viewMode;
  late SortOption _sortOption;
  late int _gridZoomLevel;

  // Create the bloc instance at the class level
  late FolderListBloc _folderListBloc;

  // Global search toggle for tag search
  bool isGlobalSearch = false;

  @override
  void initState() {
    super.initState();
    _currentPath = widget.path;
    _searchController = TextEditingController();
    _tagController = TextEditingController();
    _pathController = TextEditingController(text: _currentPath);

    // Initialize the bloc
    _folderListBloc = FolderListBloc();
    _folderListBloc.add(FolderListLoad(widget.path));

    _saveLastAccessedFolder();

    // Load preferences
    _loadPreferences();
  }

  @override
  void didUpdateWidget(TabbedFolderListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    // If the path prop changes from parent, update our current path
    // and reload the folder list with the new path
    if (widget.path != oldWidget.path && widget.path != _currentPath) {
      _currentPath = widget.path;
      _pathController.text = _currentPath;
      _folderListBloc.add(FolderListLoad(_currentPath));
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tagController.dispose();
    _pathController.dispose();
    _folderListBloc.close();
    super.dispose();
  }

  // Helper methods
  Future<void> _saveLastAccessedFolder() async {
    try {
      final directory = Directory(_currentPath);
      if (await directory.exists()) {
        final UserPreferences prefs = UserPreferences();
        await prefs.init();
        await prefs.setLastAccessedFolder(_currentPath);
      }
    } catch (e) {
      print('Error saving last accessed folder: $e');
    }
  }

  Future<void> _loadPreferences() async {
    try {
      final UserPreferences prefs = UserPreferences();
      await prefs.init();

      setState(() {
        _viewMode = prefs.getViewMode();
        _sortOption = prefs.getSortOption();
        _gridZoomLevel = prefs.getGridZoomLevel();
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _folderListBloc.add(SetViewMode(_viewMode));
          _folderListBloc.add(SetSortOption(_sortOption));
          _folderListBloc.add(SetGridZoom(_gridZoomLevel));
        }
      });
    } catch (e) {
      print('Error loading preferences: $e');
    }
  }

  Future<void> _saveViewModeSetting(ViewMode mode) async {
    try {
      final UserPreferences prefs = UserPreferences();
      await prefs.init();
      await prefs.setViewMode(mode);
    } catch (e) {
      print('Error saving view mode: $e');
    }
  }

  Future<void> _saveSortSetting(SortOption option) async {
    try {
      final UserPreferences prefs = UserPreferences();
      await prefs.init();
      await prefs.setSortOption(option);
    } catch (e) {
      print('Error saving sort option: $e');
    }
  }

  Future<void> _saveGridZoomSetting(int zoomLevel) async {
    try {
      final UserPreferences prefs = UserPreferences();
      await prefs.init();
      await prefs.setGridZoomLevel(zoomLevel);
      setState(() {
        _gridZoomLevel = zoomLevel;
      });
    } catch (e) {
      print('Error saving grid zoom level: $e');
    }
  }

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) {
        _selectedFilePaths.clear();
      }
    });
  }

  void _toggleFileSelection(String filePath) {
    setState(() {
      if (_selectedFilePaths.contains(filePath)) {
        _selectedFilePaths.remove(filePath);
      } else {
        _selectedFilePaths.add(filePath);
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _isSelectionMode = false;
      _selectedFilePaths.clear();
    });
  }

  void _toggleViewMode() {
    final newMode = _viewMode == ViewMode.list ? ViewMode.grid : ViewMode.list;
    _folderListBloc.add(SetViewMode(newMode));
    _saveViewModeSetting(newMode);
    setState(() {
      _viewMode = newMode;
    });
  }

  void _refreshFileList() {
    _folderListBloc.add(FolderListLoad(_currentPath));
  }

  void _showSearchScreen(BuildContext context, FolderListState state) {
    showDialog(
      context: context,
      builder: (context) => SearchDialog(
        currentPath: _currentPath,
        files: state.files.whereType<File>().toList(),
        folders: state.folders.whereType<Directory>().toList(),
      ),
    );
  }

  // This method updates both the tab's path in the TabManager
  // and the local UI state to display the new path
  void _navigateToPath(String path) {
    // Update the current path in local state
    setState(() {
      _currentPath = path;
      _pathController.text = path;
    });

    // Clear any search or filter state when navigating
    if (_currentFilter != null || _currentSearchTag != null) {
      _folderListBloc.add(ClearSearchAndFilters());
    }

    // Update the tab's path in the TabManager
    context.read<TabManagerBloc>().add(UpdateTabPath(widget.tabId, path));

    // Also add this path to the tab's navigation history
    context.read<TabManagerBloc>().add(AddToTabHistory(widget.tabId, path));

    // Update the folder list to show the new path
    _folderListBloc.add(FolderListLoad(path));

    // Save this folder as last accessed
    _saveLastAccessedFolder();

    // Update the tab name based on the new path
    final pathParts = path.split(Platform.pathSeparator);
    final lastPart =
        pathParts.lastWhere((part) => part.isNotEmpty, orElse: () => 'Root');
    final tabName = lastPart.isEmpty ? 'Root' : lastPart;

    // Update tab name if needed
    context.read<TabManagerBloc>().add(UpdateTabName(widget.tabId, tabName));
  }

  // Handle path submission when user manually edits the path
  void _handlePathSubmit(String path) {
    // Check if path exists
    final directory = Directory(path);
    directory.exists().then((exists) {
      if (exists) {
        _navigateToPath(path);
        setState(() {
          _isEditingPath = false;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đường dẫn không tồn tại hoặc không thể truy cập'),
            backgroundColor: Colors.red,
          ),
        );
        // Revert to current path
        _pathController.text = _currentPath;
      }
    });
  }

  Future<bool> _handleBackNavigation() async {
    // First check if we're in selection mode
    if (_isSelectionMode) {
      setState(() {
        _isSelectionMode = false;
        _selectedFilePaths.clear();
      });
      return false; // Don't exit the app, just exit selection mode
    }

    // Check if we're showing search results
    if (_currentSearchTag != null || _currentFilter != null) {
      _folderListBloc.add(const ClearSearchAndFilters());
      _folderListBloc.add(FolderListLoad(_currentPath));
      return false; // Don't exit the app, just exit search mode
    }

    // Check if we can navigate back in the folder hierarchy
    final tabManagerBloc = context.read<TabManagerBloc>();
    if (tabManagerBloc.canTabNavigateBack(widget.tabId)) {
      final previousPath = tabManagerBloc.getTabPreviousPath(widget.tabId);
      if (previousPath != null) {
        // Navigate to the previous path without adding it to history
        setState(() {
          _currentPath = previousPath;
          _pathController.text = previousPath;
        });
        _folderListBloc.add(FolderListLoad(previousPath));
        return false; // Don't exit app, we navigated back
      }
    }

    // If we're at the root, let the system handle back (which might exit the app)
    return true;
  }

  @override
  Widget build(BuildContext context) {
    // Nếu path rỗng hoặc null, hiển thị drive picker trực tiếp trong view
    if ((_currentPath.isEmpty || _currentPath == null) && Platform.isWindows) {
      return FutureBuilder<List<Directory>>(
        future: getAllWindowsDrives(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final drives = snapshot.data ?? [];
          if (drives.isEmpty) {
            return const Center(child: Text('Không tìm thấy ổ đĩa nào!'));
          }

          return Container(
            padding: const EdgeInsets.all(16.0),
            child: ListView.builder(
              itemCount: drives.length,
              itemBuilder: (context, index) {
                final drive = drives[index];
                final isDarkMode =
                    Theme.of(context).brightness == Brightness.dark;

                return Card(
                  margin: const EdgeInsets.only(bottom: 16.0),
                  // Use pure white in light mode, dark gray in dark mode
                  color: isDarkMode ? Colors.grey[850] : Colors.white,
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: FutureBuilder<Map<String, dynamic>>(
                      future: _getDriveSpaceInfo(drive.path),
                      builder: (context, spaceSnapshot) {
                        // Giá trị mặc định
                        double usageRatio = 0.0;
                        String totalStr = '';
                        String freeStr = '';
                        String usedStr = '';

                        if (spaceSnapshot.hasData) {
                          final data = spaceSnapshot.data!;
                          usageRatio = data['usageRatio'] as double;
                          totalStr = data['totalStr'] as String;
                          freeStr = data['freeStr'] as String;
                          usedStr = data['usedStr'] as String;
                        }

                        // Define colors based on theme and usage
                        Color progressColor = usageRatio > 0.9
                            ? Colors.red
                            : (usageRatio > 0.7
                                ? Colors.orange
                                : Theme.of(context).colorScheme.primary);

                        Color progressBackgroundColor =
                            isDarkMode ? Colors.grey[800]! : Colors.grey[200]!;

                        Color textColor =
                            isDarkMode ? Colors.grey[300]! : Colors.grey[700]!;

                        Color headerTextColor =
                            isDarkMode ? Colors.white : Colors.black87;

                        Color usedColor = progressColor;

                        Color subtitleColor =
                            isDarkMode ? Colors.grey[400]! : Colors.grey[600]!;

                        return InkWell(
                          onTap: () {
                            context
                                .read<TabManagerBloc>()
                                .add(UpdateTabPath(widget.tabId, drive.path));
                            context
                                .read<TabManagerBloc>()
                                .add(UpdateTabName(widget.tabId, drive.path));
                            setState(() {
                              _currentPath = drive.path;
                              _pathController.text = drive.path;
                            });
                            _folderListBloc.add(FolderListLoad(drive.path));
                          },
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Drive title và icon
                              Row(
                                children: [
                                  const Icon(Icons.storage, size: 36),
                                  const SizedBox(width: 12),
                                  Text(
                                    drive.path,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: headerTextColor,
                                    ),
                                  ),
                                  const Spacer(),
                                  const Icon(Icons.arrow_forward_ios, size: 16),
                                ],
                              ),
                              const SizedBox(height: 20),

                              // Progress bar
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: LinearProgressIndicator(
                                  value: usageRatio,
                                  backgroundColor: progressBackgroundColor,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      progressColor),
                                  minHeight: 12,
                                ),
                              ),

                              // Thông tin dung lượng
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Đã dùng: $usedStr',
                                      style: TextStyle(
                                          color: usedColor,
                                          fontWeight: FontWeight.w500),
                                    ),
                                    Text(
                                      'Còn trống: $freeStr',
                                      style: TextStyle(color: textColor),
                                    ),
                                  ],
                                ),
                              ),

                              Text(
                                'Tổng: $totalStr',
                                style: TextStyle(
                                    color: subtitleColor, fontSize: 12),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          );
        },
      );
    }
    return WillPopScope(
      onWillPop: _handleBackNavigation,
      child: BlocProvider<FolderListBloc>.value(
        value: _folderListBloc,
        child: BlocBuilder<FolderListBloc, FolderListState>(
          builder: (context, state) {
            _currentSearchTag = state.currentSearchTag;
            _currentFilter = state.currentFilter;

            // Create actions for the app bar
            List<Widget> actions = [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Back',
                onPressed: context
                        .read<TabManagerBloc>()
                        .canTabNavigateBack(widget.tabId)
                    ? () {
                        final tabBloc = context.read<TabManagerBloc>();
                        final state = tabBloc.state;
                        final tab =
                            state.tabs.firstWhere((t) => t.id == widget.tabId);
                        if (tab.navigationHistory.length > 1) {
                          // Đẩy currentPath vào forwardHistory
                          final newForward =
                              List<String>.from(tab.forwardHistory)
                                ..add(tab.path);
                          // Xóa currentPath khỏi navigationHistory
                          final newHistory =
                              List<String>.from(tab.navigationHistory)
                                ..removeLast();
                          final newPath = newHistory.last;
                          // Cập nhật TabData
                          tabBloc.emit(state.copyWith(
                            tabs: state.tabs
                                .map((t) => t.id == widget.tabId
                                    ? t.copyWith(
                                        path: newPath,
                                        navigationHistory: newHistory,
                                        forwardHistory: newForward)
                                    : t)
                                .toList(),
                          ));
                          // Cập nhật UI
                          setState(() {
                            _currentPath = newPath;
                            _pathController.text = newPath;
                          });
                          _folderListBloc.add(FolderListLoad(newPath));
                        }
                      }
                    : null,
              ),
              IconButton(
                icon: const Icon(Icons.arrow_forward),
                tooltip: 'Forward',
                onPressed: context
                        .read<TabManagerBloc>()
                        .canTabNavigateForward(widget.tabId)
                    ? () {
                        final tabBloc = context.read<TabManagerBloc>();
                        final state = tabBloc.state;
                        final tab =
                            state.tabs.firstWhere((t) => t.id == widget.tabId);
                        if (tab.forwardHistory.isNotEmpty) {
                          // Lấy path tiếp theo
                          final nextPath = tab.forwardHistory.last;
                          // Xóa path này khỏi forwardHistory
                          final newForward =
                              List<String>.from(tab.forwardHistory)
                                ..removeLast();
                          // Đẩy currentPath vào navigationHistory
                          final newHistory =
                              List<String>.from(tab.navigationHistory)
                                ..add(nextPath);
                          // Cập nhật TabData
                          tabBloc.emit(state.copyWith(
                            tabs: state.tabs
                                .map((t) => t.id == widget.tabId
                                    ? t.copyWith(
                                        path: nextPath,
                                        navigationHistory: newHistory,
                                        forwardHistory: newForward)
                                    : t)
                                .toList(),
                          ));
                          // Cập nhật UI
                          setState(() {
                            _currentPath = nextPath;
                            _pathController.text = nextPath;
                          });
                          _folderListBloc.add(FolderListLoad(nextPath));
                        }
                      }
                    : null,
              ),
            ];
            actions.addAll(_isSelectionMode
                ? []
                : SharedActionBar.buildCommonActions(
                    context: context,
                    onSearchPressed: () => _showSearchScreen(context, state),
                    onSortOptionSelected: (SortOption option) {
                      _folderListBloc.add(SetSortOption(option));
                      _saveSortSetting(option);
                    },
                    currentSortOption: state.sortOption,
                    viewMode: state.viewMode,
                    onViewModeToggled: _toggleViewMode,
                    onRefresh: _refreshFileList,
                    onGridSizePressed: state.viewMode == ViewMode.grid
                        ? () => SharedActionBar.showGridSizeDialog(
                              context,
                              currentGridSize: state.gridZoomLevel,
                              onApply: _handleGridZoomChange,
                            )
                        : null,
                    onSelectionModeToggled: _toggleSelectionMode,
                    onManageTagsPressed: () {
                      showManageTagsDialog(context, state.allTags.toList());
                    },
                    onGallerySelected: (value) {
                      if (value == 'image_gallery') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ImageGalleryScreen(
                              path: _currentPath,
                              recursive: false,
                            ),
                          ),
                        );
                      } else if (value == 'video_gallery') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => VideoGalleryScreen(
                              path: _currentPath,
                              recursive: false,
                            ),
                          ),
                        );
                      }
                    },
                    currentPath: _currentPath,
                  ));

            // If we're in selection mode, show a custom app bar
            if (_isSelectionMode) {
              return Scaffold(
                appBar: AppBar(
                  title: Text('${_selectedFilePaths.length} selected'),
                  leading: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _clearSelection,
                  ),
                  actions: [
                    if (_selectedFilePaths.isNotEmpty) ...[
                      // Tag management dropdown menu
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.label),
                        tooltip: 'Quản lý thẻ',
                        onSelected: (value) {
                          if (value == 'add_tag') {
                            showBatchAddTagDialog(
                                context, _selectedFilePaths.toList());
                          } else if (value == 'remove_tag') {
                            _showRemoveTagsDialog(
                                context, _selectedFilePaths.toList());
                          } else if (value == 'manage_all_tags') {
                            _showManageAllTagsDialog(context);
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem<String>(
                            value: 'add_tag',
                            child: Row(
                              children: [
                                Icon(Icons.add_circle_outline),
                                SizedBox(width: 8),
                                Text('Thêm thẻ'),
                              ],
                            ),
                          ),
                          const PopupMenuItem<String>(
                            value: 'remove_tag',
                            child: Row(
                              children: [
                                Icon(Icons.remove_circle_outline),
                                SizedBox(width: 8),
                                Text('Xóa thẻ'),
                              ],
                            ),
                          ),
                          const PopupMenuItem<String>(
                            value: 'manage_all_tags',
                            child: Row(
                              children: [
                                Icon(Icons.settings),
                                SizedBox(width: 8),
                                Text('Quản lý tất cả thẻ'),
                              ],
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete),
                        tooltip: 'Delete selected',
                        onPressed: () {
                          _showDeleteConfirmationDialog(context);
                        },
                      ),
                    ],
                  ],
                ),
                body: _buildBody(context, state),
                floatingActionButton: FloatingActionButton(
                  onPressed: () {
                    showBatchAddTagDialog(context, _selectedFilePaths.toList());
                  },
                  child: const Icon(Icons.label),
                ),
              );
            }

            // Note: We're not using BaseScreen here since we're already inside a tab
            return Scaffold(
              appBar: AppBar(
                title: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _pathController,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4.0),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor:
                              Theme.of(context).brightness == Brightness.dark
                                  ? Colors.grey[800]
                                  : Colors.grey[200],
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 8),
                          isDense: true,
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.navigate_next, size: 20),
                            onPressed: () =>
                                _handlePathSubmit(_pathController.text),
                            padding: const EdgeInsets.all(0),
                            constraints: const BoxConstraints(),
                          ),
                        ),
                        style: const TextStyle(fontSize: 14),
                        onSubmitted: _handlePathSubmit,
                      ),
                    ),
                  ],
                ),
                actions: actions,
              ),
              body: _buildBody(context, state),
              floatingActionButton: FloatingActionButton(
                onPressed: _toggleSelectionMode,
                child: const Icon(Icons.checklist),
              ),
            );
          },
        ),
      ),
    );
  }

  String _extractFolderName(String path) {
    // Use platform-specific path separator
    final pathParts = path.split(Platform.pathSeparator);
    return pathParts.isEmpty || pathParts.last.isEmpty
        ? 'Root'
        : pathParts.last;
  }

  Widget _buildBody(BuildContext context, FolderListState state) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Error: ${state.error}',
              style: TextStyle(color: Colors.red[700]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                _folderListBloc.add(FolderListLoad(_currentPath));
              },
              child: const Text('Try Again'),
            ),
          ],
        ),
      );
    }

    // Show search results if searching
    if (_currentSearchTag != null && state.searchResults.isNotEmpty) {
      return Column(
        children: [
          _buildSearchHeader(context, state),
          Expanded(
            child: _buildSearchResultsList(context, state),
          ),
        ],
      );
    }

    // Show filtered files if a filter is active
    if (_currentFilter != null &&
        _currentFilter!.isNotEmpty &&
        state.filteredFiles.isNotEmpty) {
      return FileView(
        files: state.filteredFiles.whereType<File>().toList(),
        folders: [], // No folders in filtered view
        state: state,
        isSelectionMode: _isSelectionMode,
        isGridView: state.viewMode == ViewMode.grid,
        selectedFiles: _selectedFilePaths.toList(),
        toggleFileSelection: _toggleFileSelection,
        toggleSelectionMode: _toggleSelectionMode,
        showDeleteTagDialog: _showDeleteTagDialog,
        showAddTagToFileDialog: _showAddTagToFileDialog,
      );
    }

    // Empty directory check
    if (state.folders.isEmpty && state.files.isEmpty) {
      return const Center(
        child: Text('Thư mục trống', style: TextStyle(fontSize: 18)),
      );
    }

    // Default view - folders and files
    return RefreshIndicator(
      onRefresh: () async {
        _folderListBloc.add(FolderListLoad(_currentPath));
      },
      child: _buildFolderAndFileList(state),
    );
  }

  Widget _buildFolderAndFileList(FolderListState state) {
    if (state.viewMode == ViewMode.grid) {
      return GridView.builder(
        padding: const EdgeInsets.all(8.0),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: state.gridZoomLevel,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: state.folders.length + state.files.length,
        itemBuilder: (context, index) {
          if (index < state.folders.length) {
            // This is a folder
            final folder = state.folders[index] as Directory;
            return _buildFolderGridItem(folder);
          } else {
            // This is a file
            final fileIndex = index - state.folders.length;
            if (fileIndex < state.files.length) {
              final file = state.files[fileIndex] as File;
              return FileGridItem(
                file: file,
                state: state,
                isSelectionMode: _isSelectionMode,
                isSelected: _selectedFilePaths.contains(file.path),
                toggleFileSelection: _toggleFileSelection,
                toggleSelectionMode: _toggleSelectionMode,
              );
            }
            return Container(); // Fallback for any index issues
          }
        },
      );
    } else {
      return ListView(
        children: [
          // Folders list
          ...state.folders
              .map((folder) => _buildFolderListItem(folder as Directory))
              .toList(),

          // Files list
          ...state.files
              .map((file) => FileItem(
                    file: file as File,
                    state: state,
                    isSelectionMode: _isSelectionMode,
                    isSelected: _selectedFilePaths.contains(file.path),
                    toggleFileSelection: _toggleFileSelection,
                    showDeleteTagDialog: _showDeleteTagDialog,
                    showAddTagToFileDialog: _showAddTagToFileDialog,
                  ))
              .toList(),
        ],
      );
    }
  }

  Widget _buildFolderGridItem(Directory folder) {
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      child: InkWell(
        onTap: () => _navigateToPath(folder.path),
        child: Column(
          children: [
            // Icon section
            Expanded(
              flex: 3,
              child: Center(
                child: Icon(
                  Icons.folder,
                  size: 40,
                  color: Colors.amber[700], // Màu icon folder đậm hơn
                ),
              ),
            ),
            // Text section
            Container(
              height: 40,
              width: double.infinity,
              padding: const EdgeInsets.all(4),
              color: Colors.grey[200], // Đảm bảo màu nền sáng
              alignment: Alignment.center,
              child: Text(
                folder.basename(),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.black87, // Đảm bảo màu chữ tối
                  fontWeight: FontWeight.w500, // Làm đậm chữ
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFolderListItem(Directory folder) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: ListTile(
        leading: Icon(Icons.folder, color: Colors.amber[700], size: 28),
        title: Text(
          folder.basename(),
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: FutureBuilder<FileStat>(
          future: folder.stat(),
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              return Text(
                '${snapshot.data!.modified.toString().split('.')[0]}',
                style: TextStyle(color: Colors.grey[800]),
              );
            }
            return Text('Loading...',
                style: TextStyle(color: Colors.grey[700]));
          },
        ),
        onTap: () => _navigateToPath(folder.path),
        tileColor: Colors.grey[50], // Nền sáng cho ListTile
      ),
    );
  }

  Widget _buildSearchResultsList(BuildContext context, FolderListState state) {
    String searchTitle = '';
    IconData searchIcon;

    // Determine the search type and appropriate display
    if (state.isSearchByName) {
      searchTitle = 'Search results for name: "${state.currentSearchQuery}"';
      searchIcon = Icons.search;
    } else {
      searchTitle = 'Search results for tag: "${state.currentSearchTag}"';
      searchIcon = Icons.label;
    }

    return Column(
      children: [
        Container(
          color: Colors.grey[100],
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(searchIcon, size: 20, color: Colors.blue),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  searchTitle,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              TextButton.icon(
                icon: const Icon(Icons.clear),
                label: const Text('Clear'),
                onPressed: () {
                  _folderListBloc.add(FolderListLoad(_currentPath));
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: FileView(
            files: state.searchResults.whereType<File>().toList(),
            folders: const [], // No folders in search results view
            state: state,
            isSelectionMode: _isSelectionMode,
            isGridView: state.viewMode == ViewMode.grid,
            selectedFiles: _selectedFilePaths.toList(),
            toggleFileSelection: _toggleFileSelection,
            toggleSelectionMode: _toggleSelectionMode,
            showDeleteTagDialog: _showDeleteTagDialog,
            showAddTagToFileDialog: _showAddTagToFileDialog,
          ),
        ),
      ],
    );
  }

  // Build header for search results
  Widget _buildSearchHeader(BuildContext context, FolderListState state) {
    String searchTitle = '';
    IconData searchIcon;

    // Determine the search type and appropriate display
    if (state.isSearchByName) {
      searchTitle = 'Search results for name: "${state.currentSearchQuery}"';
      searchIcon = Icons.search;
    } else {
      searchTitle = 'Search results for tag: "${state.currentSearchTag}"';
      searchIcon = Icons.label;
    }

    return Container(
      color: Colors.grey[100],
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Icon(searchIcon, size: 20, color: Colors.blue),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              searchTitle,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          TextButton.icon(
            icon: const Icon(Icons.clear),
            label: const Text('Clear'),
            onPressed: () {
              _folderListBloc.add(FolderListLoad(_currentPath));
            },
          ),
        ],
      ),
    );
  }

  void _showAddTagToFileDialog(BuildContext context, String filePath) {
    showAddTagToFileDialog(context, filePath);
  }

  void _showDeleteTagDialog(
      BuildContext context, String filePath, List<String> tags) {
    showDeleteTagDialog(context, filePath, tags);
  }

  void _handleGridZoomChange(int zoomLevel) {
    _folderListBloc.add(SetGridZoom(zoomLevel));
    _saveGridZoomSetting(zoomLevel);
  }

  void _showDeleteConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${_selectedFilePaths.length} items?'),
        content: const Text(
            'This action cannot be undone. Are you sure you want to delete these items?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () {
              BlocProvider.of<FolderListBloc>(context)
                  .add(FolderListDeleteFiles(_selectedFilePaths.toList()));
              Navigator.of(context).pop();
              _clearSelection();
            },
            child: const Text(
              'DELETE',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  // Tag management methods for selection mode
  void _showRemoveTagsDialog(BuildContext context, List<String> filePaths) {
    showDialog(
      context: context,
      builder: (context) {
        final Set<String> availableTags = <String>{};
        bool isLoading = true;

        // Process each file to get all tags
        Future<void> loadTags() async {
          for (final filePath in filePaths) {
            final tags = await TagManager.getTags(filePath);
            availableTags.addAll(tags);
          }

          isLoading = false;
          // Force rebuild of the dialog when tags are loaded
          if (context.mounted) {
            setState(() {});
          }
        }

        // Start loading tags
        loadTags();

        // For tracking which tags to remove
        final selectedTags = <String>{};

        return StatefulBuilder(
          builder: (context, setState) {
            if (isLoading) {
              return AlertDialog(
                title: const Text('Loading Tags'),
                content: const SizedBox(
                  height: 100,
                  child: Center(child: CircularProgressIndicator()),
                ),
              );
            }

            if (availableTags.isEmpty) {
              return AlertDialog(
                title: const Text('Không có thẻ'),
                content: const Text('Các tệp đã chọn không có thẻ nào.'),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: const Text('ĐÓNG'),
                  ),
                ],
              );
            }

            return AlertDialog(
              title: const Text('Xóa thẻ'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Chọn thẻ cần xóa khỏi các tệp đã chọn:'),
                    const SizedBox(height: 16),
                    Flexible(
                      child: ListView(
                        shrinkWrap: true,
                        children: availableTags.map((tag) {
                          return CheckboxListTile(
                            title: Text(tag),
                            value: selectedTags.contains(tag),
                            onChanged: (bool? selected) {
                              setState(() {
                                if (selected == true) {
                                  selectedTags.add(tag);
                                } else {
                                  selectedTags.remove(tag);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('HỦY'),
                ),
                TextButton(
                  onPressed: selectedTags.isEmpty
                      ? null
                      : () async {
                          // Remove selected tags from files
                          for (final tag in selectedTags) {
                            await BatchTagManager.removeTagFromFiles(
                                filePaths, tag);
                          }
                          Navigator.of(context).pop();

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  'Đã xóa ${selectedTags.length} thẻ khỏi ${filePaths.length} tệp'),
                            ),
                          );

                          // Refresh file list to update tags
                          _refreshFileList();
                        },
                  child: const Text('XÓA THẺ'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showManageAllTagsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        final List<String> allTags = [];
        bool isLoading = true;

        // Load all unique tags
        Future<void> loadAllTags() async {
          final tags = await TagManager.getAllUniqueTags(_currentPath);
          allTags.addAll(tags);
          isLoading = false;

          // Force rebuild of the dialog when tags are loaded
          if (context.mounted) {
            setState(() {});
          }
        }

        // Start loading tags
        loadAllTags();

        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            title: const Text('Quản lý tất cả thẻ'),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Tất cả thẻ hiện có trong hệ thống:'),
                  const SizedBox(height: 16),
                  Flexible(
                    child: isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : (allTags.isEmpty
                            ? const Center(
                                child: Text('Không có thẻ nào'),
                              )
                            : ListView.builder(
                                shrinkWrap: true,
                                itemCount: allTags.length,
                                itemBuilder: (context, index) {
                                  final tag = allTags[index];
                                  return ListTile(
                                    title: Text(tag),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.delete_outline),
                                      onPressed: () {
                                        _showDeleteTagConfirmationDialog(
                                            context, tag);
                                      },
                                    ),
                                  );
                                },
                              )),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('ĐÓNG'),
              ),
            ],
          );
        });
      },
    );
  }

  void _showDeleteTagConfirmationDialog(BuildContext context, String tag) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Xóa thẻ "$tag"?'),
          content: const Text(
              'Thẻ này sẽ bị xóa khỏi tất cả các tệp. Bạn có chắc chắn muốn tiếp tục?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('HỦY'),
            ),
            TextButton(
              onPressed: () async {
                // Find all files with this tag
                final files =
                    await TagManager.findFilesByTag(_currentPath, tag);

                // Remove tag from all files - Convert FileSystemEntity list to String list
                if (files.isNotEmpty) {
                  final filePaths = files.map((file) => file.path).toList();
                  await BatchTagManager.removeTagFromFiles(filePaths, tag);
                }

                Navigator.of(context).pop();
                Navigator.of(context).pop(); // Close the manage tags dialog too

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Đã xóa thẻ "$tag" khỏi tất cả tệp'),
                  ),
                );

                // Refresh file list to update tags
                _refreshFileList();
              },
              child: const Text('XÓA', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024)
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  Future<Map<String, dynamic>> _getDriveSpaceInfo(String drivePath) async {
    try {
      final drive = drivePath.endsWith('\\') ? drivePath : drivePath + '\\';
      final lpFreeBytesAvailable = calloc.allocate<Uint64>(sizeOf<Uint64>());
      final lpTotalNumberOfBytes = calloc.allocate<Uint64>(sizeOf<Uint64>());
      final lpTotalNumberOfFreeBytes =
          calloc.allocate<Uint64>(sizeOf<Uint64>());

      final result = win32.GetDiskFreeSpaceEx(
        drive.toNativeUtf16(),
        lpFreeBytesAvailable,
        lpTotalNumberOfBytes,
        lpTotalNumberOfFreeBytes,
      );

      String totalStr = '';
      String freeStr = '';
      String usedStr = '';
      int totalBytes = 0;
      int freeBytes = 0;
      int usedBytes = 0;
      double usageRatio = 0.0;

      if (result != 0) {
        // Đọc giá trị từ con trỏ
        totalBytes = lpTotalNumberOfBytes.value;
        freeBytes = lpFreeBytesAvailable.value;
        usedBytes = totalBytes - freeBytes;

        totalStr = _formatSize(totalBytes);
        freeStr = _formatSize(freeBytes);
        usedStr = _formatSize(usedBytes);

        // Tính tỷ lệ sử dụng (0.0 - 1.0)
        usageRatio = totalBytes > 0 ? usedBytes / totalBytes : 0;
      }

      // Giải phóng bộ nhớ đã cấp phát
      calloc.free(lpFreeBytesAvailable);
      calloc.free(lpTotalNumberOfBytes);
      calloc.free(lpTotalNumberOfFreeBytes);

      return {
        'totalStr': totalStr,
        'freeStr': freeStr,
        'usedStr': usedStr,
        'total': totalBytes,
        'free': freeBytes,
        'used': usedBytes,
        'usageRatio': usageRatio,
      };
    } catch (e) {
      print('Error getting drive space info: $e');
      return {
        'totalStr': '',
        'freeStr': '',
        'usedStr': '',
        'total': 0,
        'free': 0,
        'used': 0,
        'usageRatio': 0.0,
      };
    }
  }
}
