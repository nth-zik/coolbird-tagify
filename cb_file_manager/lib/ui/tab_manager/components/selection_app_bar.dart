import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:eva_icons_flutter/eva_icons_flutter.dart';
import '../../screens/folder_list/folder_list_bloc.dart';
import '../../screens/folder_list/folder_list_event.dart';
import 'tag_dialogs.dart';
import 'package:cb_file_manager/ui/tab_manager/components/tag_dialogs.dart';

/// AppBar component displayed when in selection mode
class SelectionAppBar extends StatelessWidget implements PreferredSizeWidget {
  final int selectedCount;
  final VoidCallback onClearSelection;
  final List<String> selectedFilePaths;
  final List<String> selectedFolderPaths;
  final Function(BuildContext, List<String>) showRemoveTagsDialog;
  final Function(BuildContext) showManageAllTagsDialog;
  final Function(BuildContext) showDeleteConfirmationDialog;

  const SelectionAppBar({
    Key? key,
    required this.selectedCount,
    required this.onClearSelection,
    required this.selectedFilePaths,
    this.selectedFolderPaths = const [],
    required this.showRemoveTagsDialog,
    required this.showManageAllTagsDialog,
    required this.showDeleteConfirmationDialog,
  }) : super(key: key);

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    // Always calculate the actual count from the lists to ensure accuracy
    final int fileCount = selectedFilePaths.length;
    final int folderCount = selectedFolderPaths.length;
    final int actualCount = fileCount + folderCount;

    // Debug warning if passed count doesn't match actual count
    if (actualCount != selectedCount) {
      print(
          "⚠️ SelectionAppBar - Count mismatch: passed=$selectedCount, actual=$actualCount (files=$fileCount, folders=$folderCount)");
    }

    // Build display text with file and folder counts
    String selectionText;
    if (fileCount > 0 && folderCount > 0) {
      selectionText =
          'Đã chọn: $actualCount (${fileCount} tệp, ${folderCount} thư mục)';
    } else if (fileCount > 0) {
      selectionText = 'Đã chọn: $actualCount tệp';
    } else if (folderCount > 0) {
      selectionText = 'Đã chọn: $actualCount thư mục';
    } else {
      selectionText = 'Đã chọn: $actualCount';
    }

    return AppBar(
      leading: IconButton(
        icon: const Icon(EvaIcons.close),
        onPressed: onClearSelection,
      ),
      title: Text(selectionText),
      actions: [
        // Show tag management for files only
        if (fileCount > 0) ...[
          // Tag management dropdown menu
          PopupMenuButton<String>(
            icon: const Icon(EvaIcons.shoppingBag),
            tooltip: 'Quản lý Tag',
            onSelected: (value) {
              if (value == 'add_tag') {
                showBatchAddTagDialog(context, selectedFilePaths);
              } else if (value == 'remove_tags') {
                showRemoveTagsDialog(context, selectedFilePaths);
              } else if (value == 'manage_all_tags') {
                showManageAllTagsDialog(context);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem<String>(
                value: 'add_tag',
                child: Row(
                  children: [
                    Icon(EvaIcons.plusCircleOutline),
                    SizedBox(width: 8),
                    Text('Thêm Tag'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'remove_tags',
                child: Row(
                  children: [
                    Icon(EvaIcons.minusCircleOutline),
                    SizedBox(width: 8),
                    Text('Xóa Tag'),
                  ],
                ),
              )
            ],
          ),
        ],

        // Delete option (works for both files and folders)
        if (actualCount > 0)
          IconButton(
            icon: const Icon(EvaIcons.trash2Outline),
            tooltip: 'Chuyển vào Thùng rác',
            onPressed: () {
              showDeleteConfirmationDialog(context);
            },
          ),
      ],
    );
  }
}
