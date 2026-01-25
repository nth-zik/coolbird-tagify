import 'package:remixicon/remixicon.dart' as remix;
import 'package:flutter/material.dart';

import 'package:cb_file_manager/config/languages/app_localizations.dart';

class NetworkFolderContextMenu {
  static void show({
    required BuildContext context,
    required Offset globalPosition,
    required VoidCallback onRefresh,
    required VoidCallback onCreateFolder,
    required VoidCallback onUploadFile,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final RenderObject? renderObject = Overlay.of(
      context,
    ).context.findRenderObject();
    final RenderBox overlay = renderObject as RenderBox;

    showMenu(
      context: context,
      position: RelativeRect.fromRect(
        globalPosition & const Size(40, 40),
        Offset.zero & overlay.size,
      ),
      items: <PopupMenuEntry<dynamic>>[
        PopupMenuItem(
          onTap: onRefresh,
          child: ListTile(
            leading: const Icon(remix.Remix.refresh_line),
            title: Text(l10n.refresh),
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          onTap: onCreateFolder,
          child: ListTile(
            leading: const Icon(remix.Remix.folder_add_line),
            title: Text(l10n.newFolder),
          ),
        ),
        PopupMenuItem(
          onTap: onUploadFile,
          child: ListTile(
            leading: const Icon(remix.Remix.upload_line),
            title: Text(l10n.uploadFile),
          ),
        ),
      ],
      elevation: 8.0,
    );
  }
}
