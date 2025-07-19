import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:cb_file_manager/services/network_browsing/smb_service.dart';
import 'package:cb_file_manager/ui/components/video_player/custom_video_player.dart';
import 'package:cb_file_manager/helpers/app_path_helper.dart';

// Helper model to hold file info for temp cleanup
class _FileInfo {
  final File file;
  final int size;
  final DateTime modified;

  _FileInfo({required this.file, required this.size, required this.modified});
}

class SmbVideoPlayerScreen extends StatefulWidget {
  final SMBService service;
  final String tabFilePath; // e.g. #network/SMB/host/share/file.mp4

  const SmbVideoPlayerScreen(
      {Key? key, required this.service, required this.tabFilePath})
      : super(key: key);

  @override
  State<SmbVideoPlayerScreen> createState() => _SmbVideoPlayerScreenState();

  // Static method for instant navigation - prebuilds the route
  static Route<void> createRoute(SMBService service, String tabFilePath) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) =>
          SmbVideoPlayerScreen(
        service: service,
        tabFilePath: tabFilePath,
      ),
      transitionDuration: Duration.zero, // No animation for instant feel
      reverseTransitionDuration:
          const Duration(milliseconds: 200), // Quick back animation
    );
  }
}

class _SmbVideoPlayerScreenState extends State<SmbVideoPlayerScreen>
    with TickerProviderStateMixin {
  File? _tempVideoFile;
  bool _isDownloading = true;
  bool _hasError = false;
  bool _canStartPlayback = false;
  // We rely on CustomVideoPlayer's internal loading state, no separate readiness flag needed.
  String? _errorMessage;
  double _downloadProgress = 0.0;
  int _bytesDownloaded = 0;
  int? _estimatedFileSize;
  Timer? _progressUpdateTimer;
  StreamSubscription? _downloadSubscription;

  // Use our CustomVideoPlayer for consistent UI
  File? _videoFile;

  late AnimationController _pulseController;
  late AnimationController _slideController;
  late Animation<double> _pulseAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize minimal animations for better performance
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 800), // Faster animation
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 200), // Much faster slide
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      // Smaller range
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero).animate(
      // Smaller offset
      CurvedAnimation(parent: _slideController, curve: Curves.easeOut),
    );

    _pulseController.repeat(reverse: true);
    _slideController.forward();

    // Initialize direct UNC playback
    _initializeDirectPlayback();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _slideController.dispose();
    _progressUpdateTimer?.cancel();
    _downloadSubscription?.cancel();
    // Nothing to dispose for CustomVideoPlayer here
    super.dispose();
  }

  // Get the unified temp_files directory managed by AppPathHelper
  Future<Directory> _getAppTempDir() async {
    return await AppPathHelper.getTempFilesDir();
  }

  // Keep temp dir size under 1 GB by deleting oldest files first
  Future<void> _cleanupTempDir({int maxBytes = 1073741824}) async {
    final dir = await _getAppTempDir();
    final entities =
        await dir.list(recursive: false, followLinks: false).toList();
    final files = entities.whereType<File>().toList();

    int totalSize = 0;
    final fileInfos = <_FileInfo>[];

    for (final f in files) {
      try {
        final stat = await f.stat();
        totalSize += stat.size;
        fileInfos
            .add(_FileInfo(file: f, size: stat.size, modified: stat.modified));
      } catch (_) {}
    }

    if (totalSize <= maxBytes) return; // Already within limit

    // Sort by last modified (oldest first)
    fileInfos.sort((a, b) => a.modified.compareTo(b.modified));

    for (final info in fileInfos) {
      try {
        await info.file.delete();
        totalSize -= info.size;
        if (totalSize <= maxBytes) break;
      } catch (_) {}
    }
  }

  // Convert tabFilePath to UNC path (similar logic to SMBService)
  String _toUncPath(String tabPath) {
    final lowerPath = tabPath.toLowerCase();
    if (!lowerPath.startsWith('#network/smb/')) return tabPath;

    final pathWithoutPrefix = tabPath.substring('#network/'.length);
    final parts =
        pathWithoutPrefix.split('/').where((p) => p.isNotEmpty).toList();
    if (parts.length < 3) return tabPath; // scheme + host + share

    final host = Uri.decodeComponent(parts[1]);
    final share = Uri.decodeComponent(parts[2]);
    List<String> folders = [];
    if (parts.length > 3) {
      folders = parts.sublist(3).map((e) {
        try {
          return Uri.decodeComponent(e);
        } catch (_) {
          return e;
        }
      }).toList();
    }
    final folderPart = folders.isNotEmpty ? '\\' + folders.join('\\') : '';
    return '\\\\$host\\$share$folderPart';
  }

  void _initializeDirectPlayback() async {
    try {
      final uncPath = _toUncPath(widget.tabFilePath);
      setState(() {
        _videoFile = File(uncPath);
      });
    } catch (e) {
      debugPrint('Direct UNC playback error: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
    }
  }

  String _getLocalizedErrorMessage(dynamic error) {
    final errorStr = error.toString().toLowerCase();

    if (errorStr.contains('connection') || errorStr.contains('network')) {
      return 'Lỗi kết nối mạng. Vui lòng kiểm tra kết nối internet.';
    } else if (errorStr.contains('permission') || errorStr.contains('access')) {
      return 'Không có quyền truy cập file. Vui lòng kiểm tra quyền.';
    } else if (errorStr.contains('not found') || errorStr.contains('404')) {
      return 'Không tìm thấy file. File có thể đã bị xóa hoặc di chuyển.';
    } else if (errorStr.contains('timeout')) {
      return 'Quá thời gian chờ. Vui lòng thử lại.';
    } else {
      return 'Có lỗi xảy ra: ${error.toString()}';
    }
  }

  Future<void> _estimateFileSize() async {
    try {
      final fileSize = await widget.service.getFileSize(widget.tabFilePath);
      if (fileSize != null && mounted) {
        setState(() {
          _estimatedFileSize = fileSize;
        });
      }
    } catch (e) {
      debugPrint('Could not estimate file size: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withOpacity(0.8),
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        title: Text(
          p.basename(widget.tabFilePath),
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: _buildContent(), // Remove SlideTransition for instant display
      ),
    );
  }

  Widget _buildContent() {
    if (_hasError) {
      return _buildErrorWidget();
    }

    if (_videoFile != null) {
      return _buildVideoPlayer();
    }

    return const Center(child: CircularProgressIndicator());
  }

  Widget _buildVideoPlayer() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      child: CustomVideoPlayer(
        file: _videoFile!,
        autoPlay: true,
      ),
    );
  }

  // Download widget no longer used

  Widget _buildErrorWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 60,
            ),
            const SizedBox(height: 20),
            const Text(
              'Không thể tải video',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _errorMessage ?? 'Lỗi không xác định',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 14,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Quay lại'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: BorderSide(color: Colors.white.withOpacity(0.3)),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _hasError = false;
                      _isDownloading = true;
                      _canStartPlayback = false;
                      _tempVideoFile = null; // Clear temp file
                      _downloadProgress = 0.0;
                      _bytesDownloaded = 0;
                    });
                    _pulseController.repeat(reverse: true);
                    _initializeDirectPlayback();
                  },
                  child: const Text('Thử lại'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    if (bytes < 1024 * 1024 * 1024)
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }
}
