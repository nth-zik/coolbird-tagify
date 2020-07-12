
import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:path_provider/path_provider.dart';
import 'package:simple_permissions/simple_permissions.dart';

class CoreState extends Equatable {
  Directory _currentPath;
  final List<dynamic> folders = [];
  final List<dynamic> subFolders = [];

  CoreState(String currentPath) : this._currentPath = new Directory(currentPath);

  @override
  List<Object> get props => [_currentPath];
  
  set currentPath(Directory currentPath) {
    _currentPath = currentPath;
  }

  Future<void> initialize() async {
    //Requesting permissions if not granted
    if (!await SimplePermissions.checkPermission(
        Permission.WriteExternalStorage)) {
      await SimplePermissions.requestPermission(
          Permission.WriteExternalStorage);
    }

    print("Initializing");
    // requesting permissions
    currentPath = await getExternalStorageDirectory();
  }
}