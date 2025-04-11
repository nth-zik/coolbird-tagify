import 'package:flutter/material.dart';
import './main_ui.dart';
import './utils/route.dart';
import './home.dart';
import 'package:cb_file_manager/ui/screens/tag_management/tag_management_screen.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cb_file_manager/helpers/tag_manager.dart';

class CBDrawer extends StatelessWidget {
  final BuildContext parentContext;

  const CBDrawer(this.parentContext, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Drawer(
        child: ListView(
      padding: EdgeInsets.zero,
      children: <Widget>[
        const SizedBox(
          height: 120,
          child: DrawerHeader(
            child: Text(
              'CoolBird File Manager',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
              ),
            ),
            decoration: BoxDecoration(
              color: Colors.green,
            ),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.home),
          title: const Text('Homepage'),
          onTap: () {
            RouteUtils.toNewScreen(
                context, const MyHomePage(title: 'CoolBird - File Manager'));
          },
        ),
        ExpansionTile(
          leading: const Icon(Icons.phone_android),
          title: const Text('Local'),
          children: <Widget>[
            ListTile(
              contentPadding: const EdgeInsets.only(left: 30),
              leading: const Icon(Icons.folder),
              title: const Text('Storage'),
              onTap: () {
                RouteUtils.toNewScreen(context, const LocalHome());
              },
            ),
            ListTile(
              contentPadding: const EdgeInsets.only(left: 30),
              leading: const Icon(Icons.label),
              title: const Text('Tags'),
              onTap: () async {
                Navigator.pop(context);
                // Get documents directory as starting directory
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
          ],
        ),
        ListTile(
          leading: const Icon(Icons.network_wifi),
          title: const Text('Networks'),
          onTap: () {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Network functionality coming soon'),
              ),
            );
          },
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.settings),
          title: const Text('Settings'),
          onTap: () {
            Navigator.pop(context);
            _showSettingsDialog(context);
          },
        ),
        ListTile(
          leading: const Icon(Icons.info_outline),
          title: const Text('About'),
          onTap: () {
            Navigator.pop(context);
            _showAboutDialog(context);
          },
        ),
      ],
    ));
  }

  void _showSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              leading: const Icon(Icons.label),
              title: const Text('Migrate Tags to Global System'),
              subtitle: const Text(
                  'Migrate all existing directory-based tags to the new global system'),
              onTap: () {
                Navigator.pop(context);
                _showTagMigrationDialog(context);
              },
            ),
            // Add other settings options here
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

  void _showTagMigrationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Migrate Tags'),
        content: const Text(
          'This will migrate all your existing tags from individual directories to the new global tag system. '
          'This allows your tags to be accessible from anywhere in the app.\n\n'
          'Do you want to continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();

              // Show progress dialog
              _showProgressDialog(context);

              try {
                // Get the root storage path
                final directory = await getExternalStorageDirectory() ??
                    await getApplicationDocumentsDirectory();

                // Start migration process
                final migratedCount =
                    await TagManager.migrateToGlobalTags(directory.path);

                // Hide progress dialog
                if (context.mounted) Navigator.of(context).pop();

                // Show result dialog
                if (context.mounted) {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Migration Complete'),
                      content: Text(
                          'Successfully migrated $migratedCount tagged files to the global tag system.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('OK'),
                        ),
                      ],
                    ),
                  );
                }
              } catch (e) {
                // Hide progress dialog
                if (context.mounted) Navigator.of(context).pop();

                // Show error dialog
                if (context.mounted) {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Migration Error'),
                      content: Text('An error occurred during migration: $e'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('OK'),
                        ),
                      ],
                    ),
                  );
                }
              }
            },
            child: const Text('Migrate'),
          ),
        ],
      ),
    );
  }

  void _showProgressDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        title: Text('Migrating Tags'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Please wait while your tags are being migrated...'),
          ],
        ),
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
