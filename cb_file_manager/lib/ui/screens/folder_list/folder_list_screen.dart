import 'dart:io';

import 'package:cb_file_manager/helpers/io_extensions.dart';
import 'package:cb_file_manager/helpers/batch_tag_manager.dart';
import 'package:cb_file_manager/ui/screens/folder_list/file_details_screen.dart';
import 'package:cb_file_manager/ui/screens/media_gallery/image_gallery_screen.dart';
import 'package:cb_file_manager/ui/screens/media_gallery/video_gallery_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as pathlib;

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

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _tagController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      // Clear selections when exiting selection mode
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
    return BlocProvider(
      create: (context) => FolderListBloc()..add(FolderListLoad(widget.path)),
      child: BlocBuilder<FolderListBloc, FolderListState>(
        builder: (context, state) {
          return Scaffold(
            appBar: AppBar(
              title: Text(pathlib.basename(widget.path)),
              leading: _isSelectionMode
                  ? IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: _toggleSelectionMode,
                    )
                  : null,
              actions: _isSelectionMode
                  ? [
                      // Selection mode actions
                      IconButton(
                        icon: const Icon(Icons.select_all),
                        onPressed: () {
                          // Select all files
                          setState(() {
                            _selectedFilePaths.clear();
                            for (var file in state.files) {
                              if (file is File) {
                                _selectedFilePaths.add(file.path);
                              }
                            }
                          });
                        },
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
                      ),
                    ]
                  : [
                      // Gallery buttons
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
                      // Normal mode actions
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
                        onPressed: () {
                          _showSearchDialog(context);
                        },
                      ),
                    ],
            ),
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
                context.read<FolderListBloc>().add(FolderListLoad(widget.path));
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
        context.read<FolderListBloc>().add(FolderListLoad(widget.path));
      },
      child: CustomScrollView(
        slivers: [
          // Directory path breadcrumb
          SliverToBoxAdapter(
            child: _buildBreadcrumb(context, widget.path),
          ),

          // Folders first
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
          if (state.folders.isNotEmpty)
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final folder = state.folders[index];
                  if (folder is Directory) {
                    return _buildFolderItem(context, folder);
                  }
                  return const SizedBox.shrink(); // Skip non-directory items
                },
                childCount: state.folders.length,
              ),
            ),

          // Files section
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
          if (state.files.isNotEmpty)
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final file = state.files[index];
                  if (file is File) {
                    return _buildFileItem(context, file, state);
                  }
                  return const SizedBox.shrink(); // Skip non-file items
                },
                childCount: state.files.length,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchResultsList(BuildContext context, FolderListState state) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Text(
                'Search results for tag: $_currentSearchTag',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  setState(() {
                    _currentSearchTag = null;
                  });
                  context
                      .read<FolderListBloc>()
                      .add(FolderListLoad(widget.path));
                },
                child: const Text('Clear'),
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
    return ListView.builder(
      itemCount: files.length,
      itemBuilder: (context, index) {
        final file = files[index];
        if (file is File) {
          return _buildFileItem(context, file, state);
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
                      context
                          .read<FolderListBloc>()
                          .add(RemoveTagFromFile(file.path, tag));
                    },
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  String _formatFileSize(int size) {
    if (size < 1024) {
      return '${size} B';
    } else if (size < 1024 * 1024) {
      return '${(size / 1024).toStringAsFixed(1)} KB';
    } else if (size < 1024 * 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }

  void _showSearchDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return BlocBuilder<FolderListBloc, FolderListState>(
          builder: (context, state) {
            // Get all unique tags
            final Set<String> allTags = state.allTags;

            return AlertDialog(
              title: const Text('Search by Tag'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        labelText: 'Tag',
                        hintText: 'Enter a tag to search for',
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (allTags.isNotEmpty)
                      Container(
                        height: 150,
                        child: ListView(
                          children: [
                            const Text('Available Tags:',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8.0,
                              runSpacing: 4.0,
                              children: allTags.map((tag) {
                                return ActionChip(
                                  label: Text(tag),
                                  onPressed: () {
                                    _searchController.text = tag;
                                  },
                                );
                              }).toList(),
                            ),
                          ],
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
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (_searchController.text.isNotEmpty) {
                      setState(() {
                        _currentSearchTag = _searchController.text;
                      });
                      Navigator.of(context).pop();
                      context
                          .read<FolderListBloc>()
                          .add(SearchByTag(_searchController.text));
                    }
                  },
                  child: const Text('Search'),
                ),
              ],
            );
          },
        );
      },
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
    context.read<FolderListBloc>().add(FolderListLoad(widget.path));

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
                  context.read<FolderListBloc>().add(
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
                        context.read<FolderListBloc>().add(
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
