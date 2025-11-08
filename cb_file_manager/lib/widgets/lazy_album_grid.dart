import 'package:flutter/material.dart';
import 'dart:async';
import '../services/optimized_album_service.dart';
import '../services/album_file_scanner.dart';
import 'package:cb_file_manager/ui/widgets/thumbnail_loader.dart';

class LazyAlbumGrid extends StatefulWidget {
  final int albumId;
  final String albumName;

  const LazyAlbumGrid({
    Key? key,
    required this.albumId,
    required this.albumName,
  }) : super(key: key);

  @override
  State<LazyAlbumGrid> createState() => _LazyAlbumGridState();
}

class _LazyAlbumGridState extends State<LazyAlbumGrid> {
  final OptimizedAlbumService _albumService = OptimizedAlbumService.instance;
  StreamSubscription<List<FileInfo>>? _filesSubscription;
  List<FileInfo> _files = [];
  bool _isScanning = false;
  double _scanProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  void _loadFiles() {
    // Get immediate files first (cached)
    final immediateFiles = _albumService.getImmediateFiles(widget.albumId);
    if (immediateFiles.isNotEmpty) {
      setState(() {
        _files = immediateFiles;
      });
    }

    // Start lazy loading stream
    _filesSubscription = _albumService.getLazyAlbumFiles(widget.albumId).listen(
      (files) {
        setState(() {
          _files = files;
          _isScanning = _albumService.isAlbumScanning(widget.albumId);
          _scanProgress = _albumService.getAlbumScanProgress(widget.albumId);
        });
      },
      onError: (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading files: $error')),
        );
      },
    );
  }

  @override
  void dispose() {
    _filesSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    // Target ~120 logical px tile width on mobile, clamp crossAxisCount 2..6
    final targetTileWidth = 120.0;
    final crossAxisCount = size.width > 0
        ? (size.width / targetTileWidth).floor().clamp(2, 6)
        : 3;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.albumName),
        actions: [
          if (_isScanning)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  value: _scanProgress > 0 ? _scanProgress : null,
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshAlbum,
          ),
        ],
      ),
      body: Column(
        children: [
          // Progress indicator
          if (_isScanning)
            Container(
              padding: const EdgeInsets.all(8.0),
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              child: Row(
                children: [
                  const Icon(Icons.search, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Loading files... ${_files.length} found',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  if (_scanProgress > 0)
                    Text(
                      '${(_scanProgress * 100).toInt()}%',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
          
          // File count
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Text(
                  '${_files.length} files',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                if (_files.isNotEmpty)
                  Text(
                    _isScanning ? 'Loading more...' : 'Complete',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: _isScanning ? Colors.orange : Colors.green,
                    ),
                  ),
              ],
            ),
          ),

          // Files grid
          Expanded(
            child: _files.isEmpty && !_isScanning
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.photo_library_outlined, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('No files found'),
                        SizedBox(height: 8),
                        Text('Add some directories to this album', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 6,
                      mainAxisSpacing: 6,
                      childAspectRatio: 1.0,
                    ),
                    itemCount: _files.length,
                    itemBuilder: (context, index) {
                      final file = _files[index];
                      return _buildFileItem(file, index);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileItem(FileInfo file, int index) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Unified thumbnail loader for images/videos
          ThumbnailLoader(
            filePath: file.path,
            isVideo: file.isVideo,
            isImage: file.isImage,
            fit: BoxFit.cover,
            showLoadingIndicator: true,
            borderRadius: BorderRadius.circular(10),
            fallbackBuilder: () => Container(
              color: Colors.grey[200],
              child: Icon(
                file.isVideo
                    ? Icons.play_circle_outline
                    : (file.isImage
                        ? Icons.broken_image
                        : Icons.insert_drive_file),
                color: Colors.grey[600],
                size: 28,
              ),
            ),
          ),

          // Subtle gradient only on hover/press would be ideal; keep minimal always-on footer for readability
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.45)],
                ),
              ),
              child: Text(
                file.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),

          // Badge indicating new items while scanning
          if (index >= _files.length - 20 && _isScanning)
            Positioned(
              top: 6,
              right: 6,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.fiber_new, color: Colors.white, size: 12),
              ),
            ),
        ],
      ),
    );
  }

  void _refreshAlbum() async {
    await _albumService.refreshAlbum(widget.albumId);
    
    // Show feedback
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Album refreshed - files will load progressively'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
}
