import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cb_file_manager/helpers/filesystem_utils.dart';
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

  @override
  void initState() {
    super.initState();
    _loadImages();
  }

  void _loadImages() {
    _imageFilesFuture = getAllImages(widget.path, recursive: widget.recursive);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Image Gallery: ${pathlib.basename(widget.path)}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _loadImages();
              });
            },
          ),
        ],
      ),
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
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
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
}

class _ImageViewerScreen extends StatelessWidget {
  final File file;

  const _ImageViewerScreen({required this.file});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(pathlib.basename(file.path)),
        backgroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              // Share functionality could be added here
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Share functionality not implemented')),
              );
            },
          ),
        ],
      ),
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
