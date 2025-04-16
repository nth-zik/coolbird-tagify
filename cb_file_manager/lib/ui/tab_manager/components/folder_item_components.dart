import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cb_file_manager/helpers/io_extensions.dart';

/// Component for displaying a folder item in grid view
class FolderGridItem extends StatelessWidget {
  final Directory folder;
  final Function(String) onNavigate;

  const FolderGridItem({
    Key? key,
    required this.folder,
    required this.onNavigate,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      child: InkWell(
        onTap: () => onNavigate(folder.path),
        child: Column(
          children: [
            // Icon section
            Expanded(
              flex: 3,
              child: Center(
                child: Icon(
                  Icons.folder,
                  size: 40,
                  color: Colors.amber[700],
                ),
              ),
            ),
            // Text section
            Container(
              height: 40,
              width: double.infinity,
              padding: const EdgeInsets.all(4),
              color: Colors.grey[200],
              alignment: Alignment.center,
              child: Text(
                folder.basename(),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Component for displaying a folder item in list view
class FolderListItem extends StatelessWidget {
  final Directory folder;
  final Function(String) onNavigate;

  const FolderListItem({
    Key? key,
    required this.folder,
    required this.onNavigate,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: ListTile(
        leading: Icon(Icons.folder, color: Colors.amber[700], size: 28),
        title: Text(
          folder.basename(),
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: FutureBuilder<FileStat>(
          future: folder.stat(),
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              return Text(
                '${snapshot.data!.modified.toString().split('.')[0]}',
                style: TextStyle(color: Colors.grey[800]),
              );
            }
            return Text('Loading...',
                style: TextStyle(color: Colors.grey[700]));
          },
        ),
        onTap: () => onNavigate(folder.path),
        tileColor: Colors.grey[50],
      ),
    );
  }
}
