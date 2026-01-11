import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cb_file_manager/helpers/core/filesystem_utils.dart';
import 'package:path/path.dart' as pathlib;
import 'package:cb_file_manager/helpers/media/thumbnail_helper.dart';
import 'package:cb_file_manager/helpers/core/user_preferences.dart';
import 'package:cb_file_manager/ui/utils/base_screen.dart';
import 'package:cb_file_manager/ui/screens/folder_list/folder_list_state.dart';
import '../../components/common/shared_action_bar.dart';
import '../../components/video/video_player/video_player.dart';
import '../../components/video/video_player/video_player_app_bar.dart';
import 'package:cb_file_manager/ui/widgets/lazy_video_thumbnail.dart';
import 'package:cb_file_manager/helpers/media/video_thumbnail_helper.dart';
import 'package:cb_file_manager/helpers/ui/frame_timing_optimizer.dart';
import 'dart:async';
import 'dart:math';
import 'package:cb_file_manager/helpers/files/folder_sort_manager.dart';
import 'package:cb_file_manager/config/languages/app_localizations.dart';
import '../../tab_manager/mobile/mobile_file_actions_controller.dart';
import 'package:cb_file_manager/models/objectbox/video_library.dart';
import 'package:cb_file_manager/services/video_library_service.dart';
import 'package:cb_file_manager/helpers/tags/tag_manager.dart';
import 'package:cb_file_manager/ui/screens/folder_list/components/file_grid_item.dart';
import 'widgets/video_tag_filter_bar.dart';

class VideoGalleryScreen extends StatefulWidget {
  final String path;
  final bool recursive;
  final VideoLibrary? library;

  const VideoGalleryScreen({
    Key? key,
    required this.path,
    this.recursive = true,
    this.library,
  }) : super(key: key);

  @override
  State<VideoGalleryScreen> createState() => _VideoGalleryScreenState();
}

class _VideoGalleryScreenState extends State<VideoGalleryScreen>
    with AutomaticKeepAliveClientMixin {
  late Future<List<File>> _videoFilesFuture;
  late UserPreferences _preferences;
  double _thumbnailSize = 3.0; // Default grid size (3 columns)

  // Cải thiện ScrollController với cơ chế throttle & smooth
  final ScrollController _scrollController = ScrollController();
  Timer? _scrollEndTimer;
  bool _isScrolling = false;

  bool _isLoadingThumbnails = false;
  bool _isMounted = false;
  bool _isLoadingVideos = true; // Track initial loading state

  // Sorting variables
  SortOption _currentSortOption = SortOption.nameAsc;
  List<File> _videoFiles = [];

  // View mode and selection variables
  ViewMode _viewMode = ViewMode.grid;
  bool _isSelectionMode = false;
  final Set<String> _selectedFilePaths = {};
  String? _searchQuery;

  // Tag filtering
  final Set<String> _selectedTags = {};

  // Mobile actions controller
  MobileFileActionsController? _mobileController;
  static int _controllerIdCounter = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _preferences = UserPreferences.instance;
    _isMounted = true;

    // Initialize mobile controller first
    final controllerId = 'video_gallery_${_controllerIdCounter++}';
    _mobileController = MobileFileActionsController.forTab(controllerId);

    // Register callbacks immediately (before preferences load)
    _registerMobileControllerCallbacks();

    // Load preferences and update controller state after
    _loadPreferences().then((_) {
      if (mounted) {
        _updateMobileControllerState();
      }
    });

    _loadVideos();

    // Lắng nghe sự kiện scroll để tối ưu hóa việc tải hình ảnh
    _scrollController.addListener(() {
      // Đánh dấu là đang cuộn
      if (!_isScrolling) {
        setState(() {
          _isScrolling = true;
        });
      }

      // Hủy timer hiện tại nếu có
      _scrollEndTimer?.cancel();

      // Tạo timer mới để biết khi nào cuộn kết thúc
      _scrollEndTimer = Timer(const Duration(milliseconds: 200), () {
        if (mounted) {
          setState(() {
            _isScrolling = false;
          });
        }
      });
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _scrollEndTimer?.cancel();
    _isMounted = false;
    // Cleanup controller
    if (_mobileController != null) {
      MobileFileActionsController.removeTab(_mobileController!.tabId);
    }
    super.dispose();
  }

  // Register callbacks (can be called before preferences load)
  void _registerMobileControllerCallbacks() {
    if (_mobileController == null) return;

    debugPrint('🎬 VideoGallery: Registering mobile controller callbacks');

    // Register callbacks
    _mobileController!.onSearchSubmitted = (query) {
      debugPrint('🎬 VideoGallery: Search callback received - query: "$query"');
      setState(() {
        _searchQuery = query;
        // Just update UI, filtering happens in _filteredVideos getter
      });
    };

    _mobileController!.onSortOptionSelected = (option) {
      _setSortOption(option);
    };

    _mobileController!.onViewModeToggled = (ViewMode mode) {
      setState(() {
        _viewMode = mode;
        _mobileController!.currentViewMode = mode;
      });
      _saveViewModeSetting(_viewMode);
    };

    _mobileController!.onRefresh = () {
      setState(() {
        _loadVideos();
      });
    };

    _mobileController!.onGridSizePressed = () {
      SharedActionBar.showGridSizeDialog(
        context,
        currentGridSize: _thumbnailSize.round(),
        onApply: (size) async {
          setState(() {
            _thumbnailSize = size.toDouble();
          });
          // Update controller state
          _mobileController!.currentGridSize = size;
          try {
            await _preferences.setVideoGalleryThumbnailSize(size.toDouble());
          } catch (e) {
            debugPrint('Error saving thumbnail size: $e');
          }
        },
      );
    };

    _mobileController!.onSelectionModeToggled = () {
      setState(() {
        _isSelectionMode = !_isSelectionMode;
        if (!_isSelectionMode) {
          _selectedFilePaths.clear();
        }
      });
    };
  }

  // Update controller state (called after preferences load)
  void _updateMobileControllerState() {
    if (_mobileController == null) return;

    debugPrint('🎬 VideoGallery: Updating mobile controller state');
    _mobileController!.currentSortOption = _currentSortOption;
    _mobileController!.currentViewMode = _viewMode;
    _mobileController!.currentGridSize = _thumbnailSize.round();
  }

  Future<void> _loadPreferences() async {
    await _preferences.init();
    if (mounted) {
      final thumbnailSize = await _preferences.getVideoGalleryThumbnailSize();
      final sortOption = await _preferences.getSortOption();
      final viewMode = await _preferences.getViewMode();

      setState(() {
        _thumbnailSize = thumbnailSize;
        _currentSortOption = sortOption;
        _viewMode = viewMode;
      });
    }
  }

  void _loadVideos() {
    setState(() {
      _isLoadingVideos = true;
    });

    // Load videos from library or path
    if (widget.library != null) {
      _loadVideosFromLibrary();
    } else {
      _loadVideosFromPath();
    }
  }

  Future<void> _loadVideosFromLibrary() async {
    try {
      final service = VideoLibraryService();
      
      debugPrint('VideoGallery: Loading videos from library ID: ${widget.library!.id}');
      
      // Get videos from library, optionally filtered by tags
      List<String> videoPaths;
      if (_selectedTags.isNotEmpty) {
        // Get videos matching all selected tags
        final Set<String> allVideos = {};
        for (final tag in _selectedTags) {
          final taggedVideos = await service.getVideosByTag(
            tag,
            libraryId: widget.library!.id,
          );
          if (allVideos.isEmpty) {
            allVideos.addAll(taggedVideos);
          } else {
            // Intersection: keep only videos that have all tags
            allVideos.retainWhere((path) => taggedVideos.contains(path));
          }
        }
        videoPaths = allVideos.toList();
      } else {
        // Get all videos from library
        videoPaths = await service.getLibraryFiles(widget.library!.id);
      }

      // Convert paths to File objects
      final videos = videoPaths.map((path) => File(path)).toList();

      debugPrint('VideoGallery: Loaded ${videos.length} videos from library');
      if (videos.isNotEmpty) {
        debugPrint('VideoGallery: First 3 videos: ${videos.take(3).map((v) => v.path).join(", ")}');
      }

      if (_isMounted) {
        setState(() {
          _videoFiles = videos;
          _isLoadingVideos = false;
          _sortVideoFiles();

          if (videos.isNotEmpty) {
            _isLoadingThumbnails = true;
          }
        });

        if (videos.isNotEmpty) {
          // Trigger thumbnail generation for all videos (not just first 40)
          // Use higher limit to ensure all visible videos get thumbnails
          final preloadCount = videoPaths.length > 100 ? 100 : videoPaths.length;
          final preloadPaths = videoPaths.take(preloadCount).toList();
          
          debugPrint('VideoGallery: Preloading $preloadCount thumbnails from ${videoPaths.length} total videos');
          
          // Force generate thumbnails for videos without cache
          for (final path in preloadPaths) {
            VideoThumbnailHelper.generateThumbnail(
              path,
              isPriority: false,
            ).catchError((e) {
              debugPrint('Failed to generate thumbnail for $path: $e');
              return null;
            });
          }
          
          VideoThumbnailHelper.optimizedBatchPreload(preloadPaths).then((_) {
            debugPrint('VideoGallery: Thumbnail preload complete');
            if (_isMounted) {
              setState(() {
                _isLoadingThumbnails = false;
              });
            }
          });
        }
      }
    } catch (error) {
      debugPrint('VideoGallery: Error loading videos from library: $error');
      if (_isMounted) {
        setState(() {
          _isLoadingVideos = false;
        });
        debugPrint('Error loading videos from library: $error');
      }
    }
  }

  Future<void> _loadVideosFromPath() async {
    _videoFilesFuture = getAllVideos(widget.path, recursive: widget.recursive);

    _videoFilesFuture.then((videos) async {
      if (_isMounted) {
        // Apply tag filtering if tags are selected
        List<File> filteredVideos = videos;
        if (_selectedTags.isNotEmpty) {
          // Tag filtering needs to be async, so we filter after loading
          final filtered = <File>[];
          for (final file in videos) {
            bool hasAllTags = true;
            for (final tag in _selectedTags) {
              final tags = await TagManager.getTags(file.path);
              if (!tags.contains(tag)) {
                hasAllTags = false;
                break;
              }
            }
            if (hasAllTags) {
              filtered.add(file);
            }
          }
          filteredVideos = filtered;
        }

        setState(() {
          _videoFiles = filteredVideos;
          _isLoadingVideos = false; // Mark loading as complete
          _sortVideoFiles();

          if (filteredVideos.isNotEmpty) {
            _isLoadingThumbnails = true;
          }
        });

        if (filteredVideos.isNotEmpty) {
          // Sử dụng VideoThumbnailHelper
          final videoPaths = videos.map((file) => file.path).toList();

          // Tải trước thumbnail với VideoThumbnailHelper
          VideoThumbnailHelper.optimizedBatchPreload(videoPaths).then((_) {
            if (_isMounted) {
              setState(() {
                _isLoadingThumbnails = false;
              });
            }
          });
        }
      }
    }).catchError((error) {
      if (_isMounted) {
        setState(() {
          _isLoadingVideos = false; // Mark loading as complete even on error
        });
        debugPrint('Error loading videos: $error');
      }
    });
  }

  void _sortVideoFiles() {
    switch (_currentSortOption) {
      case SortOption.nameAsc:
        _videoFiles.sort((a, b) => pathlib
            .basename(a.path)
            .toLowerCase()
            .compareTo(pathlib.basename(b.path).toLowerCase()));
        break;

      case SortOption.nameDesc:
        _videoFiles.sort((a, b) => pathlib
            .basename(b.path)
            .toLowerCase()
            .compareTo(pathlib.basename(a.path).toLowerCase()));
        break;

      case SortOption.dateAsc:
        _videoFiles.sort((a, b) {
          try {
            return a.lastModifiedSync().compareTo(b.lastModifiedSync());
          } catch (e) {
            return 0;
          }
        });
        break;

      case SortOption.dateDesc:
        _videoFiles.sort((a, b) {
          try {
            return b.lastModifiedSync().compareTo(a.lastModifiedSync());
          } catch (e) {
            return 0;
          }
        });
        break;

      case SortOption.sizeAsc:
        _videoFiles.sort((a, b) {
          try {
            return a.lengthSync().compareTo(b.lengthSync());
          } catch (e) {
            return 0;
          }
        });
        break;

      case SortOption.sizeDesc:
        _videoFiles.sort((a, b) {
          try {
            return b.lengthSync().compareTo(a.lengthSync());
          } catch (e) {
            return 0;
          }
        });
        break;

      case SortOption.typeAsc:
        _videoFiles.sort((a, b) => pathlib
            .extension(a.path)
            .toLowerCase()
            .compareTo(pathlib.extension(b.path).toLowerCase()));
        break;

      case SortOption.typeDesc:
        _videoFiles.sort((a, b) => pathlib
            .extension(b.path)
            .toLowerCase()
            .compareTo(pathlib.extension(a.path).toLowerCase()));
        break;

      case SortOption.dateCreatedAsc:
        _videoFiles.sort((a, b) {
          try {
            // On Windows, changed means creation time
            if (Platform.isWindows) {
              final aStats = FileStat.statSync(a.path);
              final bStats = FileStat.statSync(b.path);
              return aStats.changed.compareTo(bStats.changed);
            } else {
              // On other platforms, fallback to modified time
              return a.lastModifiedSync().compareTo(b.lastModifiedSync());
            }
          } catch (e) {
            return 0;
          }
        });
        break;

      case SortOption.dateCreatedDesc:
        _videoFiles.sort((a, b) {
          try {
            // On Windows, changed means creation time
            if (Platform.isWindows) {
              final aStats = FileStat.statSync(a.path);
              final bStats = FileStat.statSync(b.path);
              return bStats.changed.compareTo(aStats.changed);
            } else {
              // On other platforms, fallback to modified time
              return b.lastModifiedSync().compareTo(a.lastModifiedSync());
            }
          } catch (e) {
            return 0;
          }
        });
        break;

      case SortOption.extensionAsc:
        _videoFiles.sort((a, b) => pathlib
            .extension(a.path)
            .toLowerCase()
            .compareTo(pathlib.extension(b.path).toLowerCase()));
        break;

      case SortOption.extensionDesc:
        _videoFiles.sort((a, b) => pathlib
            .extension(b.path)
            .toLowerCase()
            .compareTo(pathlib.extension(a.path).toLowerCase()));
        break;

      case SortOption.attributesAsc:
        _videoFiles.sort((a, b) {
          try {
            final aStats = FileStat.statSync(a.path);
            final bStats = FileStat.statSync(b.path);
            // Create a string representation of attributes for comparison
            final aAttrs = '${aStats.mode},${aStats.type}';
            final bAttrs = '${bStats.mode},${bStats.type}';
            return aAttrs.compareTo(bAttrs);
          } catch (e) {
            return 0;
          }
        });
        break;

      case SortOption.attributesDesc:
        _videoFiles.sort((a, b) {
          try {
            final aStats = FileStat.statSync(a.path);
            final bStats = FileStat.statSync(b.path);
            // Create a string representation of attributes for comparison
            final aAttrs = '${aStats.mode},${aStats.type}';
            final bAttrs = '${bStats.mode},${bStats.type}';
            return bAttrs.compareTo(aAttrs);
          } catch (e) {
            return 0;
          }
        });
        break;
    }
  }

  void _setSortOption(SortOption option) async {
    if (_currentSortOption != option) {
      setState(() {
        _currentSortOption = option;
        _sortVideoFiles();
      });

      // Update controller state
      if (_mobileController != null) {
        _mobileController!.currentSortOption = option;
      }

      // Save sort preference (global and folder-specific)
      try {
        // Lưu preference toàn cục
        await _preferences.setSortOption(option);

        // Lưu cài đặt cho thư mục cụ thể
        final folderSortManager = FolderSortManager();
        bool success =
            await folderSortManager.saveFolderSortOption(widget.path, option);

        // Log kết quả
        debugPrint(
            'Saved sort option ${option.name} for folder: ${widget.path}, success: $success');
      } catch (e) {
        debugPrint('Error saving sort option: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    // Sử dụng SharedActionBar để xây dựng danh sách actions
    List<Widget> actions = SharedActionBar.buildCommonActions(
      context: context,
      onSearchPressed: () => _mobileController?.showInlineSearch(context),
      onSortOptionSelected: _setSortOption,
      currentSortOption: _currentSortOption,
      viewMode: _viewMode,
      onViewModeToggled: () {
        setState(() {
          _viewMode =
              _viewMode == ViewMode.grid ? ViewMode.list : ViewMode.grid;
        });
        _saveViewModeSetting(_viewMode);
      },
      onRefresh: () {
        setState(() {
          _loadVideos();
        });
      },
      onGridSizePressed: () => SharedActionBar.showGridSizeDialog(
        context,
        currentGridSize: _thumbnailSize.round(),
        onApply: (size) async {
          setState(() {
            _thumbnailSize = size.toDouble();
          });

          // Lưu cài đặt
          try {
            await _preferences.setVideoGalleryThumbnailSize(size.toDouble());
          } catch (e) {
            debugPrint('Error saving thumbnail size: $e');
          }
        },
      ),
      onSelectionModeToggled: () {
        setState(() {
          _isSelectionMode = true;
        });
      },
    );

    // On mobile, use custom action bar instead of AppBar
    final isMobile = Platform.isAndroid || Platform.isIOS;

    return BaseScreen(
      title: widget.library != null
          ? widget.library!.name
          : 'Video Gallery: ${pathlib.basename(widget.path)}',
      actions: actions,
      showAppBar: !isMobile, // Hide AppBar on mobile
      body: isMobile
          ? Column(
              children: [
                _buildMobileActionBar(context),
                Expanded(child: _buildVideoContent()),
              ],
            )
          : _buildVideoContent(),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          setState(() {
            _isSelectionMode = true;
          });
        },
        child: const Icon(Icons.checklist),
      ),
    );
  }

  // Build mobile action bar using shared controller method
  Widget _buildMobileActionBar(BuildContext context) {
    if (_mobileController == null) return const SizedBox.shrink();
    return _mobileController!
        .buildMobileActionBar(context, viewMode: _viewMode);
  }

  // Get filtered videos based on search query
  List<File> get _filteredVideos {
    if (_searchQuery == null || _searchQuery!.isEmpty) {
      return _videoFiles;
    }
    final searchLower = _searchQuery!.toLowerCase();
    return _videoFiles.where((file) {
      return pathlib.basename(file.path).toLowerCase().contains(searchLower);
    }).toList();
  }

  // Xây dựng nội dung video tùy theo chế độ xem
  Widget _buildVideoContent() {
    final localizations = AppLocalizations.of(context)!;

    // Show skeleton loading while data is being fetched
    if (_isLoadingVideos) {
      return _buildSkeletonLoading();
    }

    // Only show empty message after loading is complete
    if (_videoFiles.isEmpty) {
      return Center(
        child: Text(
          _selectedTags.isNotEmpty
              ? localizations.noVideosInLibrary
              : localizations.noVideosFound,
          style: const TextStyle(fontSize: 16),
        ),
      );
    }

    return Column(
      children: [
        // Tag Filter Bar
        if (widget.library != null || widget.path.isNotEmpty)
          VideoTagFilterBar(
            selectedTags: _selectedTags,
            onTagsChanged: (newTags) {
              setState(() {
                _selectedTags.clear();
                _selectedTags.addAll(newTags);
              });
              _loadVideos();
            },
            libraryPath: widget.library != null ? null : widget.path,
            globalSearch: widget.library != null,
          ),

        // Main video content
        Expanded(
          child: Stack(
            children: [
              // Tìm kiếm và hiển thị kết quả
        // Tìm kiếm và hiển thị kết quả
        if (_searchQuery != null && _searchQuery!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.blue.withAlpha(26),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search, size: 20),
                  const SizedBox(width: 8),
                  Text(localizations.searchingFor(_searchQuery!)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.clear, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      setState(() {
                        _searchQuery = null;
                      });
                    },
                  ),
                ],
              ),
            ),
          ),

        // Hiển thị video theo chế độ xem (danh sách hoặc lưới)
        Padding(
          padding: EdgeInsets.only(top: _searchQuery != null ? 50.0 : 0.0),
          child:
              _viewMode == ViewMode.grid ? _buildGridView() : _buildListView(),
        ),

        // Thông báo đang tải thumbnail
        if (_isLoadingThumbnails)
          Positioned(
            bottom: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(153),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    localizations.loadingThumbnails,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
            ],
          ),
        ),
      ],
    );
  }

  // Hiển thị video dạng lưới
  Widget _buildGridView() {
    final columns = _thumbnailSize.round();

    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(8.0),
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.85, // Standard file grid ratio
      ),
      itemCount: _filteredVideos.length,
      itemBuilder: (context, index) {
        final file = _filteredVideos[index];
        final isSelected = _selectedFilePaths.contains(file.path);

        return FileGridItem(
          file: file,
          isSelected: isSelected,
          isSelectionMode: _isSelectionMode,
          isDesktopMode: !Platform.isAndroid && !Platform.isIOS,
          toggleFileSelection: (path, {shiftSelect = false, ctrlSelect = false}) {
            setState(() {
              if (isSelected) {
                _selectedFilePaths.remove(path);
              } else {
                _selectedFilePaths.add(path);
              }
            });
          },
          toggleSelectionMode: () {
            setState(() {
              _isSelectionMode = !_isSelectionMode;
              if (!_isSelectionMode) {
                _selectedFilePaths.clear();
              }
            });
          },
          onFileTap: (file, isVideo) {
            if (isVideo) {
              Navigator.of(context, rootNavigator: true).push(
                MaterialPageRoute(
                  builder: (context) => VideoPlayerFullScreen(file: file),
                ),
              );
            }
          },
        );
      },
    );
  }

  // Hiển thị video dạng danh sách
  Widget _buildListView() {
    final localizations = AppLocalizations.of(context)!;
    final isMobile = Platform.isAndroid || Platform.isIOS;
    final theme = Theme.of(context);

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(8.0),
      itemCount: _filteredVideos.length,
      itemBuilder: (context, index) {
        final file = _filteredVideos[index];
        final isSelected = _selectedFilePaths.contains(file.path);
        final fileExtension = pathlib.extension(file.path).toLowerCase();

        final listTile = ListTile(
          leading: SizedBox(
            width: 60,
            height: 60,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: ThumbnailHelper.buildVideoThumbnail(
                    videoPath: file.path,
                    width: 60,
                    height: 60,
                    isVisible: true,
                    onThumbnailGenerated: (_) {},
                    fallbackBuilder: () => Container(
                      color: Colors.black12,
                      child: const Icon(Icons.movie, color: Colors.grey),
                    ),
                  ),
                ),
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(128),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
          title: Text(
            pathlib.basename(file.path),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: FutureBuilder<FileStat>(
            future: file.stat(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return Text(localizations.loading);
              }

              final fileStat = snapshot.data!;
              final fileSize = _formatFileSize(fileStat.size);
              final fileDate = _formatDate(fileStat.modified);
              return Text('$fileExtension • $fileSize • $fileDate');
            },
          ),
          selected: isSelected,
          trailing: _isSelectionMode
              ? Checkbox(
                  value: isSelected,
                  onChanged: (value) {
                    setState(() {
                      if (value == true) {
                        _selectedFilePaths.add(file.path);
                      } else {
                        _selectedFilePaths.remove(file.path);
                      }
                    });
                  },
                )
              : null,
          onTap: _isSelectionMode
              ? () {
                  setState(() {
                    if (isSelected) {
                      _selectedFilePaths.remove(file.path);
                    } else {
                      _selectedFilePaths.add(file.path);
                    }
                  });
                }
              : () {
                  Navigator.of(context, rootNavigator: true).push(
                    MaterialPageRoute(
                      builder: (context) => VideoPlayerFullScreen(file: file),
                    ),
                  );
                },
          onLongPress: () {
            if (!_isSelectionMode) {
              setState(() {
                _isSelectionMode = true;
                _selectedFilePaths.add(file.path);
              });
            }
          },
        );

        // Platform-specific wrapper
        if (isMobile) {
          // Mobile: flat design, no Card
          return Container(
            margin: EdgeInsets.zero,
            decoration: BoxDecoration(
              color: isSelected
                  ? theme.colorScheme.primary.withValues(alpha: 0.1)
                  : Colors.transparent,
            ),
            child: listTile,
          );
        } else {
          // Desktop: Card with shadow
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: listTile,
          );
        }
      },
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Hôm nay ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Hôm qua ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} ngày trước';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB"];
    var i = (log(bytes) / log(1024)).floor();
    return '${(bytes / pow(1024, i)).toStringAsFixed(1)} ${suffixes[i]}';
  }

  // Lưu cài đặt chế độ xem
  Future<void> _saveViewModeSetting(ViewMode mode) async {
    try {
      final UserPreferences prefs = UserPreferences.instance;
      await prefs.init();
      await prefs.setViewMode(mode);
    } catch (e) {
      debugPrint('Error saving view mode: $e');
    }
  }

  // Build skeleton loading widget
  Widget _buildSkeletonLoading() {
    final theme = Theme.of(context);
    final isMobile = Platform.isAndroid || Platform.isIOS;

    if (_viewMode == ViewMode.grid) {
      // Grid skeleton - single item
      final columns = _thumbnailSize.round();
      final screenWidth = MediaQuery.of(context).size.width;
      final itemWidth = (screenWidth - 16 - ((columns - 1) * 8)) / columns;
      final itemHeight = itemWidth * 12 / 16;

      return Padding(
        padding: const EdgeInsets.all(8.0),
        child: Align(
          alignment: Alignment.topLeft,
          child: Container(
            width: itemWidth,
            height: itemHeight + 32, // Extra space for text area
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Container(
                    color: theme.colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.5),
                    child: Center(
                      child: Icon(
                        Icons.movie,
                        size: 48,
                        color:
                            theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                ),
                Container(
                  color: theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.5),
                  padding: const EdgeInsets.all(8),
                  child: Container(
                    height: 12,
                    decoration: BoxDecoration(
                      color:
                          theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      // List skeleton - single item
      final listTile = ListTile(
        leading: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(
            Icons.movie,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
          ),
        ),
        title: Container(
          height: 14,
          decoration: BoxDecoration(
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Container(
            height: 12,
            width: double.infinity,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      );

      return Padding(
        padding: const EdgeInsets.all(8.0),
        child: isMobile
            ? listTile
            : Card(
                margin: EdgeInsets.zero,
                child: listTile,
              ),
      );
    }
  }

  // TODO: These methods are currently unused but may be needed for future tag management functionality
  /*
  void _showRemoveTagsDialog(
    // ... existing code ...
  }

  void _showManageAllTagsDialog(BuildContext context) {
    // ... existing code ...
  }

  Future<void> _addTags(List<String> filePaths, String tag) async {
    // ... existing code ...
  }
  */
}

class OptimizedVideoThumbnailItem extends StatelessWidget {
  final File file;
  final VoidCallback onTap;
  final double width;
  final double height;
  final bool usePlaceholder;

  const OptimizedVideoThumbnailItem({
    Key? key,
    required this.file,
    required this.onTap,
    this.width = 120,
    this.height = 90,
    this.usePlaceholder = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final String ext = pathlib.extension(file.path).toLowerCase();

    // Optimize frame timing before rendering thumbnails
    FrameTimingOptimizer().optimizeImageRendering();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Sử dụng LazyVideoThumbnail để hiển thị thumbnail
                  LazyVideoThumbnail(
                    videoPath: file.path,
                    width: width,
                    height: height,
                    placeholderOnly: usePlaceholder,
                    fallbackBuilder: () => _buildFallbackThumbnail(ext),
                  ),

                  // Play button overlay
                  Center(
                    child: Container(
                      padding: EdgeInsets.all(width > 100 ? 8 : 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(128),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.play_arrow,
                        color: Colors.white,
                        size: width > 100 ? 32 : 24,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Filename overlay ở dưới
            Container(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              padding: EdgeInsets.all(width > 100 ? 8 : 4),
              child: Text(
                pathlib.basename(file.path),
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: width > 100 ? 12 : 10,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackThumbnail(String ext) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _getGradientColors(ext),
        ),
      ),
      child: Center(
        child: Icon(
          _getVideoTypeIcon(ext),
          size: width > 100 ? 48 : 32,
          color: Colors.white.withAlpha(179),
        ),
      ),
    );
  }

  IconData _getVideoTypeIcon(String ext) {
    switch (ext) {
      case '.mp4':
        return Icons.movie;
      case '.mkv':
        return Icons.movie;
      case '.avi':
        return Icons.videocam;
      case '.mov':
        return Icons.videocam;
      case '.wmv':
        return Icons.video_library;
      default:
        return Icons.video_file;
    }
  }

  List<Color> _getGradientColors(String ext) {
    switch (ext) {
      case '.mp4':
        return [Colors.blue[900]!, Colors.blue[600]!];
      case '.mkv':
        return [Colors.green[900]!, Colors.green[600]!];
      case '.avi':
        return [Colors.purple[900]!, Colors.purple[600]!];
      case '.mov':
        return [Colors.orange[900]!, Colors.orange[600]!];
      case '.wmv':
        return [Colors.red[900]!, Colors.red[600]!];
      default:
        return [Colors.grey[900]!, Colors.grey[700]!];
    }
  }
}

class VideoPlayerFullScreen extends StatefulWidget {
  final File file;

  const VideoPlayerFullScreen({
    Key? key,
    required this.file,
  }) : super(key: key);

  @override
  _VideoPlayerFullScreenState createState() => _VideoPlayerFullScreenState();
}

class _VideoPlayerFullScreenState extends State<VideoPlayerFullScreen> {
  Map<String, dynamic>? _videoMetadata;
  bool _isFullScreen = false;
  bool _showAppBar = true; // Control app bar visibility
  bool _inAndroidPip = false;
  Timer? _uiEnforceTimer;

  @override
  void initState() {
    super.initState();
    // On mobile, show full UI (both status bar and nav bar)
    if (Platform.isAndroid || Platform.isIOS) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
          overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom]);
      // Also force style after first frame to avoid being overridden
      WidgetsBinding.instance.addPostFrameCallback((_) {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
            overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom]);
        SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
      });
      // Ensure Flutter re-applies overlays automatically while this route is on top
      WidgetsBinding.instance.renderView.automaticSystemUiAdjustment = true;
      // Re-assert overlays for a short period in case platform view toggles them off
      int attempts = 0;
      _uiEnforceTimer?.cancel();
      _uiEnforceTimer =
          Timer.periodic(const Duration(milliseconds: 400), (t) async {
        attempts++;
        if (!mounted || _isFullScreen || attempts > 10) {
          t.cancel();
          return;
        }
        await SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
            overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom]);
        SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
      });
    }
    // Hide app bar while in Android PiP so PiP captures only the video
    const channel = MethodChannel('cb_file_manager/pip');
    channel.setMethodCallHandler((call) async {
      if (call.method == 'onPipChanged') {
        final args = call.arguments;
        bool inPip = false;
        if (args is Map) {
          inPip = args['inPip'] == true;
        }
        if (mounted) {
          setState(() => _inAndroidPip = inPip);
        }
      }
    });
  }

  @override
  void dispose() {
    // Restore system UI when leaving video player
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
        overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom]);
    // Keep automatic adjustment enabled for underlying screens
    WidgetsBinding.instance.renderView.automaticSystemUiAdjustment = true;
    _uiEnforceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = Platform.isAndroid || Platform.isIOS;
    final scaffold = Scaffold(
      // On mobile, avoid extra app bar since parent already has one
      appBar: isMobile
          ? null
          : ((_isFullScreen && !_showAppBar) || _inAndroidPip
              ? null // Hide app bar completely when in fullscreen and _showAppBar is false
              : VideoPlayerAppBar(
                  title: pathlib.basename(widget.file.path),
                  actions: [
                    IconButton(
                      icon:
                          const Icon(Icons.info_outline, color: Colors.white70),
                      onPressed: () => _showVideoInfo(context),
                    ),
                  ],
                  onClose: () {
                    // Close the app completely when close button is pressed
                    exit(0);
                  },
                  showWindowControls: true,
                  blurAmount: 12.0,
                  opacity: 0.6,
                )),
      extendBody: true,
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.black,
      body: Center(
        child: VideoPlayer.file(
          file: widget.file,
          autoPlay: true,
          showControls: true,
          allowFullScreen: true,
          onVideoInitialized: (metadata) {
            setState(() {
              _videoMetadata = metadata;
            });
            // Ensure status bar is visible after player initializes (some plugins toggle UI)
            if (Platform.isAndroid || Platform.isIOS) {
              SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
                  overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom]);
              SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
            }
          },
          onError: (errorMessage) {
            // Optional: Show a snackbar or other notification
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Lỗi: $errorMessage')),
            );
          },
          // Add callbacks to synchronize fullscreen state and control visibility
          onFullScreenChanged: () {
            setState(() {
              _isFullScreen = !_isFullScreen;
              // When entering fullscreen, start with controls/appbar visible then hide after delay
              _showAppBar = true;
              if (_isFullScreen) {
                // Auto-hide after a delay
                Future.delayed(const Duration(seconds: 3), () {
                  if (mounted && _isFullScreen) {
                    setState(() {
                      _showAppBar = false;
                    });
                  }
                });
              }
            });
          },
          onControlVisibilityChanged: () {
            // Sync app bar visibility with video controls visibility
            if (_isFullScreen) {
              setState(() {
                _showAppBar = true;
              });
              // Auto-hide after a delay
              Future.delayed(const Duration(seconds: 3), () {
                if (mounted && _isFullScreen) {
                  setState(() {
                    _showAppBar = false;
                  });
                }
              });
            }
          },
          onOpenFolder: (folderPath, highlightedFileName) {
            debugPrint(
                '========== VIDEO_GALLERY onOpenFolder CALLBACK ==========');
            debugPrint('Folder path: $folderPath');
            debugPrint('Highlighted file: $highlightedFileName');

            // Pop back to parent screen with result containing folder info
            // The parent (tabbed_folder_list_screen) will handle opening the tab
            Navigator.of(context).pop({
              'action': 'openFolder',
              'folderPath': folderPath,
              'highlightedFileName': highlightedFileName,
            });

            debugPrint('Popped with folder open request');
            debugPrint('========== END VIDEO_GALLERY onOpenFolder ==========');
          },
        ),
      ),
    );
    return isMobile
        ? AnnotatedRegion<SystemUiOverlayStyle>(
            value: SystemUiOverlayStyle.light, child: scaffold)
        : scaffold;
  }

  void _showVideoInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => VideoInfoDialog(
        file: widget.file,
        videoMetadata: _videoMetadata,
      ),
    );
  }
}
