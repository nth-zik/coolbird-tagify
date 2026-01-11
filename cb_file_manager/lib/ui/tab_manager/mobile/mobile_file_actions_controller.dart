import 'package:flutter/material.dart';
import 'package:cb_file_manager/ui/screens/folder_list/folder_list_state.dart';
import 'package:cb_file_manager/config/languages/app_localizations.dart';

/// Controller to manage file actions from mobile action bar
/// This allows the mobile action buttons to communicate with TabbedFolderListScreen
class MobileFileActionsController {
  static final Map<String, MobileFileActionsController> _instances = {};

  final String tabId;

  // Callbacks for actions
  VoidCallback? onSearchPressed;
  Function(String?)? onSearchSubmitted; // Callback when search is submitted
  Function(bool)? onRecursiveChanged; // Callback when recursive search toggled
  Function(SortOption)? onSortOptionSelected;
  Function(ViewMode)? onViewModeToggled;
  VoidCallback? onRefresh;
  VoidCallback? onGridSizePressed;
  VoidCallback? onSelectionModeToggled;
  VoidCallback? onManageTagsPressed;
  Function(String)? onGallerySelected;
  // Masonry (Pinterest-like) layout toggle
  VoidCallback? onMasonryToggled;

  // Current state
  SortOption? currentSortOption;
  ViewMode? currentViewMode;
  int? currentGridSize;
  String? currentPath;
  String? currentSearchQuery;
  bool isRecursiveSearch = true; // Default to recursive search
  bool isMasonryLayout = false; // Current masonry layout state

  MobileFileActionsController(this.tabId);

  /// Get or create controller for a tab
  static MobileFileActionsController forTab(String tabId) {
    if (!_instances.containsKey(tabId)) {
      _instances[tabId] = MobileFileActionsController(tabId);
    }
    return _instances[tabId]!;
  }

  /// Remove controller when tab is closed
  static void removeTab(String tabId) {
    _instances.remove(tabId);
  }

  /// Clear all controllers
  static void clearAll() {
    _instances.clear();
  }

  /// Show sort options dialog
  void showSortDialog(BuildContext context) {
    if (currentSortOption == null || onSortOptionSelected == null) return;

    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.dividerColor.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Sắp xếp theo',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),

                const Divider(height: 1),

                // Sort options
                ListView(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildSortOption(
                        context, SortOption.nameAsc, 'Tên (A → Z)'),
                    _buildSortOption(
                        context, SortOption.nameDesc, 'Tên (Z → A)'),
                    const Divider(),
                    _buildSortOption(
                        context, SortOption.dateDesc, 'Ngày sửa (Mới nhất)'),
                    _buildSortOption(
                        context, SortOption.dateAsc, 'Ngày sửa (Cũ nhất)'),
                    const Divider(),
                    _buildSortOption(
                        context, SortOption.sizeDesc, 'Kích thước (Lớn nhất)'),
                    _buildSortOption(
                        context, SortOption.sizeAsc, 'Kích thước (Nhỏ nhất)'),
                    const Divider(),
                    _buildSortOption(
                        context, SortOption.typeAsc, 'Loại (A → Z)'),
                    _buildSortOption(
                        context, SortOption.typeDesc, 'Loại (Z → A)'),
                  ],
                ),

                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSortOption(
      BuildContext context, SortOption option, String label) {
    final theme = Theme.of(context);
    final isSelected = currentSortOption == option;

    return ListTile(
      title: Text(
        label,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? theme.colorScheme.primary : null,
        ),
      ),
      trailing: isSelected
          ? Icon(Icons.check, color: theme.colorScheme.primary)
          : null,
      onTap: () {
        Navigator.pop(context);
        onSortOptionSelected?.call(option);
      },
    );
  }

  /// Show view mode options dialog
  void showViewModeDialog(BuildContext context) {
    if (currentViewMode == null) return;

    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.dividerColor.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Chế độ xem',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),

                const Divider(height: 1),

                // View mode options (mobile only: list & grid)
                _buildViewModeOption(
                    context, ViewMode.list, 'Danh sách', Icons.view_list),
                _buildViewModeOption(
                    context, ViewMode.grid, 'Lưới', Icons.grid_view),

                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildViewModeOption(
      BuildContext context, ViewMode mode, String label, IconData icon) {
    final theme = Theme.of(context);
    final isSelected = currentViewMode == mode;

    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? theme.colorScheme.primary : null,
      ),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? theme.colorScheme.primary : null,
        ),
      ),
      trailing: isSelected
          ? Icon(Icons.check, color: theme.colorScheme.primary)
          : null,
      onTap: () {
        Navigator.pop(context);
        if (!isSelected) {
          currentViewMode = mode;
          onViewModeToggled?.call(mode);
        }
      },
    );
  }

  /// Show more options menu
  void showMoreOptionsMenu(BuildContext context) {
    final theme = Theme.of(context);
    final localizations = AppLocalizations.of(context)!;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.dividerColor.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                localizations.moreOptions,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),

            const Divider(height: 1),

            // More options
            ListTile(
              leading: const Icon(Icons.select_all),
              title: Text(localizations.selectMultiple ?? 'Chọn nhiều file'),
              onTap: () {
                Navigator.pop(context);
                onSelectionModeToggled?.call();
              },
            ),

            if (onGridSizePressed != null && currentViewMode == ViewMode.grid)
              ListTile(
                leading: const Icon(Icons.photo_size_select_large),
                title: Text(localizations.gridSize ?? 'Kích thước lưới'),
                onTap: () {
                  Navigator.pop(context);
                  onGridSizePressed?.call();
                },
              ),

            if (onManageTagsPressed != null)
              ListTile(
                leading: const Icon(Icons.label),
                title: Text(localizations.tagManagement),
                onTap: () {
                  Navigator.pop(context);
                  onManageTagsPressed?.call();
                },
              ),

            // Masonry toggle option
            ListTile(
              leading: Icon(
                Icons.view_quilt,
                color: isMasonryLayout
                    ? theme.colorScheme.primary
                    : theme.iconTheme.color,
              ),
              title: const Text('Masonry layout (Pinterest)'),
              trailing: isMasonryLayout
                  ? Icon(Icons.check, color: theme.colorScheme.primary)
                  : null,
              onTap: () {
                Navigator.pop(context);
                isMasonryLayout = !isMasonryLayout;
                onMasonryToggled?.call();
              },
            ),

            if (onGallerySelected != null && currentPath != null) ...[
              const Divider(),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: Text(localizations.imageGallery),
                onTap: () {
                  Navigator.pop(context);
                  onGallerySelected?.call('image_gallery');
                },
              ),
              ListTile(
                leading: const Icon(Icons.video_library),
                title: Text(localizations.videoGallery),
                onTap: () {
                  Navigator.pop(context);
                  onGallerySelected?.call('video_gallery');
                },
              ),
            ],

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  /// Build mobile action bar with 5 buttons
  Widget buildMobileActionBar(BuildContext context, {ViewMode? viewMode}) {
    debugPrint(
        '📱 buildMobileActionBar called - tabId: $tabId, currentPath: $currentPath');

    final theme = Theme.of(context);
    final localizations = AppLocalizations.of(context)!;
    // On mobile, convert details mode to list mode (details not supported on mobile)
    var effectiveViewMode = viewMode ?? currentViewMode ?? ViewMode.grid;
    if (effectiveViewMode == ViewMode.details) {
      effectiveViewMode = ViewMode.list;
    }

    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 2.0),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.05),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Search button - opens simple inline search
          IconButton(
            icon: const Icon(Icons.search, size: 20),
            tooltip: localizations.search,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            onPressed: () => showInlineSearch(context),
          ),

          // Sort button
          IconButton(
            icon: const Icon(Icons.sort, size: 20),
            tooltip: localizations.sort,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            onPressed: () {
              showSortDialog(context);
            },
          ),

          // View mode button
          IconButton(
            icon: Icon(
              effectiveViewMode == ViewMode.grid
                  ? Icons.view_list
                  : Icons.grid_view,
              size: 20,
            ),
            tooltip: localizations.listViewMode,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            onPressed: () {
              showViewModeDialog(context);
            },
          ),

          // Masonry layout toggle
          IconButton(
            icon: Icon(
              Icons.view_quilt,
              size: 20,
              color: isMasonryLayout
                  ? theme.colorScheme.primary
                  : theme.iconTheme.color,
            ),
            tooltip: 'Masonry',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            onPressed: () {
              isMasonryLayout = !isMasonryLayout;
              onMasonryToggled?.call();
            },
          ),

          // Refresh button
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            tooltip: localizations.refresh,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            onPressed: () {
              onRefresh?.call();
            },
          ),

          // More options button
          IconButton(
            icon: const Icon(Icons.more_vert, size: 20),
            tooltip: localizations.moreOptions,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            onPressed: () {
              showMoreOptionsMenu(context);
            },
          ),
        ],
      ),
    );
  }

  /// Show inline search - simple and clean
  void showInlineSearch(BuildContext context) {
    final theme = Theme.of(context);
    final localizations = AppLocalizations.of(context)!;
    final searchController = TextEditingController(text: currentSearchQuery);

    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (context) => Align(
        alignment: Alignment.topCenter,
        child: Material(
          color: Colors.transparent,
          child: Container(
            margin: const EdgeInsets.only(top: 44), // Below action bar
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              boxShadow: [
                BoxShadow(
                  color: theme.shadowColor.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: StatefulBuilder(
              builder: (context, setState) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Search bar
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        // Back button to close search
                        IconButton(
                          icon: const Icon(Icons.arrow_back, size: 20),
                          padding: EdgeInsets.zero,
                          constraints:
                              const BoxConstraints(minWidth: 40, minHeight: 40),
                          onPressed: () {
                            searchController.clear();
                            currentSearchQuery = null;
                            onSearchSubmitted?.call(null);
                            Navigator.pop(context);
                          },
                        ),

                        const SizedBox(width: 4),

                        // Search field
                        Expanded(
                          child: TextField(
                            controller: searchController,
                            autofocus: true,
                            style: const TextStyle(fontSize: 14),
                            decoration: InputDecoration(
                              hintText: localizations.searchByNameOrTag,
                              border: InputBorder.none,
                              isDense: true,
                            ),
                            onChanged: (value) {
                              // Real-time search as user types
                              currentSearchQuery = value.isEmpty ? null : value;
                              onSearchSubmitted?.call(currentSearchQuery);
                              setState(() {}); // Update clear button visibility
                            },
                            onSubmitted: (value) {
                              // On Enter: ensure search is triggered and close dialog
                              currentSearchQuery = value.isEmpty ? null : value;
                              onSearchSubmitted?.call(currentSearchQuery);
                              Navigator.pop(context);
                            },
                          ),
                        ),

                        // Clear button
                        if (searchController.text.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                                minWidth: 32, minHeight: 32),
                            onPressed: () {
                              searchController.clear();
                              currentSearchQuery = null;
                              onSearchSubmitted?.call(null);
                              setState(() {}); // Update UI
                            },
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
