
import 'dart:io';

import 'package:equatable/equatable.dart';

class FolderListState extends Equatable {
  final Directory _currentPath;
  final List<dynamic> folders = [];
  final List<dynamic> subFolders = [];

  FolderListState(String currentPath) : this._currentPath = new Directory(currentPath);

  @override
  List<Object> get props => [_currentPath];

}