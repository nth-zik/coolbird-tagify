import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:cb_file_manager/helpers/filesystem_utils.dart';
import 'package:path/path.dart' as pathlib;
import 'package:cb_file_manager/helpers/thumbnail_helper.dart';
import 'dart:async';
import 'dart:math';
import 'package:flutter/services.dart';

class VideoGalleryScreen extends StatefulWidget {
  final String path;
  final bool recursive;

  const VideoGalleryScreen({
    Key? key,
    required this.path,
    this.recursive = true,
  }) : super(key: key);

  @override
  _VideoGalleryScreenState createState() => _VideoGalleryScreenState();
}

class _VideoGalleryScreenState extends State<VideoGalleryScreen> {
  late Future<List<File>> _videoFilesFuture;

  @override
  void initState() {
    super.initState();
    _loadVideos();
  }

  void _loadVideos() {
    _videoFilesFuture = getAllVideos(widget.path, recursive: widget.recursive);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Video Gallery: ${pathlib.basename(widget.path)}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _loadVideos();
              });
            },
          ),
        ],
      ),
      body: FutureBuilder<List<File>>(
        future: _videoFilesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'Error: ${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.red[700]),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _loadVideos();
                      });
                    },
                    child: const Text('Thử lại'),
                  ),
                ],
              ),
            );
          }

          final videos = snapshot.data ?? [];

          if (videos.isEmpty) {
            return const Center(
              child: Text(
                'Không tìm thấy video trong thư mục này',
                style: TextStyle(fontSize: 16),
              ),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(8.0),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 16 / 12, // Video thumbnail aspect ratio
            ),
            itemCount: videos.length,
            itemBuilder: (context, index) {
              final file = videos[index];
              return VideoThumbnailItem(
                file: file,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => VideoPlayerFullScreen(file: file),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class VideoThumbnailItem extends StatefulWidget {
  final File file;
  final VoidCallback onTap;

  const VideoThumbnailItem({
    Key? key,
    required this.file,
    required this.onTap,
  }) : super(key: key);

  @override
  _VideoThumbnailItemState createState() => _VideoThumbnailItemState();
}

class _VideoThumbnailItemState extends State<VideoThumbnailItem> {
  bool _thumbnailLoaded = false;

  void _onThumbnailGenerated(String? path) {
    if (!_thumbnailLoaded && mounted) {
      setState(() {
        _thumbnailLoaded = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final String ext = pathlib.extension(widget.file.path).toLowerCase();

    return GestureDetector(
      onTap: widget.onTap,
      child: Card(
        clipBehavior: Clip.antiAlias,
        elevation: 2,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Sử dụng ThumbnailHelper với video_thumbnail_imageview
            ThumbnailHelper.buildVideoThumbnail(
              videoPath: widget.file.path,
              onThumbnailGenerated: _onThumbnailGenerated,
              fallbackBuilder: () => _buildFallbackThumbnail(ext),
            ),

            // Play button overlay
            Center(
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ),

            // Video name at the bottom
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                color: Colors.black.withOpacity(0.7),
                padding: const EdgeInsets.all(8),
                child: Text(
                  pathlib.basename(widget.file.path),
                  style: const TextStyle(color: Colors.white),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
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
          size: 48,
          color: Colors.white.withOpacity(0.7),
        ),
      ),
    );
  }

  // Get video icon based on extension
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

  // Get gradient colors based on video type
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
  late VideoPlayerController _videoPlayerController;
  ChewieController? _chewieController;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });

      _videoPlayerController = VideoPlayerController.file(widget.file);

      // Add error listener to catch initialization errors
      _videoPlayerController.addListener(_videoPlayerListener);

      // Initialize the video player with a longer timeout
      await _videoPlayerController.initialize().timeout(
            const Duration(seconds: 30),
            onTimeout: () => throw TimeoutException(
                'Video initialization timed out after 30 seconds'),
          );

      // Check if video initialized successfully
      if (!_videoPlayerController.value.isInitialized) {
        throw Exception('Failed to initialize video player');
      }

      // Create chewie controller with default options
      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController,
        autoPlay: true,
        looping: false,
        // Don't set aspect ratio if we have a valid one from the video
        aspectRatio: _videoPlayerController.value.aspectRatio > 0
            ? _videoPlayerController.value.aspectRatio
            : 16 / 9,
        allowFullScreen: true,
        allowMuting: true,
        allowPlaybackSpeedChanging: true,
        placeholder: Center(
          child: CircularProgressIndicator(),
        ),
        materialProgressColors: ChewieProgressColors(
          playedColor: Colors.red,
          handleColor: Colors.red,
          backgroundColor: Colors.grey,
          bufferedColor: Colors.white,
        ),
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error, color: Colors.white, size: 42),
                const SizedBox(height: 16),
                Text(
                  'Lỗi phát video: $errorMessage',
                  style: const TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('Quay lại'),
                ),
              ],
            ),
          );
        },
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error initializing video player: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
    }
  }

  void _videoPlayerListener() {
    // If we get an error during playback, update the UI
    if (_videoPlayerController.value.hasError && !_hasError) {
      setState(() {
        _hasError = true;
        _errorMessage = _videoPlayerController.value.errorDescription ??
            'Unknown video error';
      });
    }
  }

  @override
  void dispose() {
    _videoPlayerController.removeListener(_videoPlayerListener);
    _videoPlayerController.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(pathlib.basename(widget.file.path)),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showVideoInfo(context),
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Colors.white),
              )
            : _hasError
                ? _buildErrorWidget()
                : Center(
                    child: _chewieController != null
                        ? Chewie(controller: _chewieController!)
                        : const Text('Không thể khởi tạo trình phát video',
                            style: TextStyle(color: Colors.white)),
                  ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            color: Colors.red,
            size: 60,
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Không thể phát video này\n\n$_errorMessage',
              style: const TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _isLoading = true;
                _hasError = false;
                _initializePlayer();
              });
            },
            child: const Text('Thử lại'),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child:
                const Text('Quay lại', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showVideoInfo(BuildContext context) async {
    try {
      var fileStat = await widget.file.stat();
      var fileSize = fileStat.size;
      var modified = fileStat.modified;

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Thông tin video'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _infoRow('Tên tập tin', pathlib.basename(widget.file.path)),
                  const Divider(),
                  _infoRow('Đường dẫn', widget.file.path),
                  const Divider(),
                  _infoRow('Kích thước', _formatFileSize(fileSize)),
                  const Divider(),
                  _infoRow('Cập nhật lần cuối',
                      '${modified.day}/${modified.month}/${modified.year} ${modified.hour}:${modified.minute}'),
                  if (_videoPlayerController.value.isInitialized) ...[
                    const Divider(),
                    _infoRow('Độ dài',
                        _formatDuration(_videoPlayerController.value.duration)),
                    const Divider(),
                    _infoRow('Độ phân giải',
                        '${_videoPlayerController.value.size.width.toInt()} x ${_videoPlayerController.value.size.height.toInt()}'),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('Đóng'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      print('Error showing video info: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể hiển thị thông tin video: $e')),
      );
    }
  }

  Widget _infoRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$title: ',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }

  String _formatFileSize(int bytes) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB"];
    var i = (log(bytes) / log(1024)).floor();
    return '${(bytes / pow(1024, i)).toStringAsFixed(1)} ${suffixes[i]}';
  }
}
