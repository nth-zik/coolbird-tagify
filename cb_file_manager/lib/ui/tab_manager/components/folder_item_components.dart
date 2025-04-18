import 'dart:io';
import 'package:flutter/material.dart';
import 'package:eva_icons_flutter/eva_icons_flutter.dart';
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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

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
                  EvaIcons.folderOutline,
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
              // Sử dụng màu thích hợp với theme
              color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
              alignment: Alignment.center,
              child: Text(
                folder.basename(),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  // Sử dụng màu thích hợp với theme
                  color: isDarkMode ? Colors.white : Colors.black87,
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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      // Sử dụng màu card mặc định theo theme thay vì màu hardcode
      child: ListTile(
        leading:
            Icon(EvaIcons.folderOutline, color: Colors.amber[700], size: 28),
        title: Text(
          folder.basename(),
          style: TextStyle(
            color: isDarkMode ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: FutureBuilder<FileStat>(
          future: folder.stat(),
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              return Text(
                '${snapshot.data!.modified.toString().split('.')[0]}',
                style: TextStyle(
                    color: isDarkMode ? Colors.grey[400] : Colors.grey[800]),
              );
            }
            return Text('Loading...',
                style: TextStyle(
                    color: isDarkMode ? Colors.grey[500] : Colors.grey[700]));
          },
        ),
        onTap: () => onNavigate(folder.path),
        // Không gán màu nền cứng để card sử dụng màu mặc định theo theme
      ),
    );
  }
}
