import 'package:flutter/material.dart';
import 'package:cb_file_manager/ui/screens/tag_management/tag_management_tab.dart';
import 'package:cb_file_manager/ui/tab_manager/tabbed_folder_list_screen.dart';
import 'package:cb_file_manager/helpers/tag_manager.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cb_file_manager/ui/tab_manager/tab_manager.dart';
import 'package:cb_file_manager/ui/screens/folder_list/folder_list_bloc.dart';
import 'package:cb_file_manager/ui/screens/folder_list/folder_list_event.dart';

/// A router that handles system screens and special paths
class SystemScreenRouter {
  /// Routes a special path to the appropriate screen
  /// Returns null if the path is not a system path
  static Widget? routeSystemPath(
      BuildContext context, String path, String tabId) {
    // Check if this is a system path by looking for the # prefix
    if (!path.startsWith('#')) {
      return null;
    }

    // Handle different types of system paths
    if (path == '#tags') {
      // Route to the tag management screen
      return TagManagementTab(tabId: tabId);
    } else if (path.startsWith('#tag:')) {
      // This is a tag search, extract the tag name
      final tag = path.substring(5); // Remove "#tag:" prefix

      // Route to the folder list screen with a tag search
      // Pass the tag search information to the tabbed folder list screen
      return Builder(builder: (context) {
        // Update the tab name to show the tag being searched
        final tabBloc = BlocProvider.of<TabManagerBloc>(context);
        tabBloc.add(UpdateTabName(tabId, 'Tag: $tag'));

        // Initialize a TabbedFolderListScreen with global tag search
        return TabbedFolderListScreen(
          path: '', // Empty path for global search
          tabId: tabId,
          searchTag: tag, // Pass the tag name
          globalTagSearch: true, // Enable global search
        );
      });
    }

    // Fallback for unknown system paths
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red,
          ),
          const SizedBox(height: 16),
          Text(
            'Unknown system path: $path',
            style: const TextStyle(fontSize: 18),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Go Back'),
          ),
        ],
      ),
    );
  }

  /// Checks if a path is a system path
  static bool isSystemPath(String path) {
    return path.startsWith('#');
  }
}
