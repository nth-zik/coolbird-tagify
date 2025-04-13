import 'dart:io';
import 'dart:typed_data'; // Added import for Uint8List
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../../helpers/video_thumbnail_helper.dart';

/// A test screen to verify video thumbnails are working
class VideoThumbnailTestScreen extends StatefulWidget {
  const VideoThumbnailTestScreen({Key? key}) : super(key: key);

  @override
  State<VideoThumbnailTestScreen> createState() =>
      _VideoThumbnailTestScreenState();
}

class _VideoThumbnailTestScreenState extends State<VideoThumbnailTestScreen> {
  String? _selectedVideoPath;
  Uint8List? _thumbnailBytes;
  String? _errorMessage;
  bool _isLoading = false;

  Future<void> _pickVideo() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
        _thumbnailBytes = null;
      });

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: false,
      );

      if (result != null &&
          result.files.isNotEmpty &&
          result.files.first.path != null) {
        _selectedVideoPath = result.files.first.path;

        // Generate thumbnail
        _thumbnailBytes = await VideoThumbnailHelper.generateThumbnailData(
            _selectedVideoPath!);

        if (_thumbnailBytes == null) {
          _errorMessage = 'Could not generate thumbnail';
        }
      } else {
        _errorMessage = 'No video selected';
      }
    } catch (e) {
      _errorMessage = 'Error: $e';
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Video Thumbnail Test'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: _pickVideo,
              child: const Text('Select Video File'),
            ),
            const SizedBox(height: 20),
            if (_isLoading) const CircularProgressIndicator(),
            if (_selectedVideoPath != null)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text('Selected: $_selectedVideoPath'),
              ),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            if (_thumbnailBytes != null)
              Column(
                children: [
                  const Text('Thumbnail Generated Successfully'),
                  const SizedBox(height: 10),
                  Container(
                    width: 250,
                    height: 150,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                    ),
                    child: Image.memory(
                      _thumbnailBytes!,
                      fit: BoxFit.contain,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
