import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:cb_file_manager/helpers/filesystem_utils.dart';
import 'package:path/path.dart' as pathlib;
import 'package:cb_file_manager/helpers/thumbnail_helper.dart';
import 'package:cb_file_manager/helpers/user_preferences.dart';
import 'package:cb_file_manager/ui/utils/base_screen.dart';
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

class _VideoGalleryScreenState extends State<VideoGalleryScreen>
    with AutomaticKeepAliveClientMixin {
  late Future<List<File>> _videoFilesFuture;
  late UserPreferences _preferences;
  late double _thumbnailSize;
  ScrollController _scrollController = ScrollController();
  bool _isLoadingThumbnails = false;
  bool _isMounted = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _preferences = UserPreferences();
    _loadPreferences();
    _loadVideos();
    _isMounted = true;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _isMounted = false;
    super.dispose();
  }

  Future<void> _loadPreferences() async {
    await _preferences.init();
    if (_isMounted) {
      setState(() {
        _thumbnailSize = _preferences.getVideoGalleryThumbnailSize();
      });
    }
  }

  void _loadVideos() {
    _videoFilesFuture = getAllVideos(widget.path, recursive: widget.recursive);

    _videoFilesFuture.then((videos) {
      if (videos.isNotEmpty && _isMounted) {
        setState(() {
          _isLoadingThumbnails = true;
        });

        final videoPaths = videos.map((file) => file.path).toList();

        ThumbnailTaskManager.preloadFirstBatch(videoPaths, count: 20).then((_) {
          if (_isMounted) {
            setState(() {
              _isLoadingThumbnails = false;
            });
          }
        });
      }
    });
  }

  double _calculateThumbnailSize(BuildContext context, int columns) {
    final screenWidth = MediaQuery.of(context).size.width;
    final availableWidth = screenWidth - 16 - ((columns - 1) * 8);
    return availableWidth / columns;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return BaseScreen(
      title: 'Video Gallery: ${pathlib.basename(widget.path)}',
      actions: [
        IconButton(
          icon: const Icon(Icons.photo_size_select_large),
          onPressed: () {
            _showThumbnailSizeDialog();
          },
        ),
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: () {
            setState(() {
              _loadVideos();
            });
          },
        ),
      ],
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

          final columns = _thumbnailSize.round();
          final thumbnailSize = _calculateThumbnailSize(context, columns);

          return Stack(
            children: [
              GridView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(8.0),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 16 / 12,
                ),
                itemCount: videos.length,
                itemBuilder: (context, index) {
                  final file = videos[index];

                  return OptimizedVideoThumbnailItem(
                    file: file,
                    width: thumbnailSize,
                    height: thumbnailSize * 12 / 16,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              VideoPlayerFullScreen(file: file),
                        ),
                      );
                    },
                  );
                },
              ),
              if (_isLoadingThumbnails)
                Positioned(
                  bottom: 16,
                  right: 16,
                  child: Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Đang tải thumbnail',
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  void _showThumbnailSizeDialog() {
    double tempSize = _thumbnailSize;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Điều chỉnh kích thước thumbnail'),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Số cột: ${tempSize.round()}'),
                  Slider(
                    value: tempSize,
                    min: UserPreferences.minThumbnailSize,
                    max: UserPreferences.maxThumbnailSize,
                    divisions: (UserPreferences.maxThumbnailSize -
                            UserPreferences.minThumbnailSize)
                        .toInt(),
                    label: tempSize.round().toString(),
                    onChanged: (double value) {
                      setState(() {
                        tempSize = value;
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _sizePreviewBox(2, tempSize),
                      _sizePreviewBox(3, tempSize),
                      _sizePreviewBox(4, tempSize),
                      _sizePreviewBox(5, tempSize),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _sizePreviewBox(6, tempSize),
                      _sizePreviewBox(7, tempSize),
                      _sizePreviewBox(8, tempSize),
                      _sizePreviewBox(10, tempSize),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Text('Lớn hơn', style: TextStyle(fontSize: 12)),
                      const Spacer(),
                      Text('Nhỏ hơn', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ],
              );
            },
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Huỷ'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Áp dụng'),
              onPressed: () {
                setState(() {
                  _thumbnailSize = tempSize;
                });
                _preferences.setVideoGalleryThumbnailSize(tempSize);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Widget _sizePreviewBox(int size, double currentSize) {
    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          padding: EdgeInsets.all(2),
          decoration: BoxDecoration(
            border: Border.all(
              color: currentSize.round() == size ? Colors.blue : Colors.grey,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(4),
          ),
          child: GridView.count(
            crossAxisCount: size,
            mainAxisSpacing: 1,
            crossAxisSpacing: 1,
            physics: NeverScrollableScrollPhysics(),
            children: List.generate(
              size * size,
              (index) => Container(
                color: Colors.grey[300],
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$size',
          style: TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('About CoolBird File Manager'),
          content: const Text(
              'CoolBird File Manager is a powerful tool for managing your files and videos.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Close'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}

class OptimizedVideoThumbnailItem extends StatelessWidget {
  final File file;
  final VoidCallback onTap;
  final double width;
  final double height;

  const OptimizedVideoThumbnailItem({
    Key? key,
    required this.file,
    required this.onTap,
    this.width = 120,
    this.height = 90,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final String ext = pathlib.extension(file.path).toLowerCase();

    return GestureDetector(
      onTap: onTap,
      child: Card(
        clipBehavior: Clip.antiAlias,
        elevation: 2,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ThumbnailHelper.buildVideoThumbnail(
              videoPath: file.path,
              width: width,
              height: height,
              isVisible: true,
              onThumbnailGenerated: (_) {},
              fallbackBuilder: () => _buildFallbackThumbnail(ext),
            ),
            Center(
              child: Container(
                padding: EdgeInsets.all(width > 100 ? 8 : 6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.play_arrow,
                  color: Colors.white,
                  size: width > 100 ? 32 : 24,
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                color: Colors.black.withOpacity(0.7),
                padding: EdgeInsets.all(width > 100 ? 8 : 4),
                child: Text(
                  pathlib.basename(file.path),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: width > 100 ? 12 : 10,
                  ),
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
          size: width > 100 ? 48 : 32,
          color: Colors.white.withOpacity(0.7),
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

      _videoPlayerController.addListener(_videoPlayerListener);

      await _videoPlayerController.initialize().timeout(
            const Duration(seconds: 30),
            onTimeout: () => throw TimeoutException(
                'Video initialization timed out after 30 seconds'),
          );

      if (!_videoPlayerController.value.isInitialized) {
        throw Exception('Failed to initialize video player');
      }

      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController,
        autoPlay: true,
        looping: false,
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
    return BaseScreen(
      title: pathlib.basename(widget.file.path),
      backgroundColor: Colors.black,
      actions: [
        IconButton(
          icon: const Icon(Icons.info_outline),
          onPressed: () => _showVideoInfo(context),
        ),
      ],
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
