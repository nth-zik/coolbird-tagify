import 'dart:io';

import 'package:cb_file_manager/helpers/tags/tag_manager.dart';
import 'package:cb_file_manager/helpers/tags/tag_color_manager.dart';
import 'package:cb_file_manager/ui/screens/folder_list/file_details_screen.dart';
import 'package:cb_file_manager/ui/widgets/tag_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:path/path.dart' as pathlib;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cb_file_manager/ui/tab_manager/core/tab_manager.dart';
import 'package:cb_file_manager/ui/tab_manager/core/tab_data.dart';
import 'package:cb_file_manager/config/languages/app_localizations.dart';
import 'package:cb_file_manager/helpers/core/uri_utils.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../utils/route.dart';

class TagManagementScreen extends StatefulWidget {
  final String startingDirectory;

  /// Callback when a tag is selected, used for opening in a new tab
  final Function(String)? onTagSelected;

  const TagManagementScreen({
    Key? key,
    this.startingDirectory = '',
    this.onTagSelected,
  }) : super(key: key);

  @override
  State<TagManagementScreen> createState() => _TagManagementScreenState();
}

class _TagManagementScreenState extends State<TagManagementScreen> {
  late TagColorManager _tagColorManager;

  bool _isInitializing = true;
  bool _isLoading = false;
  List<String> _allTags = [];
  List<String> _filteredTags = [];

  // Tags created standalone (not yet assigned to any file)
  final Set<String> _standaloneCreatedTags = {};
  String? _selectedTag;
  List<Map<String, dynamic>> _filesBySelectedTag = [];

  // Search functionality
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  // Pagination variables
  int _currentPage = 0;
  int _tagsPerPage = 60;
  int _totalPages = 0;
  List<String> _currentPageTags = [];

  // Sorting options
  String _sortCriteria = 'name';
  bool _sortAscending = true;

  // View mode options
  bool _isGridView = false;

  @override
  void initState() {
    super.initState();
    _initializeDatabase();

    _tagColorManager = TagColorManager.instance;
    _initTagColorManager();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setDefaultViewMode();
    });

    _searchController.addListener(_filterTags);
  }

  void _setDefaultViewMode() {
    if (!mounted) return;
    final screenWidth = MediaQuery.of(context).size.width;
    _isGridView = screenWidth > 600;
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterTags);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initTagColorManager() async {
    await _tagColorManager.initialize();
    if (mounted) setState(() {});
  }

  Future<void> _initializeDatabase() async {
    setState(() {
      _isInitializing = true;
    });

    try {
      await _loadAllTags();
    } catch (e) {
      // Handle initialization error
    } finally {
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    }
  }

  Future<void> _loadAllTags() async {
    try {
      await TagManager.initialize();
      final Set<String> tags = await TagManager.getAllUniqueTags("");
      tags.addAll(_standaloneCreatedTags);

      debugPrint(
          'TagManagementScreen: Found ${tags.length} unique tags (incl. ${_standaloneCreatedTags.length} standalone)');

      if (mounted) {
        setState(() {
          _allTags = tags.toList();
          _allTags.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
          _filterTags();
        });
      }
    } catch (e) {
      debugPrint('TagManagementScreen: Error loading tags: $e');
      if (mounted) {
        final theme = Theme.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('${AppLocalizations.of(context)!.errorLoadingTags}$e'),
            backgroundColor: theme.colorScheme.error,
            duration: const Duration(seconds: 3),
          ),
        );
        setState(() {
          _allTags = [];
          _filterTags();
        });
      }
    }
  }

  void _filterTags() {
    if (!mounted) return;

    final String query = _searchController.text.toLowerCase().trim();
    debugPrint('TagManagementScreen: Filtering tags with query: "$query"');
    debugPrint('TagManagementScreen: _allTags count: ${_allTags.length}');

    setState(() {
      if (query.isEmpty) {
        _filteredTags = List.from(_allTags);
      } else {
        _filteredTags =
            _allTags.where((tag) => tag.toLowerCase().contains(query)).toList();
      }

      debugPrint(
          'TagManagementScreen: _filteredTags count: ${_filteredTags.length}');

      _sortTags();
      _updatePagination();

      debugPrint(
          'TagManagementScreen: _currentPageTags count: ${_currentPageTags.length}');
    });
  }

  void _sortTags() {
    switch (_sortCriteria) {
      case 'name':
        _filteredTags.sort((a, b) {
          final result = a.toLowerCase().compareTo(b.toLowerCase());
          return _sortAscending ? result : -result;
        });
        break;
      case 'popularity':
        _filteredTags.sort((a, b) {
          final result = a.toLowerCase().compareTo(b.toLowerCase());
          return _sortAscending ? result : -result;
        });
        break;
      case 'recent':
        _filteredTags.sort((a, b) {
          final result = a.toLowerCase().compareTo(b.toLowerCase());
          return _sortAscending ? result : -result;
        });
        break;
    }
  }

  void _updatePagination() {
    final screenHeight = MediaQuery.of(context).size.height;
    _tagsPerPage = (screenHeight ~/ 40).clamp(40, 200);

    _totalPages = (_filteredTags.length / _tagsPerPage).ceil();
    if (_totalPages == 0) _totalPages = 1;

    if (_currentPage >= _totalPages) {
      _currentPage = _totalPages - 1;
    }
    if (_currentPage < 0) {
      _currentPage = 0;
    }

    final startIndex = _currentPage * _tagsPerPage;
    final endIndex = startIndex + _tagsPerPage;

    if (startIndex < _filteredTags.length) {
      _currentPageTags = _filteredTags.sublist(startIndex,
          endIndex > _filteredTags.length ? _filteredTags.length : endIndex);
    } else {
      _currentPageTags = [];
    }

    debugPrint(
        'TagManagementScreen: Pagination - _filteredTags: ${_filteredTags.length}, _tagsPerPage: $_tagsPerPage, _totalPages: $_totalPages, _currentPage: $_currentPage, _currentPageTags: ${_currentPageTags.length}');
  }

  void _goToPage(int page) {
    if (page >= 0 && page < _totalPages) {
      setState(() {
        _currentPage = page;
        _updatePagination();
      });
    }
  }

  void _nextPage() {
    _goToPage(_currentPage + 1);
  }

  void _previousPage() {
    _goToPage(_currentPage - 1);
  }

  void _changeSortCriteria(String criteria) {
    setState(() {
      if (_sortCriteria == criteria) {
        _sortAscending = !_sortAscending;
      } else {
        _sortCriteria = criteria;
        _sortAscending = true;
      }

      _sortTags();
      _updatePagination();
    });
  }

  Future<void> _handleTagTap(String tag) async {
    final onTagSelected = widget.onTagSelected;
    if (onTagSelected != null) {
      onTagSelected(tag);
      return;
    }

    await _directTagSearch(tag);
  }

  Future<void> _directTagSearch(String tag) async {
    try {
      final tabManagerBloc = BlocProvider.of<TabManagerBloc>(context);
      final tagSearchPath = UriUtils.buildTagSearchPath(tag);

      final existingTab = tabManagerBloc.state.tabs.firstWhere(
        (tab) => tab.path == tagSearchPath,
        orElse: () => TabData(id: '', name: '', path: ''),
      );

      if (existingTab.id.isNotEmpty) {
        tabManagerBloc.add(SwitchToTab(existingTab.id));
      } else {
        tabManagerBloc.add(
          AddTab(
            path: tagSearchPath,
            name: 'Tag: $tag',
            switchToTab: true,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error opening tag in new tab: $e');
    }
  }

  void _clearTagSelection() {
    setState(() {
      _selectedTag = null;
      _filesBySelectedTag = [];
    });
  }

  Future<void> _confirmDeleteTag(String tag) async {
    final theme = Theme.of(context);
    final AppLocalizations localizations = AppLocalizations.of(context)!;
    final bool result = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations.deleteTagConfirmation(tag)),
        content: Text(localizations.tagDeleteConfirmationText),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(localizations.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              localizations.delete,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
        ],
      ),
    );

    if (result == true) {
      await _deleteTag(tag);
    }
  }

  Future<void> _deleteTag(String tag) async {
    final AppLocalizations localizations = AppLocalizations.of(context)!;
    setState(() {
      _isLoading = true;
    });

    try {
      _standaloneCreatedTags.remove(tag);
      await TagManager.deleteTagGlobally(tag);
      await _loadAllTags();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(localizations.tagDeleted(tag))),
        );
      }

      await _tagColorManager.removeTagColor(tag);

      if (_selectedTag == tag) {
        _clearTagSelection();
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showColorPickerDialog(String tag) {
    final AppLocalizations localizations = AppLocalizations.of(context)!;
    Color currentColor = _tagColorManager.getTagColor(tag);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(localizations.chooseTagColor(tag)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: TagChip(
                    tag: tag,
                    customColor: currentColor,
                  ),
                ),
                ColorPicker(
                  pickerColor: currentColor,
                  onColorChanged: (color) {
                    currentColor = color;
                  },
                  pickerAreaHeightPercent: 0.8,
                  enableAlpha: false,
                  displayThumbColor: true,
                  labelTypes: const [ColorLabelType.rgb, ColorLabelType.hsv],
                  pickerAreaBorderRadius:
                      const BorderRadius.all(Radius.circular(12)),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                RouteUtils.safePopDialog(context);
              },
              child: Text(localizations.cancel),
            ),
            ElevatedButton(
              onPressed: () async {
                await _tagColorManager.setTagColor(tag, currentColor);
                if (mounted) {
                  setState(() {});
                  RouteUtils.safePopDialog(context);

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(localizations.tagColorUpdated(tag)),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              },
              child: Text(localizations.save),
            ),
          ],
        );
      },
    );
  }

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchController.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localizations = AppLocalizations.of(context)!;

    Widget body;
    if (_isInitializing) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_selectedTag != null) {
      body = _buildFilesByTagList();
    } else {
      body = _buildTagsList();
    }

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                textInputAction: TextInputAction.search,
                style: TextStyle(color: theme.colorScheme.onSurface),
                decoration: InputDecoration(
                  hintText: localizations.searchTagsHint,
                  hintStyle: TextStyle(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                  border: InputBorder.none,
                ),
              )
            : Text(localizations.tagManagementTitle),
        actions: [
          IconButton(
            icon: Icon(
                _isSearching ? PhosphorIconsLight.x : PhosphorIconsLight.magnifyingGlass),
            onPressed: _toggleSearch,
            tooltip: localizations.searchTags,
          ),
          IconButton(
            icon: const Icon(PhosphorIconsLight.arrowsClockwise),
            onPressed: _loadAllTags,
            tooltip: localizations.tryAgain,
          ),
        ],
      ),
      body: body,
      floatingActionButton: _selectedTag == null
          ? FloatingActionButton(
              heroTag: null,
              onPressed: _showCreateTagDialog,
              backgroundColor: theme.colorScheme.primary,
              tooltip: localizations.newTagTooltip,
              child: Icon(
                PhosphorIconsLight.plus,
                color: theme.colorScheme.onPrimary,
                size: 24,
              ),
            )
          : null,
    );
  }

  void _showTagOptions(String tag) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(PhosphorIconsLight.palette),
                title: Text(AppLocalizations.of(context)!.changeTagColor),
                onTap: () {
                  Navigator.pop(context);
                  _showColorPickerDialog(tag);
                },
              ),
              if (widget.onTagSelected == null)
                ListTile(
                  leading: const Icon(PhosphorIconsLight.appWindow),
                  title: Text(AppLocalizations.of(context)!.openInNewTab),
                  onTap: () {
                    Navigator.pop(context);
                    _directTagSearch(tag);
                  },
                ),
              ListTile(
                leading: Icon(PhosphorIconsLight.trash,
                    color: theme.colorScheme.error),
                title: Text(AppLocalizations.of(context)!.deleteTag,
                    style: TextStyle(color: theme.colorScheme.error)),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDeleteTag(tag);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTagsList() {
    final theme = Theme.of(context);

    if (_allTags.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              PhosphorIconsLight.tag,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 24),
            Text(
              AppLocalizations.of(context)!.noTagsFoundMessage,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)!.noTagsFoundDescription,
              style: TextStyle(
                fontSize: 14,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _showCreateTagDialog,
              icon: const Icon(PhosphorIconsLight.plus),
              label: Text(AppLocalizations.of(context)!.createNewTagButton),
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      );
    }

    if (_filteredTags.isEmpty && _searchController.text.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              PhosphorIconsLight.magnifyingGlass,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 24),
            Text(
              AppLocalizations.of(context)!
                  .noMatchingTagsMessage(_searchController.text),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () {
                _searchController.clear();
              },
              icon: const Icon(PhosphorIconsLight.x, size: 20),
              label: Text(AppLocalizations.of(context)!.clearSearch),
              style: OutlinedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      );
    }

    final localizations = AppLocalizations.of(context)!;
    final screenWidth = MediaQuery.of(context).size.width;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with tag count and controls
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(
            children: [
              Icon(PhosphorIconsLight.tag,
                  size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 12),
              Text(
                '${_filteredTags.length} ${localizations.tagsCreated}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              if (screenWidth > 600) ...[
                PopupMenuButton<String>(
                  tooltip: localizations.sortTags,
                  onSelected: _changeSortCriteria,
                  icon: Icon(PhosphorIconsLight.sortAscending,
                      size: 20,
                      color: theme.colorScheme.onSurfaceVariant),
                  itemBuilder: (context) => [
                    _buildSortMenuItem('name', PhosphorIconsLight.sortAscending,
                        localizations.sortByAlphabet),
                    _buildSortMenuItem('popularity', PhosphorIconsLight.chartBar,
                        localizations.sortByPopular),
                    _buildSortMenuItem('recent', PhosphorIconsLight.clockCounterClockwise,
                        localizations.sortByRecent),
                  ],
                ),
                IconButton(
                  onPressed: () => setState(() => _isGridView = !_isGridView),
                  icon: Icon(
                    _isGridView
                        ? PhosphorIconsLight.listBullets
                        : PhosphorIconsLight.squaresFour,
                    color: theme.colorScheme.onSurfaceVariant,
                    size: 20,
                  ),
                  tooltip: _isGridView
                      ? localizations.listViewMode
                      : localizations.gridViewMode,
                ),
              ],
            ],
          ),
        ),

        // Tags list or grid
        Expanded(
          child: _isGridView ? _buildTagsGridView() : _buildTagsListView(),
        ),

        // Bottom pagination controls
        if (_totalPages > 1)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(PhosphorIconsLight.skipBack),
                  iconSize: 20,
                  onPressed: _currentPage > 0 ? () => _goToPage(0) : null,
                ),
                IconButton(
                  icon: const Icon(PhosphorIconsLight.caretLeft),
                  iconSize: 20,
                  onPressed: _currentPage > 0 ? _previousPage : null,
                ),
                ..._buildPageIndicators(),
                IconButton(
                  icon: const Icon(PhosphorIconsLight.caretRight),
                  iconSize: 20,
                  onPressed:
                      _currentPage < _totalPages - 1 ? _nextPage : null,
                ),
                IconButton(
                  icon: const Icon(PhosphorIconsLight.skipForward),
                  iconSize: 20,
                  onPressed: _currentPage < _totalPages - 1
                      ? () => _goToPage(_totalPages - 1)
                      : null,
                ),
              ],
            ),
          ),
      ],
    );
  }

  PopupMenuItem<String> _buildSortMenuItem(
      String value, IconData icon, String label) {
    final theme = Theme.of(context);
    final isActive = _sortCriteria == value;
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon,
              size: 18,
              color: isActive ? theme.colorScheme.primary : null),
          const SizedBox(width: 12),
          Text(label),
          if (isActive)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Icon(
                _sortAscending
                    ? PhosphorIconsLight.arrowUp
                    : PhosphorIconsLight.arrowDown,
                size: 16,
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildPageIndicators() {
    final theme = Theme.of(context);
    List<Widget> indicators = [];

    int startPage = _currentPage - 2;
    int endPage = _currentPage + 2;

    if (startPage < 0) {
      endPage -= startPage;
      startPage = 0;
    }

    if (endPage >= _totalPages) {
      startPage =
          (startPage - (endPage - _totalPages + 1)).clamp(0, _totalPages - 1);
      endPage = _totalPages - 1;
    }

    if (startPage > 0) {
      indicators.add(Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text('...',
            style: TextStyle(
                fontSize: 16, color: theme.colorScheme.onSurfaceVariant)),
      ));
    }

    for (int i = startPage; i <= endPage; i++) {
      indicators.add(
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          child: InkWell(
            onTap: () => _goToPage(i),
            borderRadius: BorderRadius.circular(16.0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: i == _currentPage
                    ? theme.colorScheme.primary
                    : theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16.0),
              ),
              child: Text(
                '${i + 1}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight:
                      i == _currentPage ? FontWeight.w600 : FontWeight.normal,
                  color: i == _currentPage
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (endPage < _totalPages - 1) {
      indicators.add(Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text('...',
            style: TextStyle(
                fontSize: 16, color: theme.colorScheme.onSurfaceVariant)),
      ));
    }

    return indicators;
  }

  Widget _buildTagsListView() {
    final theme = Theme.of(context);

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _currentPageTags.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final tag = _currentPageTags[index];
        final tagColor = TagColorManager.instance.getTagColor(tag);

        return ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
          tileColor: tagColor.withValues(alpha: 0.08),
          leading: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: tagColor, shape: BoxShape.circle),
          ),
          title: Text(
            tag,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurface,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          onTap: () => _handleTagTap(tag),
          onLongPress: () => _showTagOptions(tag),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(PhosphorIconsLight.palette,
                    size: 20,
                    color: theme.colorScheme.onSurfaceVariant),
                onPressed: () => _showColorPickerDialog(tag),
                visualDensity: VisualDensity.compact,
              ),
              IconButton(
                icon: Icon(PhosphorIconsLight.trash,
                    size: 20,
                    color: theme.colorScheme.error.withValues(alpha: 0.7)),
                onPressed: () => _confirmDeleteTag(tag),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTagsGridView() {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: screenWidth > 1200
            ? 8
            : screenWidth > 900
                ? 6
                : screenWidth > 600
                    ? 5
                    : 3,
        childAspectRatio: 1.6,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: _currentPageTags.length,
      itemBuilder: (context, index) {
        final tag = _currentPageTags[index];
        final tagColor = TagColorManager.instance.getTagColor(tag);

        return InkWell(
          borderRadius: BorderRadius.circular(16.0),
          onTap: () => _handleTagTap(tag),
          onLongPress: () => _showTagOptions(tag),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: tagColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16.0),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration:
                      BoxDecoration(color: tagColor, shape: BoxShape.circle),
                ),
                const SizedBox(height: 4),
                Text(
                  tag,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    InkWell(
                      onTap: () => _showColorPickerDialog(tag),
                      borderRadius: BorderRadius.circular(16.0),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(PhosphorIconsLight.palette,
                            size: 16,
                            color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () => _confirmDeleteTag(tag),
                      borderRadius: BorderRadius.circular(16.0),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(PhosphorIconsLight.trash,
                            size: 16,
                            color:
                                theme.colorScheme.error.withValues(alpha: 0.7)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilesByTagList() {
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_filesBySelectedTag.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              PhosphorIconsLight.fileMagnifyingGlass,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 24),
            Text(
              AppLocalizations.of(context)!.noFilesWithTag,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)!.debugInfo(_selectedTag ?? 'none'),
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton.icon(
                  icon: const Icon(PhosphorIconsLight.arrowLeft, size: 20),
                  label: Text(AppLocalizations.of(context)!.backToAllTags),
                  onPressed: _clearTagSelection,
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  icon: const Icon(PhosphorIconsLight.arrowsClockwise, size: 20),
                  label: Text(AppLocalizations.of(context)!.tryAgain),
                  onPressed: _selectedTag != null
                      ? () => _directTagSearch(_selectedTag!)
                      : null,
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Action buttons and header
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
          ),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  TextButton.icon(
                    icon: const Icon(PhosphorIconsLight.arrowLeft, size: 20),
                    label: Text(AppLocalizations.of(context)!.backToAllTags),
                    onPressed: _clearTagSelection,
                  ),
                  const Spacer(),
                  if (_selectedTag != null)
                    TextButton.icon(
                      icon: const Icon(PhosphorIconsLight.palette, size: 20),
                      label: Text(
                          AppLocalizations.of(context)!.changeColor),
                      onPressed: () =>
                          _showColorPickerDialog(_selectedTag!),
                    ),
                ],
              ),

              const SizedBox(height: 16),

              // Tag header with custom color
              if (_selectedTag != null)
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: TagColorManager.instance
                            .getTagColor(_selectedTag!),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _selectedTag!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${_filesBySelectedTag.length} ${AppLocalizations.of(context)!.filesWithTagCount}',
                      style: TextStyle(
                        fontSize: 14,
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),

        // Files list
        Expanded(
          child: ListView.builder(
            padding:
                const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
            itemCount: _filesBySelectedTag.length,
            itemBuilder: (context, index) {
              final file = _filesBySelectedTag[index];
              final String path = file['path'] as String;
              final String fileName = pathlib.basename(path);
              final String dirName = pathlib.dirname(path);

              return MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onSecondaryTap: () => _showFileOptions(path),
                  child: Card(
                    margin: const EdgeInsets.only(bottom: 8.0),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16.0),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer
                              .withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          PhosphorIconsLight.fileText,
                          color: theme.colorScheme.primary,
                          size: 24,
                        ),
                      ),
                      title: Text(
                        fileName,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: theme.colorScheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        dirName,
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Icon(
                        PhosphorIconsLight.caretRight,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => FileDetailsScreen(
                              file: File(path),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showFileOptions(String filePath) {
    final theme = Theme.of(context);
    final File file = File(filePath);
    final String fileName = pathlib.basename(filePath);

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer
                      .withValues(alpha: 0.3),
                ),
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fileName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      filePath,
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              ListTile(
                leading: const Icon(PhosphorIconsLight.info),
                title: Text(AppLocalizations.of(context)!.viewDetails),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => FileDetailsScreen(
                        file: file,
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(PhosphorIconsLight.folderOpen),
                title: Text(AppLocalizations.of(context)!.openContainingFolder),
                onTap: () {
                  Navigator.pop(context);
                  final directory = pathlib.dirname(filePath);
                  _openContainingFolder(directory);
                },
              ),
              ListTile(
                leading: const Icon(PhosphorIconsLight.pencilSimple),
                title: Text(AppLocalizations.of(context)!.editTags),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => FileDetailsScreen(
                        file: file,
                        initialTab: 1,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showCreateTagDialog() async {
    final TextEditingController tagController = TextEditingController();

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(AppLocalizations.of(context)!.newTagTitle),
          content: TextField(
            controller: tagController,
            decoration: InputDecoration(
              hintText: AppLocalizations.of(context)!.enterTagName,
              prefixIcon: const Icon(PhosphorIconsLight.hash),
            ),
            autofocus: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (value) {
              if (value.trim().isNotEmpty) {
                Navigator.of(context).pop();
                _createNewTag(value.trim());
              }
            },
          ),
          actions: <Widget>[
            TextButton(
              child: Text(AppLocalizations.of(context)!.cancel),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text(AppLocalizations.of(context)!.create),
              onPressed: () {
                final tagName = tagController.text.trim();
                if (tagName.isNotEmpty) {
                  Navigator.of(context).pop();
                  _createNewTag(tagName);
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _createNewTag(String tagName) async {
    if (_allTags.contains(tagName)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(AppLocalizations.of(context)!.tagAlreadyExists(tagName)),
        ),
      );
      return;
    }

    _standaloneCreatedTags.add(tagName);

    setState(() {
      _allTags.add(tagName);
      _allTags.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      _filterTags();
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              AppLocalizations.of(context)!.tagCreatedSuccessfully(tagName)),
        ),
      );
    }
  }

  void _openContainingFolder(String folderPath) {
    if (Directory(folderPath).existsSync()) {
      try {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  '${AppLocalizations.of(context)!.openingFolder}$folderPath')),
        );

        final bool isInTabContext = context.findAncestorWidgetOfExactType<
                BlocProvider<TabManagerBloc>>() !=
            null;

        if (isInTabContext) {
          try {
            final tabManagerBloc = BlocProvider.of<TabManagerBloc>(context);

            final existingTab = tabManagerBloc.state.tabs.firstWhere(
              (tab) => tab.path == folderPath,
              orElse: () => TabData(id: '', name: '', path: ''),
            );

            if (existingTab.id.isNotEmpty) {
              tabManagerBloc.add(SwitchToTab(existingTab.id));
            } else {
              final folderName = pathlib.basename(folderPath);
              tabManagerBloc.add(
                AddTab(
                  path: folderPath,
                  name: folderName,
                  switchToTab: true,
                ),
              );
            }
          } catch (e) {}
        } else {
          RouteUtils.safePopDialog(context);
        }
      } catch (e) {}
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                '${AppLocalizations.of(context)!.folderNotFound}$folderPath')),
      );
    }
  }
}




