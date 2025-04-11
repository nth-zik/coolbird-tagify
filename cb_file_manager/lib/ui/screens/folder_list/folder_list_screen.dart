import 'dart:io';

import 'package:cb_file_manager/helpers/io_extensions.dart';
import 'package:cb_file_manager/helpers/batch_tag_manager.dart';
import 'package:cb_file_manager/ui/screens/folder_list/file_details_screen.dart';
import 'package:cb_file_manager/ui/screens/media_gallery/image_gallery_screen.dart';
import 'package:cb_file_manager/ui/screens/media_gallery/video_gallery_screen.dart';
import 'package:cb_file_manager/ui/utils/base_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as pathlib;
import 'package:cb_file_manager/helpers/user_preferences.dart';
import 'package:cb_file_manager/main.dart'; // Import for goHome function

import 'folder_list_bloc.dart';
import 'folder_list_event.dart';
import 'folder_list_state.dart';

class FolderListScreen extends StatefulWidget {
  final String path;

  const FolderListScreen({Key? key, required this.path}) : super(key: key);

  @override
  State<FolderListScreen> createState() => _FolderListScreenState();
}

class _FolderListScreenState extends State<FolderListScreen> {
  late TextEditingController _searchController;
  late TextEditingController _tagController;
  String? _currentFilter;
  String? _currentSearchTag;
  bool _isSelectionMode = false;
  final Set<String> _selectedFilePaths = {};

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
    _searchController = TextEditingController();
    _tagController = TextEditingController();

    // Initialize the bloc
    _folderListBloc = FolderListBloc();
    _folderListBloc.add(FolderListLoad(widget.path));

    _saveLastAccessedFolder();

    // Load preferences
    _loadPreferences();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        if (!mounted) {
          final prefs = UserPreferences();
          await prefs.init();
          final lastFolder = prefs.getLastAccessedFolder();

          if (lastFolder == widget.path) {
            await prefs.clearLastAccessedFolder();
          }
        }
      } catch (e) {
        print('Error in dispose cleanup: $e');
      }
    });

    _searchController.dispose();
    _tagController.dispose();
    _folderListBloc.close();
    super.dispose();
  }

  Future<void> _saveLastAccessedFolder() async {
    try {
      final directory = Directory(widget.path);
      if (await directory.exists()) {
        final UserPreferences prefs = UserPreferences();
        await prefs.init();
        await prefs.setLastAccessedFolder(widget.path);
      } else {
        print(
            'Cannot save last folder: directory does not exist: ${widget.path}');
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

  void _changeZoomLevel(int delta) {
    final currentZoom = _gridZoomLevel;
    final newZoom = (currentZoom + delta).clamp(
      UserPreferences.minGridZoomLevel,
      UserPreferences.maxGridZoomLevel,
    );

    if (newZoom != currentZoom) {
      _folderListBloc.add(SetGridZoom(newZoom));
      _saveGridZoomSetting(newZoom);
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

  @override
  Widget build(BuildContext context) {
    return BlocProvider<FolderListBloc>.value(
      value: _folderListBloc,
      child: BlocBuilder<FolderListBloc, FolderListState>(
        builder: (context, state) {
          _currentSearchTag = state.currentSearchTag;
          _currentFilter = state.currentFilter;

          return BaseScreen(
            title: pathlib.basename(widget.path),
            actions: _isSelectionMode
                ? [
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: _toggleSelectionMode,
                      tooltip: 'Cancel Selection',
                    ),
                    IconButton(
                      icon: const Icon(Icons.select_all),
                      onPressed: () {
                        setState(() {
                          _selectedFilePaths.clear();
                          for (var file in state.files) {
                            if (file is File) {
                              _selectedFilePaths.add(file.path);
                            }
                          }
                        });
                      },
                      tooltip: 'Select All',
                    ),
                    IconButton(
                      icon: const Icon(Icons.label),
                      onPressed: () {
                        if (_selectedFilePaths.isNotEmpty) {
                          _showAddTagToFilesDialog(context);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please select files first'),
                            ),
                          );
                        }
                      },
                      tooltip: 'Add Tag to Selected',
                    ),
                  ]
                : [
                    if (state.viewMode == ViewMode.grid)
                      IconButton(
                        icon: const Icon(Icons.zoom_out),
                        tooltip: 'More columns (smaller items)',
                        onPressed: state.gridZoomLevel <
                                UserPreferences.maxGridZoomLevel
                            ? () => _changeZoomLevel(1)
                            : null,
                      ),
                    if (state.viewMode == ViewMode.grid)
                      IconButton(
                        icon: const Icon(Icons.zoom_in),
                        tooltip: 'Fewer columns (larger items)',
                        onPressed: state.gridZoomLevel >
                                UserPreferences.minGridZoomLevel
                            ? () => _changeZoomLevel(-1)
                            : null,
                      ),
                    IconButton(
                      icon: Icon(state.viewMode == ViewMode.list
                          ? Icons.grid_view
                          : Icons.list),
                      tooltip: state.viewMode == ViewMode.list
                          ? 'Switch to Grid View'
                          : 'Switch to List View',
                      onPressed: () {
                        final newMode = state.viewMode == ViewMode.list
                            ? ViewMode.grid
                            : ViewMode.list;
                        context
                            .read<FolderListBloc>()
                            .add(SetViewMode(newMode));
                        _saveViewModeSetting(newMode);
                      },
                    ),
                    PopupMenuButton<SortOption>(
                      icon: const Icon(Icons.sort),
                      tooltip: 'Sort files',
                      onSelected: (SortOption option) {
                        context
                            .read<FolderListBloc>()
                            .add(SetSortOption(option));
                        _saveSortSetting(option);
                      },
                      itemBuilder: (BuildContext context) => [
                        const PopupMenuItem(
                          value: SortOption.nameAsc,
                          child: ListTile(
                            leading: Icon(Icons.arrow_upward),
                            title: Text('Name (A to Z)'),
                            dense: true,
                          ),
                        ),
                        const PopupMenuItem(
                          value: SortOption.nameDesc,
                          child: ListTile(
                            leading: Icon(Icons.arrow_downward),
                            title: Text('Name (Z to A)'),
                            dense: true,
                          ),
                        ),
                        const PopupMenuItem(
                          value: SortOption.dateAsc,
                          child: ListTile(
                            leading: Icon(Icons.arrow_upward),
                            title: Text('Date (Oldest first)'),
                            dense: true,
                          ),
                        ),
                        const PopupMenuItem(
                          value: SortOption.dateDesc,
                          child: ListTile(
                            leading: Icon(Icons.arrow_downward),
                            title: Text('Date (Newest first)'),
                            dense: true,
                          ),
                        ),
                        const PopupMenuItem(
                          value: SortOption.sizeAsc,
                          child: ListTile(
                            leading: Icon(Icons.arrow_upward),
                            title: Text('Size (Smallest first)'),
                            dense: true,
                          ),
                        ),
                        const PopupMenuItem(
                          value: SortOption.sizeDesc,
                          child: ListTile(
                            leading: Icon(Icons.arrow_downward),
                            title: Text('Size (Largest first)'),
                            dense: true,
                          ),
                        ),
                        const PopupMenuItem(
                          value: SortOption.typeAsc,
                          child: ListTile(
                            leading: Icon(Icons.sort),
                            title: Text('Type'),
                            dense: true,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.photo_library),
                      tooltip: 'Image Gallery',
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ImageGalleryScreen(
                              path: widget.path,
                              recursive: true,
                            ),
                          ),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.video_library),
                      tooltip: 'Video Gallery',
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => VideoGalleryScreen(
                              path: widget.path,
                              recursive: true,
                            ),
                          ),
                        );
                      },
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.filter_list),
                      onSelected: (String value) {
                        setState(() {
                          _currentFilter = value;
                          context
                              .read<FolderListBloc>()
                              .add(FolderListFilter(value));
                        });
                      },
                      itemBuilder: (BuildContext context) => [
                        const PopupMenuItem(
                          value: 'image',
                          child: Text('Images'),
                        ),
                        const PopupMenuItem(
                          value: 'video',
                          child: Text('Videos'),
                        ),
                        const PopupMenuItem(
                          value: 'audio',
                          child: Text('Audio'),
                        ),
                        const PopupMenuItem(
                          value: 'document',
                          child: Text('Documents'),
                        ),
                        const PopupMenuItem(
                          value: '',
                          child: Text('Clear Filter'),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.search),
                      tooltip: 'Search files',
                      onPressed: () {
                        _showEnhancedSearchDialog(context);
                      },
                    ),
                  ],
            body: _buildBody(context, state),
            floatingActionButton: _isSelectionMode
                ? FloatingActionButton(
                    onPressed: () {
                      if (_selectedFilePaths.isNotEmpty) {
                        _showAddTagToFilesDialog(context);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please select files first'),
                          ),
                        );
                      }
                    },
                    child: const Icon(Icons.label),
                  )
                : FloatingActionButton(
                    onPressed: _toggleSelectionMode,
                    child: const Icon(Icons.checklist),
                  ),
          );
        },
      ),
    );
  }

  void _showAddTagToFilesDialog(BuildContext context) {
    _tagController.clear();
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Add Tag to ${_selectedFilePaths.length} Files'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _tagController,
                decoration: const InputDecoration(
                  labelText: 'Tag',
                  hintText: 'Enter a new tag',
                ),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              const Text(
                'This will add the tag to all selected files.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (_tagController.text.isNotEmpty) {
                  Navigator.of(context).pop();
                  _applyTagToSelectedFiles(_tagController.text);
                }
              },
              child: const Text('Add to All'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _applyTagToSelectedFiles(String tag) async {
    if (_selectedFilePaths.isEmpty) return;

    // Show progress indicator
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Adding tag to selected files...'),
        duration: Duration(seconds: 1),
      ),
    );

    // Use BatchTagManager to apply tag to all selected files
    final results =
        await BatchTagManager.addTagToFiles(_selectedFilePaths.toList(), tag);

    // Count failures
    final failures = results.values.where((success) => !success).length;

    // Refresh file list
    _folderListBloc.add(FolderListLoad(widget.path));

    // Show result
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          failures > 0
              ? 'Tag added to ${_selectedFilePaths.length - failures} files with $failures failures'
              : 'Tag added to all ${_selectedFilePaths.length} files successfully',
        ),
      ),
    );
  }

  void _showEnhancedSearchDialog(BuildContext context) {
    // Tab controller for search options
    final tabController = PageController();
    final searchModes = ['Search by Name', 'Search by Tag', 'Media Search'];
    int selectedTabIndex = 0;

    // Controllers
    final fileNameController = TextEditingController();
    final tagController = TextEditingController();

    // Recursive search option (for file name search)
    bool recursiveSearch = false;

    // Local variable for global search toggle instead of using class-level variable
    bool localIsGlobalSearch = isGlobalSearch;

    // Media search options
    MediaSearchType selectedMediaType = MediaSearchType.images;

    // Auto-complete suggestions for tags
    List<String> tagSuggestions = [];
    bool isTagTabActive = false;

    // Store the current state here to avoid Provider dependency
    final currentState = context.read<FolderListBloc>().state;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              title: Row(
                children: [
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (int i = 0; i < searchModes.length; i++)
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 4.0),
                            child: ChoiceChip(
                              label: Text(searchModes[i],
                                  style: TextStyle(fontSize: 12)),
                              selected: selectedTabIndex == i,
                              onSelected: (selected) {
                                if (selected) {
                                  setState(() {
                                    selectedTabIndex = i;
                                    // Set flag when tag tab is active
                                    isTagTabActive = (i == 1);

                                    // Update tag suggestions if we're switching to tag tab
                                    if (isTagTabActive) {
                                      if (tagController.text.isNotEmpty) {
                                        tagSuggestions =
                                            currentState.getTagSuggestions(
                                                tagController.text);
                                      } else {
                                        tagSuggestions =
                                            currentState.allTags.toList();
                                      }
                                    }
                                  });
                                  tabController.animateToPage(
                                    i,
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                  );
                                }
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              content: Container(
                width: double.maxFinite,
                height: 250, // Fixed height for the dialog content
                child: PageView(
                  controller: tabController,
                  physics:
                      const NeverScrollableScrollPhysics(), // Disable swiping
                  onPageChanged: (index) {
                    setState(() {
                      selectedTabIndex = index;
                      // Set flag when tag tab is active
                      isTagTabActive = (index == 1);

                      // Update tag suggestions if we're switching to tag tab
                      if (isTagTabActive) {
                        if (tagController.text.isNotEmpty) {
                          tagSuggestions = currentState
                              .getTagSuggestions(tagController.text);
                        } else {
                          tagSuggestions = currentState.allTags.toList();
                        }
                      }
                    });
                  },
                  children: [
                    // File name search page
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: fileNameController,
                          decoration: const InputDecoration(
                            labelText: 'File Name',
                            hintText: 'Enter file name to search',
                            prefixIcon: Icon(Icons.search),
                          ),
                          autofocus: selectedTabIndex == 0,
                          textInputAction: TextInputAction.search,
                          onSubmitted: (_) {
                            if (fileNameController.text.isNotEmpty) {
                              Navigator.of(context).pop();
                              _folderListBloc.add(SearchByFileName(
                                fileNameController.text,
                                recursive: recursiveSearch,
                              ));
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        CheckboxListTile(
                          title: const Text('Include subfolders'),
                          value: recursiveSearch,
                          onChanged: (bool? value) {
                            setState(() {
                              recursiveSearch = value ?? false;
                            });
                          },
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          dense: true,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'This will search for files where the name contains the text you enter.',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),

                    // Tag search page - using pre-loaded tag suggestions
                    Visibility(
                      visible: isTagTabActive,
                      maintainState: true,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Stack(
                            children: [
                              TextField(
                                controller: tagController,
                                decoration: const InputDecoration(
                                  labelText: 'Tag',
                                  hintText: 'Enter a tag to search for',
                                  prefixIcon: Icon(Icons.label),
                                ),
                                autofocus: selectedTabIndex == 1,
                                textInputAction: TextInputAction.search,
                                onSubmitted: (_) {
                                  if (tagController.text.isNotEmpty) {
                                    Navigator.of(context).pop();
                                    if (localIsGlobalSearch) {
                                      _folderListBloc.add(SearchByTagGlobally(
                                          tagController.text));
                                    } else {
                                      _folderListBloc
                                          .add(SearchByTag(tagController.text));
                                    }
                                  }
                                },
                                onChanged: (value) {
                                  // Update tag suggestions when text changes
                                  if (isTagTabActive) {
                                    setState(() {
                                      if (value.isNotEmpty) {
                                        tagSuggestions = currentState
                                            .getTagSuggestions(value);
                                      } else {
                                        tagSuggestions =
                                            currentState.allTags.toList();
                                      }
                                    });
                                  }
                                },
                              ),
                              // Clear button
                              if (tagController.text.isNotEmpty)
                                Positioned(
                                  right: 0,
                                  top: 0,
                                  child: IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      setState(() {
                                        tagController.clear();
                                        tagSuggestions =
                                            currentState.allTags.toList();
                                      });
                                    },
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // Add global search toggle - using local state variable
                          CheckboxListTile(
                            title: const Text('Search tags globally',
                                style: TextStyle(fontSize: 14)),
                            subtitle: const Text(
                              'Find files with this tag across all directories',
                              style: TextStyle(fontSize: 12),
                            ),
                            value: localIsGlobalSearch,
                            onChanged: (value) {
                              setState(() {
                                localIsGlobalSearch = value ?? false;
                                // Update the class variable when the dialog is closed
                                isGlobalSearch = localIsGlobalSearch;
                              });
                            },
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: tagSuggestions.isEmpty
                                ? const Center(
                                    child: Text('No matching tags'),
                                  )
                                : SingleChildScrollView(
                                    child: Wrap(
                                      spacing: 8.0,
                                      runSpacing: 8.0,
                                      children: tagSuggestions.map((tag) {
                                        return ActionChip(
                                          label: Text(tag),
                                          onPressed: () {
                                            Navigator.of(context).pop();
                                            // Update the class variable before closing
                                            isGlobalSearch =
                                                localIsGlobalSearch;
                                            if (localIsGlobalSearch) {
                                              _folderListBloc.add(
                                                  SearchByTagGlobally(tag));
                                            } else {
                                              _folderListBloc
                                                  .add(SearchByTag(tag));
                                            }
                                          },
                                        );
                                      }).toList(),
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),

                    // Media Search page
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Find media files in this folder',
                          style: TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 16),
                        ListTile(
                          title: const Text('Images'),
                          leading: Radio<MediaSearchType>(
                            value: MediaSearchType.images,
                            groupValue: selectedMediaType,
                            onChanged: (MediaSearchType? value) {
                              setState(() {
                                selectedMediaType = value!;
                              });
                            },
                          ),
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        ListTile(
                          title: const Text('Videos'),
                          leading: Radio<MediaSearchType>(
                            value: MediaSearchType.videos,
                            groupValue: selectedMediaType,
                            onChanged: (MediaSearchType? value) {
                              setState(() {
                                selectedMediaType = value!;
                              });
                            },
                          ),
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        ListTile(
                          title: const Text('Audio'),
                          leading: Radio<MediaSearchType>(
                            value: MediaSearchType.audio,
                            groupValue: selectedMediaType,
                            onChanged: (MediaSearchType? value) {
                              setState(() {
                                selectedMediaType = value!;
                              });
                            },
                          ),
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        CheckboxListTile(
                          title: const Text('Include subfolders'),
                          value: recursiveSearch,
                          onChanged: (bool? value) {
                            setState(() {
                              recursiveSearch = value ?? false;
                            });
                          },
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          dense: true,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    // Update the class variable before closing
                    isGlobalSearch = localIsGlobalSearch;
                    Navigator.of(context).pop();

                    switch (selectedTabIndex) {
                      case 0: // File name search
                        if (fileNameController.text.isNotEmpty) {
                          _folderListBloc.add(SearchByFileName(
                            fileNameController.text,
                            recursive: recursiveSearch,
                          ));
                        }
                        break;
                      case 1: // Tag search
                        if (tagController.text.isNotEmpty) {
                          if (localIsGlobalSearch) {
                            _folderListBloc
                                .add(SearchByTagGlobally(tagController.text));
                          } else {
                            _folderListBloc
                                .add(SearchByTag(tagController.text));
                          }
                        }
                        break;
                      case 2: // Media search
                        _folderListBloc.add(SearchMediaFiles(
                          selectedMediaType,
                          recursive: recursiveSearch,
                        ));
                        break;
                    }
                  },
                  child: const Text('Search'),
                ),
              ],
            );
          },
        );
      },
    ).then((_) {
      // Clean up controllers when dialog is dismissed
      fileNameController.dispose();
      tagController.dispose();
      tabController.dispose();
    });
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
                _folderListBloc.add(FolderListLoad(widget.path));
              },
              child: const Text('Try Again'),
            ),
          ],
        ),
      );
    }

    // Show search results if searching
    if (_currentSearchTag != null && state.searchResults.isNotEmpty) {
      return _buildSearchResultsList(context, state);
    }

    // Show filtered files if a filter is active
    if (_currentFilter != null &&
        _currentFilter!.isNotEmpty &&
        state.filteredFiles.isNotEmpty) {
      return _buildFileList(context, state.filteredFiles, state);
    }

    // Empty directory check
    if (state.folders.isEmpty && state.files.isEmpty) {
      return const Center(
        child: Text('Empty folder', style: TextStyle(fontSize: 18)),
      );
    }

    // Default view - folders and files
    return RefreshIndicator(
      onRefresh: () async {
        _folderListBloc.add(FolderListLoad(widget.path));
      },
      child: CustomScrollView(
        slivers: [
          // Directory path breadcrumb
          SliverToBoxAdapter(
            child: _buildBreadcrumb(context, widget.path),
          ),

          // Folders section
          SliverToBoxAdapter(
            child: state.folders.isNotEmpty
                ? const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('Folders',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                  )
                : const SizedBox.shrink(),
          ),

          // Folder items
          if (state.folders.isNotEmpty)
            state.viewMode == ViewMode.list
                ? SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final folder = state.folders[index];
                        if (folder is Directory) {
                          return _buildFolderItem(context, folder);
                        }
                        return const SizedBox.shrink();
                      },
                      childCount: state.folders.length,
                    ),
                  )
                : SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: state.gridZoomLevel,
                      childAspectRatio: 0.8,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final folder = state.folders[index];
                        if (folder is Directory) {
                          return _buildFolderGridItem(context, folder);
                        }
                        return const SizedBox.shrink();
                      },
                      childCount: state.folders.length,
                    ),
                  ),

          // Files section header
          SliverToBoxAdapter(
            child: state.files.isNotEmpty
                ? const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('Files',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                  )
                : const SizedBox.shrink(),
          ),

          // File items
          if (state.files.isNotEmpty)
            state.viewMode == ViewMode.list
                ? SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final file = state.files[index];
                        if (file is File) {
                          return _buildFileItem(context, file, state);
                        }
                        return const SizedBox.shrink();
                      },
                      childCount: state.files.length,
                    ),
                  )
                : SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: state.gridZoomLevel,
                      childAspectRatio: 0.75,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final file = state.files[index];
                        if (file is File) {
                          return _buildFileGridItem(context, file, state);
                        }
                        return const SizedBox.shrink();
                      },
                      childCount: state.files.length,
                    ),
                  ),
        ],
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
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              TextButton.icon(
                icon: const Icon(Icons.clear),
                label: const Text('Clear'),
                onPressed: () {
                  _folderListBloc.add(FolderListLoad(widget.path));
                },
              ),
            ],
          ),
        ),
        state.searchResults.isEmpty
            ? Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.search_off,
                          size: 48, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(
                        'No matching files found',
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              )
            : Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${state.searchResults.length} results found',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.file_download),
                      label: const Text('Export Results'),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Export feature not implemented'),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
        Expanded(
          child: _buildFileList(context, state.searchResults, state),
        ),
      ],
    );
  }

  Widget _buildFileList(BuildContext context, List<FileSystemEntity> files,
      FolderListState state) {
    // Choose between list and grid views based on current viewMode
    return state.viewMode == ViewMode.list
        ? ListView.builder(
            itemCount: files.length,
            itemBuilder: (context, index) {
              final file = files[index];
              if (file is File) {
                return _buildFileItem(context, file, state);
              }
              return const SizedBox.shrink();
            },
          )
        : GridView.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: state.gridZoomLevel,
              childAspectRatio: 0.75,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            padding: const EdgeInsets.all(8),
            itemCount: files.length,
            itemBuilder: (context, index) {
              final file = files[index];
              if (file is File) {
                return _buildFileGridItem(context, file, state);
              }
              return const SizedBox.shrink();
            },
          );
  }

  Widget _buildBreadcrumb(BuildContext context, String path) {
    List<String> pathParts = path.split('/');

    // Remove empty parts
    pathParts = pathParts.where((part) => part.isNotEmpty).toList();

    if (pathParts.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Text('Root', style: TextStyle(fontSize: 14, color: Colors.grey)),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12.0),
      color: Colors.grey[100],
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (int i = 0; i < pathParts.length; i++)
              Row(
                children: [
                  if (i > 0)
                    const Icon(Icons.chevron_right,
                        size: 18, color: Colors.grey),
                  InkWell(
                    onTap: () {
                      // Navigate to this level
                      String partialPath = '/';
                      for (int j = 0; j <= i; j++) {
                        partialPath += '${pathParts[j]}/';
                      }

                      if (partialPath != widget.path) {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                FolderListScreen(path: partialPath),
                          ),
                        );
                      }
                    },
                    child: Text(
                      pathParts[i],
                      style: TextStyle(
                        color: i == pathParts.length - 1
                            ? Colors.black
                            : Colors.blue,
                        fontWeight: i == pathParts.length - 1
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFolderItem(BuildContext context, Directory folder) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: ListTile(
        leading: const Icon(Icons.folder, color: Colors.amber),
        title: Text(folder.basename()),
        subtitle: FutureBuilder<FileStat>(
          future: folder.stat(),
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              return Text(
                  'Modified: ${snapshot.data!.modified.toString().split('.')[0]}');
            }
            return const Text('Loading...');
          },
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => FolderListScreen(path: folder.path),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFolderGridItem(BuildContext context, Directory folder) {
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => FolderListScreen(path: folder.path),
            ),
          );
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.folder,
              size: 48,
              color: Colors.amber,
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(
                folder.basename(),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 4),
            FutureBuilder<FileStat>(
              future: folder.stat(),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  final date = snapshot.data!.modified;
                  return Text(
                    '${date.month}/${date.day}/${date.year}',
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  );
                }
                return const Text('Loading...', style: TextStyle(fontSize: 10));
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileItem(
      BuildContext context, File file, FolderListState state) {
    final extension = file.extension().toLowerCase();
    IconData icon;
    Color? iconColor;

    // Determine file type and icon
    if (['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'].contains(extension)) {
      icon = Icons.image;
      iconColor = Colors.blue;
    } else if (['mp4', 'mov', 'avi', 'mkv', 'flv', 'wmv'].contains(extension)) {
      icon = Icons.videocam;
      iconColor = Colors.red;
    } else if (['mp3', 'wav', 'ogg', 'm4a', 'aac', 'flac']
        .contains(extension)) {
      icon = Icons.audiotrack;
      iconColor = Colors.purple;
    } else if (['pdf', 'doc', 'docx', 'txt', 'xls', 'xlsx', 'ppt', 'pptx']
        .contains(extension)) {
      icon = Icons.description;
      iconColor = Colors.indigo;
    } else {
      icon = Icons.insert_drive_file;
      iconColor = Colors.grey;
    }

    // Get tags for this file
    final List<String> fileTags = state.getTagsForFile(file.path);
    final bool isSelected = _selectedFilePaths.contains(file.path);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      color: isSelected ? Colors.blue.shade50 : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: _isSelectionMode
                ? Checkbox(
                    value: isSelected,
                    onChanged: (bool? value) {
                      _toggleFileSelection(file.path);
                    },
                  )
                : Icon(icon, color: iconColor),
            title: Text(file.basename()),
            subtitle: FutureBuilder<FileStat>(
              future: file.stat(),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  String sizeText = _formatFileSize(snapshot.data!.size);
                  return Text(
                      '${snapshot.data!.modified.toString().split('.')[0]} • $sizeText');
                }
                return const Text('Loading...');
              },
            ),
            onTap: () {
              if (_isSelectionMode) {
                _toggleFileSelection(file.path);
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => FileDetailsScreen(file: file),
                  ),
                );
              }
            },
            trailing: _isSelectionMode
                ? null
                : PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    onSelected: (String value) {
                      if (value == 'tag') {
                        _showAddTagToFileDialog(context, file.path);
                      } else if (value == 'delete_tag') {
                        _showDeleteTagDialog(context, file.path,
                            state.getTagsForFile(file.path));
                      }
                    },
                    itemBuilder: (BuildContext context) => [
                      const PopupMenuItem(
                        value: 'tag',
                        child: Text('Add Tag'),
                      ),
                      if (fileTags.isNotEmpty)
                        const PopupMenuItem(
                          value: 'delete_tag',
                          child: Text('Remove Tag'),
                        ),
                    ],
                  ),
          ),
          // Show tags if any
          if (fileTags.isNotEmpty)
            Padding(
              padding:
                  const EdgeInsets.only(left: 16.0, bottom: 8.0, right: 16.0),
              child: Wrap(
                spacing: 8.0,
                children: fileTags.map((tag) {
                  return Chip(
                    label: Text(tag),
                    backgroundColor: Colors.green[100],
                    deleteIcon: const Icon(Icons.close, size: 18),
                    onDeleted: () {
                      _folderListBloc.add(RemoveTagFromFile(file.path, tag));
                    },
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFileGridItem(
      BuildContext context, File file, FolderListState state) {
    final extension = file.extension().toLowerCase();
    IconData icon;
    Color? iconColor;
    bool isPreviewable = false;

    // Determine file type and icon
    if (['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'].contains(extension)) {
      icon = Icons.image;
      iconColor = Colors.blue;
      isPreviewable = true;
    } else if (['mp4', 'mov', 'avi', 'mkv', 'flv', 'wmv'].contains(extension)) {
      icon = Icons.videocam;
      iconColor = Colors.red;
    } else if (['mp3', 'wav', 'ogg', 'm4a', 'aac', 'flac']
        .contains(extension)) {
      icon = Icons.audiotrack;
      iconColor = Colors.purple;
    } else if (['pdf', 'doc', 'docx', 'txt', 'xls', 'xlsx', 'ppt', 'pptx']
        .contains(extension)) {
      icon = Icons.description;
      iconColor = Colors.indigo;
    } else {
      icon = Icons.insert_drive_file;
      iconColor = Colors.grey;
    }

    // Get tags for this file
    final List<String> fileTags = state.getTagsForFile(file.path);
    final bool isSelected = _selectedFilePaths.contains(file.path);

    // Build a card with thumbnail or icon
    return Card(
      color: isSelected ? Colors.blue.shade50 : null,
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      child: InkWell(
        onTap: () {
          if (_isSelectionMode) {
            _toggleFileSelection(file.path);
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => FileDetailsScreen(file: file),
              ),
            );
          }
        },
        onLongPress: () {
          if (!_isSelectionMode) {
            _toggleSelectionMode();
            _toggleFileSelection(file.path);
          }
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // File preview or icon
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Show image preview if it's an image file, otherwise show icon
                  isPreviewable
                      ? _buildThumbnail(file)
                      : Center(
                          child: Icon(
                            icon,
                            size: 48,
                            color: iconColor,
                          ),
                        ),
                  // Selection indicator overlay
                  if (_isSelectionMode)
                    Positioned(
                      right: 6,
                      top: 6,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.blue : Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.grey.shade400),
                        ),
                        child: Center(
                          child: isSelected
                              ? Icon(Icons.check, size: 16, color: Colors.white)
                              : null,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // File name and tags
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    file.basename(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  FutureBuilder<FileStat>(
                    future: file.stat(),
                    builder: (context, snapshot) {
                      if (snapshot.hasData) {
                        return Text(
                          _formatFileSize(snapshot.data!.size),
                          style: const TextStyle(fontSize: 10),
                        );
                      }
                      return const Text('Loading...',
                          style: TextStyle(fontSize: 10));
                    },
                  ),
                  // Tag indicators
                  if (fileTags.isNotEmpty)
                    Row(
                      children: [
                        Icon(Icons.label, size: 12, color: Colors.green[800]),
                        const SizedBox(width: 4),
                        Text(
                          '${fileTags.length} tags',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.green[800],
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnail(File file) {
    return Hero(
      tag: file.path,
      child: Image.file(
        file,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Center(
            child: Icon(
              Icons.broken_image,
              size: 48,
              color: Colors.grey[400],
            ),
          );
        },
      ),
    );
  }

  String _formatFileSize(int size) {
    if (size < 1024) {
      return '$size B';
    } else if (size < 1024 * 1024) {
      return '${(size / 1024).toStringAsFixed(1)} KB';
    } else if (size < 1024 * 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }

  void _showAddTagToFileDialog(BuildContext context, String filePath) {
    _tagController.clear();
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Add Tag to File'),
          content: TextField(
            controller: _tagController,
            decoration: const InputDecoration(
              labelText: 'Tag',
              hintText: 'Enter a new tag',
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (_tagController.text.isNotEmpty) {
                  Navigator.of(context).pop();
                  _folderListBloc.add(
                    AddTagToFile(filePath, _tagController.text),
                  );
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteTagDialog(
      BuildContext context, String filePath, List<String> tags) {
    if (tags.isEmpty) return;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Remove Tag'),
          content: Container(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Select a tag to remove:'),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8.0,
                  runSpacing: 4.0,
                  children: tags.map((tag) {
                    return ActionChip(
                      label: Text(tag),
                      onPressed: () {
                        Navigator.of(context).pop();
                        _folderListBloc.add(
                          RemoveTagFromFile(filePath, tag),
                        );
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }
}
