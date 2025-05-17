import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cb_file_manager/ui/screens/folder_list/folder_list_bloc.dart';
import 'package:cb_file_manager/ui/screens/folder_list/folder_list_event.dart';
import 'package:cb_file_manager/ui/screens/media_gallery/image_gallery_screen.dart';
import 'package:cb_file_manager/ui/screens/media_gallery/video_gallery_screen.dart';
import 'package:cb_file_manager/ui/tab_manager/components/tag_dialogs.dart';

class FolderListAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String currentPath;
  final bool isSelectionMode;
  final bool isGridView;
  final List<String> selectedFiles;
  final List<String> allTags;
  final Function() toggleViewMode;
  final Function() toggleSelectionMode;
  final Function() clearSelection;
  final Function() showSearchScreen;
  final Function() refresh;
  final Function(int) setGridZoomLevel;
  final int currentGridZoomLevel;

  const FolderListAppBar({
    Key? key,
    required this.currentPath,
    required this.isSelectionMode,
    required this.isGridView,
    required this.selectedFiles,
    required this.allTags,
    required this.toggleViewMode,
    required this.toggleSelectionMode,
    required this.clearSelection,
    required this.showSearchScreen,
    required this.refresh,
    required this.setGridZoomLevel,
    required this.currentGridZoomLevel,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(
        isSelectionMode ? '${selectedFiles.length} selected' : 'Files',
      ),
      actions: _buildAppBarActions(context),
    );
  }

  List<Widget> _buildAppBarActions(BuildContext context) {
    if (isSelectionMode) {
      return [
        PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'add_tag':
                showBatchAddTagDialog(context, selectedFiles);
                break;
              case 'delete':
                BlocProvider.of<FolderListBloc>(context)
                    .add(FolderListDeleteFiles(selectedFiles));
                toggleSelectionMode();
                break;
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'add_tag',
              child: Row(
                children: [
                  Icon(Icons.local_offer,
                      color: Theme.of(context).iconTheme.color),
                  const SizedBox(width: 8),
                  const Text('Add Tag'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, color: Colors.red[400]),
                  const SizedBox(width: 8),
                  const Text('Delete', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
        IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Cancel selection',
          onPressed: clearSelection,
        ),
      ];
    } else {
      return [
        if (!isGridView)
          IconButton(
            icon: const Icon(Icons.grid_view),
            tooltip: 'Switch to grid view',
            onPressed: toggleViewMode,
          )
        else
          IconButton(
            icon: const Icon(Icons.view_list),
            tooltip: 'Switch to list view',
            onPressed: toggleViewMode,
          ),
        IconButton(
          icon: const Icon(Icons.search),
          tooltip: 'Search',
          onPressed: showSearchScreen,
        ),
        PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'refresh':
                refresh();
                break;
              case 'select_all':
                toggleSelectionMode();
                break;
              case 'manage_tags':
                showManageTagsDialog(context, allTags, currentPath);
                break;
              case 'photo_gallery':
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ImageGalleryScreen(path: currentPath),
                  ),
                );
                break;
              case 'video_gallery':
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => VideoGalleryScreen(path: currentPath),
                  ),
                );
                break;
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'refresh',
              child: Row(
                children: [
                  Icon(Icons.refresh, color: Theme.of(context).iconTheme.color),
                  const SizedBox(width: 8),
                  const Text('Refresh'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'select_all',
              child: Row(
                children: [
                  Icon(Icons.select_all,
                      color: Theme.of(context).iconTheme.color),
                  const SizedBox(width: 8),
                  const Text('Select All'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'manage_tags',
              child: Row(
                children: [
                  Icon(Icons.local_offer,
                      color: Theme.of(context).iconTheme.color),
                  const SizedBox(width: 8),
                  const Text('Manage Tags'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'photo_gallery',
              child: Row(
                children: [
                  Icon(Icons.photo_library,
                      color: Theme.of(context).iconTheme.color),
                  const SizedBox(width: 8),
                  const Text('Photo Gallery'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'video_gallery',
              child: Row(
                children: [
                  Icon(Icons.video_library,
                      color: Theme.of(context).iconTheme.color),
                  const SizedBox(width: 8),
                  const Text('Video Gallery'),
                ],
              ),
            ),
          ],
        ),
      ];
    }
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
