import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cb_file_manager/helpers/filesystem_utils.dart';
import 'package:cb_file_manager/helpers/user_preferences.dart';
import 'package:cb_file_manager/ui/utils/base_screen.dart';
import 'package:path/path.dart' as pathlib;

class ImageGalleryScreen extends StatefulWidget {
  final String path;
  final bool recursive;

  const ImageGalleryScreen({
    Key? key,
    required this.path,
    this.recursive = true,
  }) : super(key: key);

  @override
  _ImageGalleryScreenState createState() => _ImageGalleryScreenState();
}

class _ImageGalleryScreenState extends State<ImageGalleryScreen> {
  late Future<List<File>> _imageFilesFuture;
  late UserPreferences _preferences;
  late double _thumbnailSize;

  @override
  void initState() {
    super.initState();
    _preferences = UserPreferences();
    _loadPreferences();
    _loadImages();
  }

  Future<void> _loadPreferences() async {
    await _preferences.init();
    setState(() {
      _thumbnailSize = _preferences.getImageGalleryThumbnailSize();
    });
  }

  void _loadImages() {
    _imageFilesFuture = getAllImages(widget.path, recursive: widget.recursive);
  }

  @override
  Widget build(BuildContext context) {
    return BaseScreen(
      title: 'Image Gallery: ${pathlib.basename(widget.path)}',
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
              _loadImages();
            });
          },
        ),
      ],
      body: FutureBuilder<List<File>>(
        future: _imageFilesFuture,
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
                        _loadImages();
                      });
                    },
                    child: const Text('Try Again'),
                  ),
                ],
              ),
            );
          }

          final images = snapshot.data ?? [];

          if (images.isEmpty) {
            return const Center(
              child: Text(
                'No images found in this location',
                style: TextStyle(fontSize: 16),
              ),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(8.0),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: _thumbnailSize.round(),
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: images.length,
            itemBuilder: (context, index) {
              final file = images[index];
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => _ImageViewerScreen(file: file),
                    ),
                  );
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    color: Colors.grey[200],
                    child: Hero(
                      tag: file.path,
                      child: Image.file(
                        file,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const Center(
                            child: Icon(
                              Icons.broken_image,
                              size: 40,
                              color: Colors.grey,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              );
            },
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
          title: const Text('Adjust Thumbnail Size'),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Columns: ${tempSize.round()}'),
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
                      Text('Larger', style: TextStyle(fontSize: 12)),
                      const Spacer(),
                      Text('Smaller', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ],
              );
            },
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Apply'),
              onPressed: () {
                setState(() {
                  _thumbnailSize = tempSize;
                });
                _preferences.setImageGalleryThumbnailSize(tempSize);
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
}

class _ImageViewerScreen extends StatelessWidget {
  final File file;

  const _ImageViewerScreen({required this.file});

  @override
  Widget build(BuildContext context) {
    return BaseScreen(
      title: pathlib.basename(file.path),
      backgroundColor: Colors.black,
      actions: [
        IconButton(
          icon: const Icon(Icons.share),
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Share functionality not implemented')),
            );
          },
        ),
      ],
      body: Center(
        child: Hero(
          tag: file.path,
          child: InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: Image.file(
              file,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.broken_image,
                      size: 80,
                      color: Colors.white70,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Failed to load image',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
