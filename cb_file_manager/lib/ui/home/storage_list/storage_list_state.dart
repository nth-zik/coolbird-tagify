import 'dart:io';

import 'package:equatable/equatable.dart';

class StorageListState extends Equatable {
  final Directory currentPath;
  final List<Directory> storageLocations;
  final bool isLoading;
  final String? error;

  StorageListState(String currentPath)
      : this.currentPath = Directory(currentPath),
        this.storageLocations = const [],
        this.isLoading = false,
        this.error = null;

  StorageListState._({
    required this.currentPath,
    required this.storageLocations,
    required this.isLoading,
    this.error,
  });

  StorageListState copyWith({
    Directory? currentPath,
    List<Directory>? storageLocations,
    bool? isLoading,
    String? error,
  }) {
    return StorageListState._(
      currentPath: currentPath ?? this.currentPath,
      storageLocations: storageLocations ?? this.storageLocations,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }

  @override
  List<Object?> get props => [currentPath, storageLocations, isLoading, error];
}
