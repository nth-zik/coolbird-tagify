import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path_util;
import 'package:ffmpeg_helper/ffmpeg_helper.dart';
import 'package:path_provider/path_provider.dart';
import 'ffmpeg_extensions.dart'; // Import the extensions

class ThumbnailHelper {
  // Cache for storing generated thumbnails
  static final Map<String, String> _thumbnailCache = {};

  // Track FFmpeg installation status
  static bool _ffmpegInstalled = false;
  static ValueNotifier<FFMpegProgress?> downloadProgress = ValueNotifier(null);

  /// Check if FFmpeg is installed or download/setup if needed
  static Future<bool> ensureFFmpegInstalled(BuildContext context) async {
    if (_ffmpegInstalled) return true;

    final ffmpeg = FFMpegHelper();
    bool isInstalled = await ffmpeg.isFFmpegInstalled();

    if (isInstalled) {
      _ffmpegInstalled = true;
      return true;
    }

    return await downloadFFmpeg(context, ffmpeg);
  }

  /// Download and setup FFmpeg based on platform
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

  /// Show FFmpeg download progress dialog
  static Future<void> showFFmpegDownloadDialog(BuildContext context) async {
    await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Downloading FFmpeg'),
            content: ValueListenableBuilder<FFMpegProgress?>(
                valueListenable: downloadProgress,
                builder: (context, progress, _) {
                  if (progress == null) {
                    return const LinearProgressIndicator();
                  }

                  // Instead of accessing specific properties, display a simple progress indicator
                  // This avoids errors with unknown property names
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Downloading FFmpeg components...'),
                      const SizedBox(height: 10),
                      // Use indeterminate progress indicator since we can't reliably access the progress value
                      const LinearProgressIndicator(),
                      const SizedBox(height: 10),
                      // Display any available progress information in a more descriptive way
                      Text('Please wait while FFmpeg is being downloaded...'),
                    ],
                  );
                }),
            actions: [
              TextButton(
                onPressed: () {
                  // Optionally allow canceling the dialog
                  Navigator.of(context).pop();
                },
                child: const Text('Cancel'),
              ),
            ],
          );
        });
  }

  static Widget buildVideoThumbnail({
    required String videoPath,
    required Function(String?) onThumbnailGenerated,
    required Widget Function() fallbackBuilder,
    double width = 300,
    double height = 300,
  }) {
    // Check cache first
    if (_thumbnailCache.containsKey(videoPath)) {
      final cachedPath = _thumbnailCache[videoPath];
      if (cachedPath != null && File(cachedPath).existsSync()) {
        onThumbnailGenerated(cachedPath);
        return Image.file(
          File(cachedPath),
          width: width,
          height: height,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => fallbackBuilder(),
        );
      }
    }

    return FFmpegThumbnailWidget(
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

  static void clearCache() {
    _thumbnailCache.clear();
  }
}

class FFmpegThumbnailWidget extends StatefulWidget {
  final String videoPath;
  final double width;
  final double height;
  final Function(String?) onThumbnailGenerated;
  final Widget Function() fallbackBuilder;

  const FFmpegThumbnailWidget({
    Key? key,
    required this.videoPath,
    required this.width,
    required this.height,
    required this.onThumbnailGenerated,
    required this.fallbackBuilder,
  }) : super(key: key);

  @override
  _FFmpegThumbnailWidgetState createState() => _FFmpegThumbnailWidgetState();
}

class _FFmpegThumbnailWidgetState extends State<FFmpegThumbnailWidget> {
  String? _thumbnailPath;
  bool _hasError = false;
  bool _isGenerating = true;
  String? _extension;
  FFMpegHelper? _ffmpeg;

  @override
  void initState() {
    super.initState();
    _extension = path_util.extension(widget.videoPath).toLowerCase();
    _initFFmpeg();
  }

  Future<void> _initFFmpeg() async {
    try {
      // Check if FFmpeg is installed first
      if (!await ThumbnailHelper.ensureFFmpegInstalled(context)) {
        throw Exception('FFmpeg is not installed or setup failed');
      }

      _ffmpeg = FFMpegHelper();
      await _generateThumbnail();
    } catch (e) {
      debugPrint('Error initializing FFmpeg: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _isGenerating = false;
        });
        widget.onThumbnailGenerated(null);
      }
    }
  }

  Future<void> _generateThumbnail() async {
    try {
      if (_ffmpeg == null) {
        throw Exception('FFmpeg helper not initialized');
      }

      // Create output thumbnail path
      final tempDir = await getTemporaryDirectory();
      final thumbnailPath =
          '${tempDir.path}/thumbnail_${DateTime.now().millisecondsSinceEpoch}.jpg';

      // Use the new getThumbnailFileAsync method
      await _ffmpeg!.getThumbnailFileAsync(
        videoPath: widget.videoPath,
        fromDuration: const Duration(seconds: 1), // Seek to 1 second
        outputPath: thumbnailPath,
        qualityPercentage: 90, // High quality (90%)
        statisticsCallback: (Statistics statistics) {
          // Optionally handle statistics
          debugPrint('FFmpeg progress - bitrate: ${statistics.getBitrate()}');
        },
        onComplete: (File? outputFile) {
          if (outputFile != null && outputFile.existsSync()) {
            if (mounted) {
              setState(() {
                _thumbnailPath = outputFile.path;
                _isGenerating = false;
              });
              widget.onThumbnailGenerated(outputFile.path);
            }
          } else {
            throw Exception('FFmpeg failed to generate thumbnail');
          }
        },
      );
    } catch (e) {
      debugPrint('Error generating thumbnail with FFmpeg: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _isGenerating = false;
        });
        widget.onThumbnailGenerated(null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return _buildFallbackWidget();
    }

    if (_thumbnailPath != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Stack(
          children: [
            // Thumbnail image
            Image.file(
              File(_thumbnailPath!),
              width: widget.width,
              height: widget.height,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                debugPrint('Error loading thumbnail: $error');
                return _buildFallbackWidget();
              },
            ),

            // File name overlay at top
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                color: Colors.black54,
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                child: Text(
                  path_util.basename(widget.videoPath),
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),

            // File info overlay at bottom
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildFileInfo(),
            ),
          ],
        ),
      );
    }

    // Loading state
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: Colors.black12,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Stack(
        children: [
          if (_isGenerating)
            const Center(
              child: SizedBox(
                width: 30,
                height: 30,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              ),
            ),
          // File name overlay at top
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              color: Colors.black54,
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              child: Text(
                path_util.basename(widget.videoPath),
                style: const TextStyle(color: Colors.white, fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFallbackWidget() {
    return Container(
      width: widget.width,
      height: widget.height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _getGradientColors(_extension ?? ''),
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: Icon(
              _getVideoTypeIcon(_extension ?? ''),
              size: widget.width * 0.3,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              color: Colors.black54,
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              child: Text(
                path_util.basename(widget.videoPath),
                style: const TextStyle(color: Colors.white, fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildFileInfo(),
          ),
        ],
      ),
    );
  }

  Widget _buildFileInfo() {
    return FutureBuilder<FileStat>(
      future: File(widget.videoPath).stat(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Container(
            color: Colors.black54,
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            child: const Text(
              'Loading info...',
              style: TextStyle(color: Colors.white70, fontSize: 10),
            ),
          );
        }

        final fileSize = _formatFileSize(snapshot.data!.size);
        final modified = snapshot.data!.modified;

        return Container(
          color: Colors.black54,
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                fileSize,
                style: const TextStyle(color: Colors.white, fontSize: 10),
              ),
              Text(
                _formatDate(modified),
                style: const TextStyle(color: Colors.white70, fontSize: 9),
              ),
            ],
          ),
        );
      },
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

  String _formatFileSize(int bytes) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB"];
    var i = (math.log(bytes) / math.log(1024)).floor();
    return '${(bytes / math.pow(1024, i)).toStringAsFixed(1)} ${suffixes[i]}';
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${_twoDigits(date.hour)}:${_twoDigits(date.minute)}';
  }

  String _twoDigits(int n) {
    if (n >= 10) return "$n";
    return "0$n";
  }
}
