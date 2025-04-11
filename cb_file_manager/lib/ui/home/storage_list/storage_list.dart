import 'dart:io';

import 'package:cb_file_manager/ui/home/storage_list/storage_list_bloc.dart';
import 'package:cb_file_manager/ui/home/storage_list/storage_list_event.dart';
import 'package:cb_file_manager/ui/home/storage_list/storage_list_state.dart';
import 'package:cb_file_manager/ui/screens/folder_list/folder_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class StorageListWidget extends StatelessWidget {
  const StorageListWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Initialize with a try-catch for better error handling
    try {
      print('StorageListWidget build called');
      context.read<StorageListBloc>().add(const StorageListInit());
    } catch (e) {
      print('Error initializing StorageListBloc: $e');
      // We'll handle this below in the builder
    }

    return BlocBuilder<StorageListBloc, StorageListState>(
      builder: (context, state) {
        print(
            'StorageListWidget state update: isLoading=${state.isLoading}, error=${state.error}');

        if (state.isLoading) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Loading storage locations...'),
              ],
            ),
          );
        }

        if (state.error != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  'Error: ${state.error}',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.red[700]),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => context
                      .read<StorageListBloc>()
                      .add(const LoadStorageLocations()),
                  child: const Text('Try Again'),
                ),
              ],
            ),
          );
        }

        if (state.storageLocations.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.storage_outlined,
                    size: 48, color: Colors.grey),
                const SizedBox(height: 16),
                const Text(
                  'No storage locations found',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                  onPressed: () => context
                      .read<StorageListBloc>()
                      .add(const LoadStorageLocations()),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            context.read<StorageListBloc>().add(const LoadStorageLocations());
            // Wait a bit for the UI to update
            await Future.delayed(const Duration(seconds: 1));
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: state.storageLocations.length,
            itemBuilder: (context, index) {
              final storage = state.storageLocations[index];
              return _buildStorageCard(context, storage);
            },
          ),
        );
      },
    );
  }

  Widget _buildStorageCard(BuildContext context, Directory storage) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: ListTile(
        leading: const Icon(Icons.storage, color: Colors.green),
        title: Text(
          storage.path,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: FutureBuilder<FileStat>(
          future: storage.stat(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Text('Calculating...');
            }
            return Text(
                'Last modified: ${snapshot.data?.modified.toString().split('.')[0]}');
          },
        ),
        onTap: () {
          print('Navigating to folder list with path: ${storage.path}');
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => FolderListScreen(path: storage.path),
            ),
          );
        },
      ),
    );
  }
}
