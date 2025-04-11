import 'package:cb_file_manager/ui/home/storage_list/storage_list.dart';
import 'package:cb_file_manager/ui/home/storage_list/storage_list_bloc.dart';
import 'package:cb_file_manager/ui/screens/tag_management/tag_management_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path_provider/path_provider.dart';

class LocalHome extends StatelessWidget {
  const LocalHome({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Local File Manager'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // Global search functionality could be added here
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Global search not implemented yet'),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              // Settings screen could be added here
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Settings not implemented yet'),
                ),
              );
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.green,
              ),
              child: Text(
                'CoolBird File Manager',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.storage),
              title: const Text('Storage'),
              onTap: () {
                Navigator.pop(context); // Close drawer
              },
            ),
            ListTile(
              leading: const Icon(Icons.folder_special),
              title: const Text('Favorites'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Favorites not implemented yet'),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.label),
              title: const Text('Tags'),
              onTap: () async {
                Navigator.pop(context);
                // Get the app's documents directory as the starting directory
                final directory = await getApplicationDocumentsDirectory();
                // Navigate to the Tag Management screen
                if (context.mounted) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TagManagementScreen(
                        startingDirectory: directory.path,
                      ),
                    ),
                  );
                }
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('About'),
              onTap: () {
                Navigator.pop(context);
                _showAboutDialog(context);
              },
            ),
          ],
        ),
      ),
      body: BlocProvider<StorageListBloc>(
        create: (context) => StorageListBloc(),
        child: StorageListWidget(),
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('CoolBird File Manager'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('A powerful file manager with tagging capabilities.'),
            SizedBox(height: 16),
            Text('Version: 1.0.0'),
            SizedBox(height: 8),
            Text('Developed by CoolBird Team'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
