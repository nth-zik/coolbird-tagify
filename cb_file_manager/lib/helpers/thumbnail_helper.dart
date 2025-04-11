import 'dart:io';
import 'dart:math' as math;
import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path_util;
import 'package:ffmpeg_helper/ffmpeg_helper.dart';
import 'package:path_provider/path_provider.dart';
import 'ffmpeg_extensions.dart'; // Import the extensions

/// Quản lý hàng đợi tạo thumbnail để tránh quá tải hệ thống
class ThumbnailTaskManager {
  static final ThumbnailTaskManager _instance =
      ThumbnailTaskManager._internal();
  factory ThumbnailTaskManager() => _instance;
  ThumbnailTaskManager._internal();

  // Hàng đợi các tác vụ tạo thumbnail
  final List<_ThumbnailTask> _queue = [];

  // Danh sách các tác vụ đang chạy
  final List<_ThumbnailTask> _runningTasks = [];

  // Số lượng tác vụ tối đa được phép chạy đồng thời
  // Khi hiển thị nhiều cột (10), giảm xuống để tránh quá tải hệ thống
  final int maxConcurrentTasks = 3;

  // Cache cho thumbnail đã tải vào bộ nhớ để tránh đọc từ disk liên tục
  static final Map<String, Uint8List> _memoryCache = {};

  // Trạng thái của task manager
  bool _isProcessing = false;

  // Kích thước mặc định của thumbnail để giảm tải hệ thống
  static const int thumbnailQuality = 70; // Giảm chất lượng ảnh
  static const int maxThumbnailSize =
      200; // Giới hạn kích thước thumbnail để giảm bộ nhớ

  /// Thêm một tác vụ tạo thumbnail vào hàng đợi
  void addTask({
    required String videoPath,
    required Function(String?) onComplete,
    int priority = 0,
  }) {
    // Kiểm tra nếu đã có trong memory cache
    if (_memoryCache.containsKey(videoPath)) {
      // Trả về đường dẫn file để giữ tương thích với code hiện tại
      final cachedPath = ThumbnailHelper._thumbnailCache[videoPath];
      if (cachedPath != null) {
        onComplete(cachedPath);
        return;
      }
    }

    // Kiểm tra nếu thumbnail đã có trong file cache
    if (ThumbnailHelper._thumbnailCache.containsKey(videoPath)) {
      final cachedPath = ThumbnailHelper._thumbnailCache[videoPath];
      if (cachedPath != null && File(cachedPath).existsSync()) {
        // Nếu đã có trong cache, trả về ngay lập tức
        onComplete(cachedPath);

        // Đọc vào memory cache để lần sau không cần đọc từ disk
        _loadIntoMemoryCache(videoPath, cachedPath);
        return;
      } else {
        // Xóa cache không hợp lệ
        ThumbnailHelper._thumbnailCache.remove(videoPath);
      }
    }

    // Kiểm tra xem tác vụ đã tồn tại trong queue hoặc đang chạy
    bool taskExists = false;

    for (var task in _queue) {
      if (task.videoPath == videoPath) {
        taskExists = true;
        // Cập nhật callback để đảm bảo nó được gọi khi thumbnail hoàn thành
        final existingCallbacks = task.onComplete;
        task.onComplete = (String? path) {
          existingCallbacks(path);
          onComplete(path);
        };
        break;
      }
    }

    for (var task in _runningTasks) {
      if (task.videoPath == videoPath) {
        taskExists = true;
        // Cập nhật callback để đảm bảo nó được gọi khi thumbnail hoàn thành
        final existingCallbacks = task.onComplete;
        task.onComplete = (String? path) {
          existingCallbacks(path);
          onComplete(path);
        };
        break;
      }
    }

    // Chỉ thêm tác vụ mới nếu nó chưa tồn tại
    if (!taskExists) {
      _queue.add(_ThumbnailTask(
        videoPath: videoPath,
        onComplete: onComplete,
        priority: priority,
      ));

      // Sắp xếp lại hàng đợi theo độ ưu tiên (cao đến thấp)
      _queue.sort((a, b) => b.priority.compareTo(a.priority));

      // Bắt đầu xử lý hàng đợi nếu chưa chạy
      if (!_isProcessing) {
        _processQueue();
      }
    }
  }

  /// Xử lý hàng đợi và chạy các tác vụ thumbnail
  Future<void> _processQueue() async {
    if (_isProcessing) return;

    _isProcessing = true;

    while (_queue.isNotEmpty && _runningTasks.length < maxConcurrentTasks) {
      // Lấy tác vụ tiếp theo từ hàng đợi
      final task = _queue.removeAt(0);
      _runningTasks.add(task);

      // Chạy tác vụ trong một Future riêng biệt
      unawaited(_generateThumbnail(task).then((_) {
        _runningTasks.remove(task);
        // Tiếp tục xử lý queue nếu còn tác vụ trong hàng đợi
        if (_queue.isNotEmpty) {
          _processQueue();
        }
      }));
    }

    _isProcessing = false;
  }

  /// Tạo thumbnail cho một video cụ thể
  Future<void> _generateThumbnail(_ThumbnailTask task) async {
    try {
      final ffmpeg = FFMpegHelper();
      if (!await ThumbnailHelper.ensureFFmpegInstalled()) {
        task.onComplete(null);
        return;
      }

      // Tạo đường dẫn cho thumbnail
      final String uniqueId = task.videoPath.hashCode.toString();
      final tempDir = await getTemporaryDirectory();
      final thumbnailPath = '${tempDir.path}/thumb_${uniqueId}.jpg';

      // Kiểm tra nếu thumbnail đã tồn tại thì không cần tạo lại
      if (File(thumbnailPath).existsSync()) {
        // Thêm vào cache và gọi callback
        ThumbnailHelper._thumbnailCache[task.videoPath] = thumbnailPath;
        _loadIntoMemoryCache(task.videoPath, thumbnailPath);
        task.onComplete(thumbnailPath);
        return;
      }

      // Tạo thumbnail mới với chất lượng thấp hơn để cải thiện hiệu suất
      await ffmpeg.getThumbnailFileAsync(
        videoPath: task.videoPath,
        fromDuration: const Duration(seconds: 1), // Seek to 1 second
        outputPath: thumbnailPath,
        qualityPercentage:
            thumbnailQuality, // Giảm chất lượng để tạo nhanh hơn và giảm kích thước
        onComplete: (File? outputFile) {
          if (outputFile != null && outputFile.existsSync()) {
            // Thêm vào cache và gọi callback
            ThumbnailHelper._thumbnailCache[task.videoPath] = outputFile.path;
            _loadIntoMemoryCache(task.videoPath, outputFile.path);
            task.onComplete(outputFile.path);
          } else {
            task.onComplete(null);
          }
        },
      );
    } catch (e) {
      debugPrint('Error generating thumbnail: $e');
      task.onComplete(null);
    }
  }

  /// Load thumbnail từ file vào memory cache
  Future<void> _loadIntoMemoryCache(String videoPath, String filePath) async {
    try {
      final file = File(filePath);
      if (!file.existsSync()) return;

      // Đọc file vào memory
      final bytes = await file.readAsBytes();
      _memoryCache[videoPath] = bytes;
    } catch (e) {
      debugPrint('Error loading thumbnail into memory cache: $e');
    }
  }

  /// Lấy thumbnail từ memory cache nếu có
  static Uint8List? getFromMemoryCache(String videoPath) {
    return _memoryCache[videoPath];
  }

  /// Xóa hàng đợi
  void clearQueue() {
    _queue.clear();
  }

  /// Tiền tải thumbnail cho danh sách video đầu tiên
  static Future<void> preloadFirstBatch(List<String> videoPaths,
      {int count = 20}) async {
    final manager = ThumbnailTaskManager();

    // Chỉ preload số lượng giới hạn để tránh quá tải
    final pathsToPreload = videoPaths.take(count).toList();

    // Tạo completer để theo dõi khi nào tất cả thumbnail được tải
    final completer = Completer<void>();
    int remaining = pathsToPreload.length;

    if (pathsToPreload.isEmpty) {
      completer.complete();
      return completer.future;
    }

    for (int i = 0; i < pathsToPreload.length; i++) {
      final videoPath = pathsToPreload[i];

      // Đặt độ ưu tiên giảm dần - những video đầu tiên có độ ưu tiên cao nhất
      final priority = 1000 - i;

      manager.addTask(
          videoPath: videoPath,
          priority: priority,
          onComplete: (_) {
            remaining--;
            if (remaining <= 0) {
              completer.complete();
            }
          });
    }

    // Chờ tối đa 5 giây
    return completer.future.timeout(const Duration(seconds: 5), onTimeout: () {
      // Nếu timeout, vẫn cho phép tiếp tục
      if (!completer.isCompleted) {
        completer.complete();
      }
    });
  }
}

/// Lớp đại diện cho một tác vụ tạo thumbnail
class _ThumbnailTask {
  final String videoPath;
  Function(String?) onComplete;
  final int priority; // Độ ưu tiên, cao hơn = được xử lý trước

  _ThumbnailTask({
    required this.videoPath,
    required this.onComplete,
    this.priority = 0,
  });
}

class ThumbnailHelper {
  // Cache để lưu trữ các thumbnail đã tạo
  static final Map<String, String> _thumbnailCache = {};

  // Trạng thái FFmpeg
  static bool _ffmpegInstalled = false;
  static ValueNotifier<FFMpegProgress?> downloadProgress = ValueNotifier(null);

  /// Kiểm tra nếu FFmpeg đã được cài đặt
  static Future<bool> ensureFFmpegInstalled([BuildContext? context]) async {
    if (_ffmpegInstalled) return true;

    final ffmpeg = FFMpegHelper();
    bool isInstalled = await ffmpeg.isFFmpegInstalled();

    if (isInstalled) {
      _ffmpegInstalled = true;
      return true;
    }

    if (context != null) {
      return await downloadFFmpeg(context, ffmpeg);
    }

    return false;
  }

  /// Tải và cài đặt FFmpeg
  static Future<bool> downloadFFmpeg(
      BuildContext context, FFMpegHelper ffmpeg) async {
    bool success = false;

    if (Platform.isWindows) {
      success = await ffmpeg.setupFFMpegOnWindows(
        onProgress: (FFMpegProgress progress) {
          downloadProgress.value = progress;
        },
      );
      _ffmpegInstalled = success;
    } else if (Platform.isLinux) {
      // Show dialog for Linux installation
      await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Install FFMpeg'),
              content: const Text(
                  'FFmpeg installation required.\n\nPlease install FFmpeg using one of the following commands:\n'
                  'sudo apt-get install ffmpeg\n'
                  'sudo snap install ffmpeg'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('OK'),
                ),
              ],
            );
          });
      // Recheck if FFmpeg is installed after manual installation
      _ffmpegInstalled = await ffmpeg.isFFmpegInstalled();
      success = _ffmpegInstalled;
    } else if (Platform.isMacOS) {
      // Show dialog for macOS installation
      await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Install FFMpeg'),
              content: const Text(
                  'FFmpeg installation required.\n\nPlease install FFmpeg using one of the following commands:\n'
                  'brew install ffmpeg\n'
                  'sudo port install ffmpeg'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('OK'),
                ),
              ],
            );
          });
      // Recheck if FFmpeg is installed after manual installation
      _ffmpegInstalled = await ffmpeg.isFFmpegInstalled();
      success = _ffmpegInstalled;
    } else {
      // Android and iOS should have FFmpeg bundled with the app
      _ffmpegInstalled = await ffmpeg.isFFmpegInstalled();
      success = _ffmpegInstalled;
    }

    return success;
  }

  /// Tạo widget hiển thị thumbnail của video
  static Widget buildVideoThumbnail({
    required String videoPath,
    required Function(String?) onThumbnailGenerated,
    required Widget Function() fallbackBuilder,
    double width = 300,
    double height = 300,
    bool isVisible = true,
  }) {
    final Key videoKey = Key('thumbnail-${videoPath.hashCode}');

    // Kiểm tra memory cache trước tiên
    final memoryData = ThumbnailTaskManager.getFromMemoryCache(videoPath);
    if (memoryData != null) {
      return Image.memory(
        memoryData,
        key: videoKey,
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return fallbackBuilder();
        },
      );
    }

    // Kiểm tra file cache
    if (_thumbnailCache.containsKey(videoPath)) {
      final cachedPath = _thumbnailCache[videoPath];
      if (cachedPath != null && File(cachedPath).existsSync()) {
        onThumbnailGenerated(cachedPath);
        return Image.file(
          File(cachedPath),
          key: videoKey,
          width: width,
          height: height,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            _thumbnailCache.remove(videoPath);
            return fallbackBuilder();
          },
          // Giảm chất lượng giải mã ảnh để tải nhanh hơn
          cacheWidth: ThumbnailTaskManager.maxThumbnailSize,
        );
      } else {
        _thumbnailCache.remove(videoPath);
      }
    }

    if (!isVisible) {
      return Container(
        key: videoKey,
        width: width,
        height: height,
        color: Colors.grey[200],
        child: fallbackBuilder(),
      );
    }

    return OptimizedLazyThumbnailWidget(
      key: videoKey,
      videoPath: videoPath,
      width: width,
      height: height,
      onThumbnailGenerated: (path) {
        if (path != null) {
          _thumbnailCache[videoPath] = path;
        }
        onThumbnailGenerated(path);
      },
      fallbackBuilder: fallbackBuilder,
    );
  }

  /// Xóa toàn bộ cache thumbnail
  static void clearCache() {
    _thumbnailCache.clear();
  }
}

class OptimizedLazyThumbnailWidget extends StatefulWidget {
  final String videoPath;
  final double width;
  final double height;
  final Function(String?) onThumbnailGenerated;
  final Widget Function() fallbackBuilder;

  const OptimizedLazyThumbnailWidget({
    Key? key,
    required this.videoPath,
    required this.width,
    required this.height,
    required this.onThumbnailGenerated,
    required this.fallbackBuilder,
  }) : super(key: key);

  @override
  _OptimizedLazyThumbnailWidgetState createState() =>
      _OptimizedLazyThumbnailWidgetState();
}

class _OptimizedLazyThumbnailWidgetState
    extends State<OptimizedLazyThumbnailWidget> {
  String? _thumbnailPath;
  bool _hasError = false;
  bool _isGenerating = false;
  bool _requestedThumbnail = false;

  @override
  void initState() {
    super.initState();
    _requestThumbnail();
  }

  void _requestThumbnail() {
    if (_isGenerating || _requestedThumbnail) return;

    setState(() {
      _isGenerating = true;
      _requestedThumbnail = true;
    });

    ThumbnailTaskManager().addTask(
      videoPath: widget.videoPath,
      onComplete: (thumbnailPath) {
        if (mounted) {
          setState(() {
            _thumbnailPath = thumbnailPath;
            _hasError = thumbnailPath == null;
            _isGenerating = false;
          });
          widget.onThumbnailGenerated(thumbnailPath);
        }
      },
      // Đặt priority dựa trên hash để không bị xung đột
      priority: 1000 -
          int.parse(widget.videoPath.hashCode
              .toString()
              .replaceAll('-', '')
              .substring(0, 3)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return widget.fallbackBuilder();
    }

    // Kiểm tra xem có sẵn trong memory cache không
    final memoryData =
        ThumbnailTaskManager.getFromMemoryCache(widget.videoPath);
    if (memoryData != null) {
      return Image.memory(
        memoryData,
        width: widget.width,
        height: widget.height,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return widget.fallbackBuilder();
        },
      );
    }

    if (_thumbnailPath != null) {
      return Image.file(
        File(_thumbnailPath!),
        width: widget.width,
        height: widget.height,
        fit: BoxFit.cover,
        // Giảm chất lượng giải mã ảnh để tải nhanh hơn
        cacheWidth: ThumbnailTaskManager.maxThumbnailSize,
        errorBuilder: (context, error, stackTrace) {
          return widget.fallbackBuilder();
        },
      );
    }

    // Trạng thái đang tải
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(4),
      ),
      child: Stack(
        children: [
          widget.fallbackBuilder(),
          if (_isGenerating)
            Center(
              child: SizedBox(
                width: 20, // Nhỏ hơn để ít chiếm không gian hơn
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
