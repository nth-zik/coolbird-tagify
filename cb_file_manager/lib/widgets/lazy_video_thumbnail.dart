import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import '../helpers/video_thumbnail_helper.dart';
import '../helpers/thumbnail_isolate_manager.dart';
import '../helpers/frame_timing_optimizer.dart';
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

  const LazyVideoThumbnail({
    Key? key,
    required this.videoPath,
    this.width = 160,
    this.height = 120,
    required this.fallbackBuilder,
    this.keepAlive = true,
    this.placeholderOnly = false,
    this.onThumbnailGenerated,
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

  /// Handle the event when the thumbnail cache is cleared
  void _handleCacheCleared() {
    debugPrint(
        '[Thumbnail] Cache cleared notification received for ${widget.videoPath}');
    if (!mounted) return;

    // Reset thumbnail path
    final hadThumbnail = _thumbnailPathNotifier.value != null;
    _thumbnailPathNotifier.value = null;

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
    } else if (hadThumbnail) {
      // For non-visible thumbnails, just mark as needing regeneration when they become visible
      _wasAttempted = false;

      // Force a rebuild to show placeholder instead of thumbnail
      setState(() {});
      debugPrint(
          '[Thumbnail] Widget not visible, will reload when visible: ${widget.videoPath}');
    }
  }

  /// Schedule the initial thumbnail loading after the first frame is rendered
  void _scheduleInitialLoad() {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted && !widget.placeholderOnly) {
        debugPrint(
            '[Thumbnail] Scheduling thumbnail load for: ${widget.videoPath}');
        _prefetchThumbnail();
      }
    });
  }

  /// Attempt to load the thumbnail with low priority when widget is initialized
  Future<void> _prefetchThumbnail() async {
    if (!mounted || _thumbnailPathNotifier.value != null) return;

    _isLoading = true;
    _updateProgress(0.1);

    // Try quick cache lookup first
    final cachedPath = await _checkCache();
    if (cachedPath != null && mounted) {
      debugPrint(
          '[Thumbnail] Using cached thumbnail for ${widget.videoPath}: $cachedPath');
      _setThumbnailPath(cachedPath);
      return;
    }

    // Start progress simulation for better UX
    _startProgressSimulation();

    // Queue thumbnail generation with low priority
    if (mounted) {
      debugPrint(
          '[Thumbnail] No cached thumbnail found for ${widget.videoPath}, generating new one');
      _generateThumbnail(priority: 0);
    }
  }

  /// Start simulating progress to provide visual feedback
  void _startProgressSimulation() {
    // Cancel existing timer if any
    _progressTimer?.cancel();

    // Set initial progress
    _updateProgress(0.2); // Start at 20% for better visual feedback

    // Force immediate UI update
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_progressNotifier.value <= 0.2) {
        _updateProgress(0.25);
      }
    });

    // Create periodic timer for progress updates with faster interval
    _progressTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (!mounted || !_isLoading) {
        timer.cancel();
        return;
      }

      double current = _progressNotifier.value;

      // Progressive simulation with different speeds based on current progress
      if (current < 0.4) {
        _updateProgress(current + 0.08); // Fast initial progress
      } else if (current < 0.7) {
        _updateProgress(current + 0.05); // Medium speed
      } else if (current < 0.95) {
        _updateProgress(current + 0.01); // Slower near completion
      } else if (_thumbnailPathNotifier.value != null) {
        _updateProgress(1.0);
        timer.cancel();
      }
    });
  }

  /// Update progress value and ensure animated progress is visible
  void _updateProgress(double value) {
    if (mounted) {
      _progressNotifier.value = value;
    }
  }

  /// Set the thumbnail path and update related state
  void _setThumbnailPath(String? path) {
    if (!mounted) return;

    debugPrint(
        '[Thumbnail] Setting thumbnail path for ${widget.videoPath}: $path');

    // Update state
    _thumbnailPathNotifier.value = path;
    _updateProgress(path != null
        ? 1.0
        : 0.0); // Immediately set to 100% when thumbnail is loaded
    _isLoading = false;

    // Cancel any progress simulation timer when thumbnail is ready
    _progressTimer?.cancel();
    _progressTimer = null;

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
          !widget.placeholderOnly) {
        debugPrint(
            '[Thumbnail] Widget became visible, loading thumbnail for ${widget.videoPath}');
        _loadThumbnail(isPriority: true);
      } else if (_wasAttempted &&
          _thumbnailPathNotifier.value == null &&
          !_isLoading &&
          !widget.placeholderOnly) {
        debugPrint(
            '[Thumbnail] Widget became visible, regenerating thumbnail for ${widget.videoPath}');
        _loadThumbnail(forceRegenerate: true, isPriority: true);
      }
    } else if (_visibilityNotifier.value) {
      _visibilityNotifier.value = false;
      _wasVisible = false;
    }
  }

  /// Check if thumbnail is available in cache
  Future<String?> _checkCache() async {
    try {
      final cachedPath =
          await VideoThumbnailHelper.getFromCache(widget.videoPath);
      debugPrint(
          '[Thumbnail] Cache check for ${widget.videoPath}: ${cachedPath != null ? 'Found: $cachedPath' : 'Not found'}');
      return cachedPath;
    } catch (e) {
      debugPrint(
          '[Thumbnail] Error checking cache for ${widget.videoPath}: $e');
      return null;
    }
  }

  /// Primary thumbnail loading handler with multi-stage approach
  void _loadThumbnail({bool forceRegenerate = false, bool isPriority = false}) {
    if (!mounted) return;

    debugPrint(
        '[Thumbnail] Loading thumbnail for ${widget.videoPath} (force: $forceRegenerate, priority: $isPriority)');

    _isLoading = true;
    _wasAttempted = true;
    _updateProgress(
        0.25); // Start at higher progress for better visual feedback
    _startProgressSimulation();
    _optimizeFrameTiming();

    // Force an immediate rebuild to show the loading state
    setState(() {});

    // Try cache first unless forcing regeneration
    if (!forceRegenerate) {
      _checkCache().then((cachedPath) {
        if (mounted && cachedPath != null) {
          debugPrint(
              '[Thumbnail] Using cached thumbnail for ${widget.videoPath}: $cachedPath');
          _setThumbnailPath(cachedPath);
          // Force UI update immediately when thumbnail is found in cache
          setState(() {});
          return;
        }

        // Proceed with generation if not in cache
        if (mounted) {
          debugPrint(
              '[Thumbnail] No cached thumbnail found for ${widget.videoPath}, generating new one');
          _generateThumbnailWithFallbacks(forceRegenerate, isPriority);
        }
      });
    } else {
      debugPrint(
          '[Thumbnail] Force regenerating thumbnail for ${widget.videoPath}');
      _generateThumbnailWithFallbacks(forceRegenerate, isPriority);
    }
  }

  /// Generate thumbnail using multiple approaches with fallbacks
  void _generateThumbnailWithFallbacks(bool forceRegenerate, bool isPriority) {
    if (!mounted) return;

    final priority = isPriority ? 150 : 100;
    debugPrint(
        '[Thumbnail] Generating thumbnail with direct approach for ${widget.videoPath}');

    // Try direct approach first
    VideoThumbnailHelper.forceRegenerateThumbnail(widget.videoPath)
        .timeout(const Duration(seconds: 5), onTimeout: () {
      debugPrint(
          '[Thumbnail] Direct thumbnail generation timed out for ${widget.videoPath}');
      return null;
    }).then((directPath) {
      if (mounted && directPath != null) {
        debugPrint(
            '[Thumbnail] Direct thumbnail generation succeeded for ${widget.videoPath}: $directPath');
        _setThumbnailPath(directPath);
        // Force an immediate UI update when the thumbnail is loaded
        setState(() {});
        return;
      }

      // Fall back to isolate manager
      if (mounted) {
        debugPrint(
            '[Thumbnail] Direct approach failed for ${widget.videoPath}, trying isolate manager');
        _generateThumbnail(
            priority: priority, forceRegenerate: forceRegenerate);
      }
    });
  }

  /// Generate thumbnail using ThumbnailIsolateManager
  void _generateThumbnail(
      {required int priority, bool forceRegenerate = false}) {
    debugPrint(
        '[Thumbnail] Generating thumbnail with isolate manager for ${widget.videoPath} (priority: $priority)');

    _isolateManager
        .generateThumbnail(widget.videoPath,
            priority: priority, forceRegenerate: forceRegenerate)
        .then((path) {
      if (!mounted) return;

      if (path != null) {
        debugPrint(
            '[Thumbnail] Isolate manager thumbnail generation succeeded for ${widget.videoPath}: $path');
        _setThumbnailPath(path);
        // Force UI update immediately when thumbnail is loaded
        setState(() {});
      } else {
        debugPrint(
            '[Thumbnail] Isolate manager failed for ${widget.videoPath}, making last attempt');
        // Make last attempt if isolate manager fails
        _makeLastAttempt();
      }
    }).catchError((error) {
      if (!mounted) return;

      debugPrint(
          '[Thumbnail] Error generating thumbnail with isolate manager for ${widget.videoPath}: $error');
      _isLoading = false;
      _isError = true;
      _updateProgress(0.0);
      VideoThumbnailHelper.markAttempted(widget.videoPath);
    });
  }

  /// Last resort attempt to generate thumbnail
  void _makeLastAttempt() {
    if (!mounted) return;

    debugPrint(
        '[Thumbnail] Making last attempt to generate thumbnail for ${widget.videoPath}');
    VideoThumbnailHelper.markAttempted(widget.videoPath);

    VideoThumbnailHelper.generateThumbnail(widget.videoPath, isPriority: true)
        .timeout(const Duration(seconds: 3), onTimeout: () {
      debugPrint('[Thumbnail] Last attempt timed out for ${widget.videoPath}');
      return null;
    }).then((lastPath) {
      if (mounted) {
        if (lastPath != null) {
          debugPrint(
              '[Thumbnail] Last attempt succeeded for ${widget.videoPath}: $lastPath');
        } else {
          debugPrint('[Thumbnail] Last attempt failed for ${widget.videoPath}');
        }
        _setThumbnailPath(lastPath);
        // Force an immediate UI update when the thumbnail is loaded
        setState(() {});
      }
    });
  }

  /// Optimize frame timing during thumbnail generation
  void _optimizeFrameTiming() {
    FrameTimingOptimizer().optimizeImageRendering();

    SchedulerBinding.instance.scheduleFrameCallback((_) {
      Timer(Duration.zero, () {
        SystemChannels.skia.invokeMethod<void>(
            'Skia.setResourceCacheMaxBytes', 512 * 1024 * 1024);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    // Create placeholder with consistent size
    final sizedPlaceholder = SizedBox(
      width: widget.width,
      height: widget.height,
      child: widget.fallbackBuilder(),
    );

    // Just return placeholder if set to placeholder only mode
    if (widget.placeholderOnly) {
      return sizedPlaceholder;
    }

    // Generate unique key for visibility detector
    final attemptStatus = _wasAttempted ? 'attempted' : 'not_attempted';
    final visibilityKey =
        ValueKey('video_thumb_${widget.videoPath}_$attemptStatus');

    return VisibilityDetector(
      key: visibilityKey,
      onVisibilityChanged: _onVisibilityChanged,
      child: ValueListenableBuilder<String?>(
        valueListenable: _thumbnailPathNotifier,
        builder: (context, thumbnailPath, _) {
          return RepaintBoundary(
            child: thumbnailPath != null && !_isError
                ? _buildThumbnailImage(thumbnailPath)
                : _buildLoadingPlaceholder(sizedPlaceholder),
          );
        },
      ),
    );
  }

  /// Build the loading placeholder with progress indicator
  Widget _buildLoadingPlaceholder(Widget sizedPlaceholder) {
    return ValueListenableBuilder<bool>(
      valueListenable: _visibilityNotifier,
      builder: (context, isVisible, _) {
        return Stack(
          alignment: Alignment.center,
          children: [
            sizedPlaceholder,
            if (isVisible && _isLoading) _buildProgressIndicator(),
            if (isVisible && _isLoading) _buildProgressLabel(),
          ],
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
    // Notify parent with the path as soon as we build the thumbnail
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.onThumbnailGenerated != null) {
        widget.onThumbnailGenerated!(thumbnailPath);
      }
    });

    debugPrint(
        '[Thumbnail] Building thumbnail image for ${widget.videoPath} with path: $thumbnailPath');

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Image.file(
        File(thumbnailPath),
        key: ValueKey(thumbnailPath),
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
          VideoThumbnailHelper.removeFromCache(widget.videoPath);
          return widget.fallbackBuilder();
        },
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded) {
            debugPrint(
                '[Thumbnail] Thumbnail image loaded synchronously for ${widget.videoPath}');
            // Also notify for synchronously loaded images
            SchedulerBinding.instance.addPostFrameCallback((_) {
              if (mounted && widget.onThumbnailGenerated != null) {
                widget.onThumbnailGenerated!(thumbnailPath);
              }
            });
            return child;
          }

          if (frame != null) {
            debugPrint(
                '[Thumbnail] Thumbnail image frame loaded for ${widget.videoPath}');
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
