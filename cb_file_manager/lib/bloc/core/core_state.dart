import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class CoreState extends Equatable {
  final Directory currentPath;
  final List<dynamic> folders;
  final List<dynamic> subFolders;

  const CoreState({
    required this.currentPath,
    this.folders = const [],
    this.subFolders = const [],
  });

  // Factory constructor with string path
  factory CoreState.withPath(String path) {
    return CoreState(currentPath: Directory(path));
  }

  @override
  List<Object> get props => [currentPath, folders, subFolders];

  // Create a new instance with updated path
  CoreState copyWith({
    Directory? currentPath,
    List<dynamic>? folders,
    List<dynamic>? subFolders,
  }) {
    return CoreState(
      currentPath: currentPath ?? this.currentPath,
      folders: folders ?? this.folders,
      subFolders: subFolders ?? this.subFolders,
    );
  }

  Future<CoreState> initialize() async {
    try {
      // Requesting permissions if not granted using the newer permission_handler package
      var status = await Permission.storage.status;
      if (!status.isGranted) {
        await Permission.storage.request();
      }

      print("Initializing");
      // requesting storage directory
      Directory? externalDir = await getExternalStorageDirectory();
      if (externalDir != null) {
        return copyWith(currentPath: externalDir);
      } else {
        print("Failed to get external storage directory");
        return this;
      }
    } catch (e) {
      print("Error during initialization: $e");
      return this;
    }
  }

  // Helper method to get current folder contents
  Future<List<FileSystemEntity>> getCurrentFolderContents() async {
    try {
      return currentPath.listSync();
    } catch (e) {
      print("Error listing directory contents: $e");
      return [];
    }
  }
}
