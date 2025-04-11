import 'dart:io';
import 'package:cb_file_manager/helpers/filesystem_utils.dart';
import 'package:cb_file_manager/ui/home/storage_list/storage_list_event.dart';
import 'package:cb_file_manager/ui/home/storage_list/storage_list_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path_provider/path_provider.dart';

class StorageListBloc extends Bloc<StorageListEvent, StorageListState> {
  StorageListBloc() : super(StorageListState("/")) {
    print('StorageListBloc initialized');
    on<StorageListInit>(_onStorageListInit);
    on<LoadStorageLocations>(_onLoadStorageLocations);
  }

  void _onStorageListInit(
      StorageListInit event, Emitter<StorageListState> emit) {
    print('StorageListInit event received');
    emit(state.copyWith(isLoading: true));
    add(const LoadStorageLocations());
  }

  void _onLoadStorageLocations(
      LoadStorageLocations event, Emitter<StorageListState> emit) async {
    print('LoadStorageLocations event received');
    try {
      emit(state.copyWith(isLoading: true));
      print('Attempting to get storage directories...');

      List<Directory> storageLocations = [];

      try {
        // Try to use the platform-agnostic method first
        storageLocations = await getAllStorageLocations();
        print(
            'Found ${storageLocations.length} storage locations using getAllStorageLocations()');
      } catch (e) {
        print('Error using getAllStorageLocations(): $e');
        print('Falling back to platform-specific methods...');

        // Fallback based on platform
        if (Platform.isWindows) {
          try {
            // For Windows, try to get all drives
            storageLocations = await getAllWindowsDrives();
            print('Found ${storageLocations.length} Windows drives');
          } catch (e) {
            print('Error getting Windows drives: $e');
          }
        } else if (Platform.isAndroid) {
          try {
            // For Android, use the existing storage detection
            storageLocations = await getStorageList();
            print('Found ${storageLocations.length} Android storage locations');
          } catch (e) {
            print('Error getting Android storage: $e');
          }
        }
      }

      // If all methods failed, fall back to app documents directory
      if (storageLocations.isEmpty) {
        final appDocDir = await getApplicationDocumentsDirectory();
        print('Using app documents directory as fallback: ${appDocDir.path}');
        storageLocations.add(appDocDir);
      }

      // Log what we found
      for (var dir in storageLocations) {
        print('Storage location: ${dir.path}');
      }

      print('Emitting state with ${storageLocations.length} storage locations');
      emit(state.copyWith(
        storageLocations: storageLocations,
        isLoading: false,
      ));
    } catch (e) {
      print('Error in LoadStorageLocations: $e');
      emit(state.copyWith(
        isLoading: false,
        error: e.toString(),
      ));
    }
  }
}
