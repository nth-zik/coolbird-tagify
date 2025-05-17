import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import '../../helpers/video_thumbnail_helper.dart';
import '../../helpers/thumbnail_isolate_manager.dart';
import '../../helpers/frame_timing_optimizer.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// A widget that efficiently displays a video thumbnail with lazy loading
/// and background processing to avoid UI thread blocking during scrolling
class LazyVideoThumbnail extends StatefulWidget {
  /// Path to the video file for which the thumbnail should be generated
  final String videoPath;

  /// Width of the thumbnail
  final double width;

  /// Height of the thumbnail
  final double height;

  /// Builder function that returns a widget to show when thumbnail is loading or on error
  final Widget Function() fallbackBuilder;

  /// Whether to keep the thumbnail in memory when it's scrolled out of view
  final bool keepAlive;

  /// If true, only shows the placeholder and doesn't attempt to load thumbnails
  final bool placeholderOnly;

  /// Callback when thumbnail is successfully generated
  final Function(String path)? onThumbnailGenerated;

  /// Callback when thumbnail generation fails with an error
  final Function(dynamic error)? onError;

  const LazyVideoThumbnail({
    Key? key,
    required this.videoPath,
    this.width = 160,
    this.height = 120,
    required this.fallbackBuilder,
    this.keepAlive = true,
    this.placeholderOnly = false,
    this.onThumbnailGenerated,
    this.onError,
  }) : super(key: key);

  @override
  State<LazyVideoThumbnail> createState() => _LazyVideoThumbnailState();
}

class _LazyVideoThumbnailState extends State<LazyVideoThumbnail>
    with AutomaticKeepAliveClientMixin {
  // Notifiers to maintain widget state
  final _visibilityNotifier = ValueNotifier<bool>(false);
  final _thumbnailPathNotifier = ValueNotifier<String?>(null);
  final _progressNotifier = ValueNotifier<double>(0.0);

  // State tracking
  bool _isLoading = false;
  bool _isError = false;
  bool _wasAttempted = false;
  bool _wasVisible = false;
  bool _isThumbnailGenerated = false;
  // Add a new flag to prevent regeneration when path hasn't changed
  bool _shouldRegenerateThumbnail = true;

  // Thumbnail generation manager
  final _isolateManager = ThumbnailIsolateManager.instance;

  // Progress simulation timer
  Timer? _progressTimer;

  // Stream subscription to cache clear events
  StreamSubscription? _cacheChangedSubscription;

  // AutomaticKeepAliveClientMixin implementation
  @override
  bool get wantKeepAlive => widget.keepAlive;

  @override
  void initState() {
    super.initState();
    debugPrint(
        '[Thumbnail] Initializing thumbnail for video: ${widget.videoPath}');
    _scheduleInitialLoad();

    // Subscribe to cache changed events
    _cacheChangedSubscription = VideoThumbnailHelper.onCacheChanged.listen((_) {
      _handleCacheCleared();
    });
  }

  @override
  void dispose() {
    _visibilityNotifier.dispose();
    _thumbnailPathNotifier.dispose();
    _progressNotifier.dispose();
    _progressTimer?.cancel();
    _cacheChangedSubscription?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(LazyVideoThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Only set regeneration flag if the path actually changed
    if (widget.videoPath != oldWidget.videoPath) {
      _shouldRegenerateThumbnail = true;
      _scheduleInitialLoad();
    }
  }

  /// Handle the event when the thumbnail cache is cleared
  void _handleCacheCleared() {
    debugPrint(
        '[Thumbnail] Cache cleared notification received for ${widget.videoPath}');
    if (!mounted) return;

    // Reset thumbnail path
    final hadThumbnail = _thumbnailPathNotifier.value != null;
    _thumbnailPathNotifier.value = null;
    _isThumbnailGenerated = false;
    _shouldRegenerateThumbnail = true;

    // Only reload immediately if the widget is visible
    if (_visibilityNotifier.value) {
      debugPrint(
          '[Thumbnail] Widget is visible, reloading thumbnail after cache clear for ${widget.videoPath}');
      // Reset error state if there was one
      if (_isError) {
        _isError = false;
      }

      // If we had a thumbnail before, force regeneration
      _loadThumbnail(forceRegenerate: hadThumbnail, isPriority: true);
    }
  }

  /// Schedule initial thumbnail load after layout is complete
  void _scheduleInitialLoad() {
    // Don't schedule if we've determined we don't need to regenerate
    if (!_shouldRegenerateThumbnail) return;

    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      // Start a Future chain to check cache and load thumbnail
      VideoThumbnailHelper.getFromCache(widget.videoPath)
          .then((cachedThumbnailPath) {
        if (!mounted) return;

        // If we have a cached path, use it immediately
        if (cachedThumbnailPath != null) {
          _thumbnailPathNotifier.value = cachedThumbnailPath;
          _isThumbnailGenerated = true;
          _shouldRegenerateThumbnail = false;

          // Notify parent if we already have a thumbnail
          if (widget.onThumbnailGenerated != null) {
            widget.onThumbnailGenerated!(cachedThumbnailPath);
          }
          return;
        }

        // If no cached thumbnail, check if we should load
        if (_visibilityNotifier.value && !widget.placeholderOnly) {
          _loadThumbnail(isPriority: true);
        }
      }).catchError((error) {
        debugPrint('[Thumbnail] Error checking cache: $error');

        // Try loading anyway if visible and not in placeholder mode
        if (mounted && _visibilityNotifier.value && !widget.placeholderOnly) {
          _loadThumbnail(isPriority: true);
        }
      });
    });
  }

  /// Start loading the thumbnail
  void _loadThumbnail({bool forceRegenerate = false, bool isPriority = false}) {
    // Skip if already loading, if we're in placeholder-only mode,
    // if we already have a thumbnail generated and don't need to regenerate,
    // or if we've determined we don't need to regenerate
    if (_isLoading ||
        widget.placeholderOnly ||
        (_thumbnailPathNotifier.value != null && !forceRegenerate) ||
        (!_shouldRegenerateThumbnail && !forceRegenerate)) {
      return;
    }

    debugPrint(
        '[Thumbnail] Starting thumbnail load for ${widget.videoPath} (force=$forceRegenerate, priority=$isPriority)');

    _isLoading = true;
    _wasAttempted = true;
    _progressNotifier.value = 0.0;

    // Start progress simulation for better UX
    _simulateProgressUpdates();

    // Attempt to generate the thumbnail
    _isolateManager
        .generateThumbnail(
      widget.videoPath,
      priority: isPriority ? 150 : 100,
      forceRegenerate: forceRegenerate,
    )
        .then((path) {
      if (!mounted) return;

      _progressTimer?.cancel();
      _isLoading = false;

      if (path != null) {
        debugPrint(
            '[Thumbnail] Thumbnail generated successfully for ${widget.videoPath}');
        _thumbnailPathNotifier.value = path;
        _isThumbnailGenerated = true;
        _shouldRegenerateThumbnail = false;
        _onThumbnailGenerated(path);
      } else {
        debugPrint(
            '[Thumbnail] Failed to generate thumbnail for ${widget.videoPath}');
        _thumbnailPathNotifier.value = null;
        _isError = true;

        // Call onError callback if provided
        if (widget.onError != null) {
          widget.onError!('Failed to generate thumbnail');
        }
      }

      // Update UI
      _progressNotifier.value = 1.0;
      if (mounted) {
        setState(() {});
      }
    }).catchError((error) {
      if (!mounted) return;

      _progressTimer?.cancel();
      debugPrint(
          '[Thumbnail] Error generating thumbnail for ${widget.videoPath}: $error');
      _thumbnailPathNotifier.value = null;
      _isLoading = false;
      _isError = true;
      _progressNotifier.value = 0.0;

      // Call onError callback if provided
      if (widget.onError != null) {
        widget.onError!(error);
      }

      if (mounted) {
        setState(() {});
      }
    });
  }

  /// Simulate progress updates for better UX while thumbnail is generating
  void _simulateProgressUpdates() {
    _progressTimer?.cancel();
    _progressNotifier.value = 0.0;

    _progressTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted || _thumbnailPathNotifier.value != null) {
        timer.cancel();
        return;
      }

      double currentValue = _progressNotifier.value;
      // Simulate progress with diminishing returns curve
      if (currentValue < 0.95) {
        // Increment faster at the beginning, slower as we get closer to 95%
        double increment = (1.0 - currentValue) * 0.05;
        _progressNotifier.value = currentValue + increment;
      }
    });
  }

  /// Handle the thumbnail generation completion
  void _onThumbnailGenerated(String path) {
    // Notify parent about the thumbnail being generated
    if (path != null && widget.onThumbnailGenerated != null) {
      // Use a post-frame callback to avoid calling during build
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          debugPrint(
              '[Thumbnail] Notifying parent about thumbnail generated for ${widget.videoPath}');
          widget.onThumbnailGenerated!(path);
        }
      });
    }

    // Force an immediate UI update to show the thumbnail
    if (mounted && path != null) {
      setState(() {});
    }
  }

  /// Visibility change handler that triggers thumbnail loading when widget becomes visible
  void _onVisibilityChanged(VisibilityInfo info) {
    if (!mounted) return;

    final isNowVisible = info.visibleFraction > 0;

    if (isNowVisible) {
      _visibilityNotifier.value = true;
      _wasVisible = true;

      // Load thumbnail if needed when widget becomes visible
      if (_thumbnailPathNotifier.value == null &&
          !_isLoading &&
          !widget.placeholderOnly &&
          !_isThumbnailGenerated) {
        debugPrint(
            '[Thumbnail] Widget became visible, loading thumbnail for ${widget.videoPath}');
        _loadThumbnail(isPriority: true);
      } else if (_wasAttempted &&
          _thumbnailPathNotifier.value == null &&
          !_isLoading &&
          !widget.placeholderOnly &&
          !_isThumbnailGenerated) {
        debugPrint(
            '[Thumbnail] Widget became visible, regenerating thumbnail for ${widget.videoPath}');
        _loadThumbnail(forceRegenerate: true, isPriority: true);
      }
    } else if (_visibilityNotifier.value) {
      _visibilityNotifier.value = false;
      _wasVisible = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    // Ensure frame timing is optimized
    FrameTimingOptimizer().optimizeImageRendering();

    // Use a unique key for the VisibilityDetector based on video path
    // This helps Flutter identify and reuse this widget when possible
    final String visibilityKey = 'vid-visibility-${widget.videoPath.hashCode}';

    return ValueListenableBuilder<String?>(
      valueListenable: _thumbnailPathNotifier,
      builder: (context, thumbnailPath, _) {
        // First check if we have a valid thumbnail to display
        if (thumbnailPath != null) {
          return _buildThumbnailImage(thumbnailPath);
        }

        // The main widget that detects visibility and loads thumbnails
        return VisibilityDetector(
          key: Key(visibilityKey),
          onVisibilityChanged: _onVisibilityChanged,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // The fallback widget provided by the consumer
              widget.fallbackBuilder(),

              // Show loading indicator if loading
              if (_isLoading) Center(child: _buildProgressIndicator()),
            ],
          ),
        );
      },
    );
  }

  /// Build circular progress indicator
  Widget _buildProgressIndicator() {
    return ValueListenableBuilder<double>(
      valueListenable: _progressNotifier,
      builder: (context, progress, _) {
        return SizedBox(
          width: 32,
          height: 32,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            value: progress > 0 ? progress : null,
            valueColor: AlwaysStoppedAnimation<Color>(
              Theme.of(context).primaryColor.withOpacity(0.8),
            ),
          ),
        );
      },
    );
  }

  /// Build progress percentage label
  Widget _buildProgressLabel() {
    return ValueListenableBuilder<double>(
      valueListenable: _progressNotifier,
      builder: (context, progress, _) {
        return Positioned(
          bottom: 4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '${(progress * 100).toInt()}%',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      },
    );
  }

  /// Build the actual thumbnail image
  Widget _buildThumbnailImage(String thumbnailPath) {
    debugPrint(
        '[Thumbnail] Building thumbnail image for ${widget.videoPath} with path: $thumbnailPath');

    return RepaintBoundary(
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: Image.file(
          File(thumbnailPath),
          key: ValueKey(
              'thumbnail-${widget.videoPath}-${thumbnailPath.hashCode}'),
          width: widget.width,
          height: widget.height,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
          errorBuilder: (context, error, stackTrace) {
            debugPrint(
                '[Thumbnail] Error loading thumbnail image for ${widget.videoPath}: $error');
            _thumbnailPathNotifier.value = null;
            _isLoading = false;
            _isError = true;
            _isThumbnailGenerated = false;
            _shouldRegenerateThumbnail = true;
            VideoThumbnailHelper.removeFromCache(widget.videoPath);
            return widget.fallbackBuilder();
          },
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
            if (wasSynchronouslyLoaded) {
              debugPrint(
                  '[Thumbnail] Thumbnail image loaded synchronously for ${widget.videoPath}');
              // Also notify for synchronously loaded images
              SchedulerBinding.instance.addPostFrameCallback((_) {
                if (mounted &&
                    widget.onThumbnailGenerated != null &&
                    !_isThumbnailGenerated) {
                  widget.onThumbnailGenerated!(thumbnailPath);
                  _isThumbnailGenerated = true;
                  _shouldRegenerateThumbnail = false;
                }
              });
              return child;
            }

            if (frame != null) {
              debugPrint(
                  '[Thumbnail] Thumbnail image frame loaded for ${widget.videoPath}');
              // Thumbnail is ready now
              SchedulerBinding.instance.addPostFrameCallback((_) {
                if (mounted &&
                    widget.onThumbnailGenerated != null &&
                    !_isThumbnailGenerated) {
                  widget.onThumbnailGenerated!(thumbnailPath);
                  _isThumbnailGenerated = true;
                  _shouldRegenerateThumbnail = false;
                }
              });
            }

            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: frame != null
                  ? child
                  : SizedBox(
                      width: widget.width,
                      height: widget.height,
                      child: widget.fallbackBuilder()),
            );
          },
        ),
      ),
    );
  }
}

/// A grid item that displays a video thumbnail with lazy loading
/// For use in GridView to display video files
class LazyVideoGridItem extends StatelessWidget {
  final File file;
  final VoidCallback onTap;
  final double width;
  final double height;

  const LazyVideoGridItem({
    Key? key,
    required this.file,
    required this.onTap,
    this.width = 160,
    this.height = 120,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Sử dụng RepaintBoundary để giảm việc vẽ lại khi scroll
    return RepaintBoundary(
      child: GestureDetector(
        onTap: onTap,
        child: Card(
          clipBehavior: Clip.antiAlias,
          elevation: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: LazyVideoThumbnail(
                  videoPath: file.path,
                  width: width,
                  height: height,
                  fallbackBuilder: () => Container(
                    color: Colors.black12,
                    child: Center(
                      child: Icon(
                        Icons.movie_outlined,
                        size: 48,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  file.path.split('/').last,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}

/// A list item that displays a video thumbnail with lazy loading
/// For use in ListView to display video files
class LazyVideoListItem extends StatelessWidget {
  final File file;
  final VoidCallback onTap;
  final double thumbnailWidth;
  final double thumbnailHeight;

  const LazyVideoListItem({
    Key? key,
    required this.file,
    required this.onTap,
    this.thumbnailWidth = 120,
    this.thumbnailHeight = 80,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final fileName = file.path.split('/').last;
    final fileExt = fileName.split('.').last.toUpperCase();

    // Dùng RepaintBoundary để giảm việc vẽ lại khi scroll
    return RepaintBoundary(
      child: ListTile(
        onTap: onTap,
        leading: SizedBox(
          width: thumbnailWidth,
          height: thumbnailHeight,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LazyVideoThumbnail(
              videoPath: file.path,
              width: thumbnailWidth,
              height: thumbnailHeight,
              fallbackBuilder: () => Container(
                color: Colors.black12,
                child: Center(
                  child: Text(
                    fileExt,
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        title: Text(fileName),
        // Thay FutureBuilder bằng cách lưu trữ thông tin file
        subtitle: _FileInfoWidget(file: file),
        trailing: PopupMenuButton(
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'play',
              child: Row(
                children: [
                  Icon(Icons.play_arrow),
                  SizedBox(width: 8),
                  Text('Play'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'info',
              child: Row(
                children: [
                  Icon(Icons.info_outline),
                  SizedBox(width: 8),
                  Text('Properties'),
                ],
              ),
            ),
          ],
          onSelected: (value) {
            if (value == 'play') {
              onTap();
            } else if (value == 'info') {
              // Show file properties dialog
            }
          },
        ),
      ),
    );
  }
}

// Widget riêng để hiển thị thông tin file, tránh rebuild ListTile khi loading thông tin
class _FileInfoWidget extends StatefulWidget {
  final File file;

  const _FileInfoWidget({required this.file});

  @override
  _FileInfoWidgetState createState() => _FileInfoWidgetState();
}

class _FileInfoWidgetState extends State<_FileInfoWidget> {
  String? _fileInfo;

  @override
  void initState() {
    super.initState();
    _loadFileInfo();
  }

  Future<void> _loadFileInfo() async {
    try {
      final fileStat = await widget.file.stat();
      final size = _formatFileSize(fileStat.size);
      final modified = _formatDate(fileStat.modified);
      if (mounted) {
        setState(() {
          _fileInfo = '$size • $modified';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _fileInfo = 'Error loading info';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Text(_fileInfo ?? 'Loading...');
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String _formatDate(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }
}
