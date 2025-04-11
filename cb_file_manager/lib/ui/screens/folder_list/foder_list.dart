import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'folder_list_bloc.dart';
import 'folder_list_event.dart';
import 'folder_list_state.dart';

class FolderListScreen extends StatelessWidget {
  final String path;

  const FolderListScreen({Key? key, required this.path}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => FolderListBloc()..add(FolderListLoad(path)),
      child: BlocBuilder<FolderListBloc, FolderListState>(
        builder: (context, state) {
          if (state.isLoading) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          if (state.error != null) {
            return Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(
                      'Error: ${state.error}',
                      style: TextStyle(color: Colors.red[700]),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        context
                            .read<FolderListBloc>()
                            .add(FolderListLoad(path));
                      },
                      child: const Text('Try Again'),
                    ),
                  ],
                ),
              ),
            );
          }

          return Scaffold(
            appBar: AppBar(
              title: Text(
                  path.split('/').last.isEmpty ? 'Root' : path.split('/').last),
            ),
            body: RefreshIndicator(
              onRefresh: () async {
                context.read<FolderListBloc>().add(FolderListLoad(path));
                return Future.value();
              },
              child: state.files.isEmpty && state.folders.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 200),
                        Center(
                          child: Text('No files or folders found'),
                        ),
                      ],
                    )
                  : ListView(
                      children: [
                        if (state.folders.isNotEmpty) ...[
                          const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Text(
                              'Folders',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          ...state.folders
                              .whereType<Directory>()
                              .map(
                                  (folder) => _buildFolderItem(context, folder))
                              .toList(),
                        ],
                        if (state.files.isNotEmpty) ...[
                          const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Text(
                              'Files',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          ...state.files
                              .whereType<File>()
                              .map((file) => _buildFileItem(context, file))
                              .toList(),
                        ],
                      ],
                    ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFolderItem(BuildContext context, Directory folder) {
    return ListTile(
      leading: const Icon(Icons.folder, color: Colors.amber),
      title: Text(folder.path.split('/').last),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FolderListScreen(path: folder.path),
          ),
        );
      },
    );
  }

  Widget _buildFileItem(BuildContext context, File file) {
    // Simple file icon based on extension
    String extension = file.path.split('.').last.toLowerCase();
    IconData iconData;
    Color iconColor = Colors.grey;

    if (['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'].contains(extension)) {
      iconData = Icons.image;
      iconColor = Colors.blue;
    } else if (['mp4', 'mov', 'avi', 'mkv', 'wmv'].contains(extension)) {
      iconData = Icons.video_file;
      iconColor = Colors.red;
    } else if (['mp3', 'wav', 'ogg', 'aac', 'flac'].contains(extension)) {
      iconData = Icons.audio_file;
      iconColor = Colors.purple;
    } else if (['pdf', 'doc', 'docx', 'txt', 'rtf'].contains(extension)) {
      iconData = Icons.description;
      iconColor = Colors.indigo;
    } else {
      iconData = Icons.insert_drive_file;
    }

    return ListTile(
      leading: Icon(iconData, color: iconColor),
      title: Text(file.path.split('/').last),
      subtitle: FutureBuilder<FileStat>(
        future: file.stat(),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            int size = snapshot.data!.size;
            String sizeStr;
            if (size < 1024) {
              sizeStr = '$size B';
            } else if (size < 1024 * 1024) {
              sizeStr = '${(size / 1024).toStringAsFixed(1)} KB';
            } else if (size < 1024 * 1024 * 1024) {
              sizeStr = '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
            } else {
              sizeStr =
                  '${(size / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
            }
            return Text(sizeStr);
          }
          return const Text('Loading...');
        },
      ),
      onTap: () {
        // You can implement file opening functionality here
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Opening ${file.path.split('/').last}...')),
        );
      },
    );
  }
}
