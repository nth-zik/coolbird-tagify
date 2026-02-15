import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:cb_file_manager/helpers/core/io_extensions.dart';
import 'package:cb_file_manager/config/translation_helper.dart';
import 'package:cb_file_manager/ui/widgets/drawer/cubit/drawer_cubit.dart';
import 'package:cb_file_manager/ui/utils/route.dart';

class StorageSectionWidget extends StatefulWidget {
  final Function(String path, String name) onNavigate;
  final VoidCallback onTrashTap;

  const StorageSectionWidget({
    Key? key,
    required this.onNavigate,
    required this.onTrashTap,
  }) : super(key: key);

  @override
  State<StorageSectionWidget> createState() => _StorageSectionWidgetState();
}

class _StorageSectionWidgetState extends State<StorageSectionWidget> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return BlocBuilder<DrawerCubit, DrawerState>(
      builder: (context, state) {
        return Theme(
          data: Theme.of(context).copyWith(
            dividerColor: Colors.transparent,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Material(
              color: Colors.transparent,
              child: ExpansionTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                trailing: AnimatedRotation(
                  duration: const Duration(milliseconds: 180),
                  turns: _isExpanded ? 0.5 : 0.0,
                  child: Icon(
                    PhosphorIconsLight.caretDown,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                leading: Icon(
                  PhosphorIconsLight.hardDrives,
                  size: 22,
                  color: theme.colorScheme.primary,
                ),
                title: Text(
                  context.tr.drivesTab,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                collapsedBackgroundColor: Colors.transparent,
                backgroundColor: Colors.transparent,
                childrenPadding: const EdgeInsets.only(bottom: 8),
                initiallyExpanded: _isExpanded,
                onExpansionChanged: (isExpanded) {
                  setState(() {
                    _isExpanded = isExpanded;
                  });
                },
                children: <Widget>[
                  if (state.isLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(
                        child: SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    )
                  else if (state.storageLocations.isEmpty)
                    ListTile(
                      contentPadding: const EdgeInsets.only(left: 52, right: 14),
                      title: Text(context.tr.noStorageLocationsFound),
                      trailing: IconButton(
                        icon: const Icon(PhosphorIconsLight.arrowsClockwise),
                        onPressed: () {
                          context.read<DrawerCubit>().loadStorageLocations();
                        },
                      ),
                    )
                  else
                    ...state.storageLocations.map((storage) {
                      return _buildStorageItem(context, storage);
                    }),

                  // Trash Bin
                  _buildItem(
                    context,
                    icon: PhosphorIconsLight.trash,
                    title: context.tr.trashBin,
                    iconColor: theme.colorScheme.error,
                    onTap: widget.onTrashTap,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStorageItem(BuildContext context, Directory storage) {
    final theme = Theme.of(context);
    String displayName = _getStorageDisplayName(storage);
    IconData icon = _getStorageIcon(storage);
    bool requiresAdmin = storage.requiresAdmin;

    return _buildItem(
      context,
      icon: icon,
      title: displayName,
      subtitle: requiresAdmin ? context.tr.requiresAdminPrivileges : null,
      iconColor: requiresAdmin ? theme.colorScheme.tertiary : null,
      onTap: () {
        if (requiresAdmin) {
          _showAdminAccessDialog(context, storage);
        } else {
          widget.onNavigate(storage.path, displayName);
        }
      },
    );
  }

  Widget _buildItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    Color? iconColor,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return ListTile(
      contentPadding: const EdgeInsets.only(left: 52, right: 14),
      dense: true,
      leading: Icon(
        icon,
        size: 20,
        color: iconColor ?? theme.colorScheme.primary.withValues(alpha: 0.8),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: theme.textTheme.bodySmall?.color,
              ),
            )
          : null,
      onTap: onTap,
    );
  }

  void _showAdminAccessDialog(BuildContext context, Directory drive) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr.adminAccessRequired),
        content: Text(context.tr.driveRequiresAdmin(drive.path)),
        actions: [
          TextButton(
            onPressed: () => RouteUtils.safePopDialog(context),
            child: Text(context.tr.cancel),
          ),
          TextButton(
            onPressed: () {
              RouteUtils.safePopDialog(context);
              widget.onNavigate(drive.path, drive.path.split(r'\')[0]);
            },
            child: Text(context.tr.ok),
          ),
        ],
      ),
    );
  }

  // Helper methods from original file
  String _getStorageDisplayName(Directory storage) {
    String path = storage.path;
    if (path.length > 1 && path.endsWith(Platform.pathSeparator)) {
      path = path.substring(0, path.length - 1);
    }

    if (Platform.isWindows && path.contains(':')) {
      String driveLetter = path.split(r'\')[0];
      return '$driveLetter (${_getDriveTypeIcon(storage)})';
    }

    if (path == '/') return 'Root (/)';
    if (path == '/storage/emulated/0') return 'Internal Storage (Primary)';
    if (path == '/sdcard') return 'Internal Storage (sdcard)';
    if (path == '/storage') return 'Storage';

    return path;
  }

  String _getDriveTypeIcon(Directory drive) {
    String path = drive.path;
    if (path.startsWith('C:')) {
      return 'System';
    }
    return 'Drive';
  }

  IconData _getStorageIcon(Directory drive) {
    if (Platform.isWindows && drive.path.startsWith('C:')) {
      return PhosphorIconsLight.desktop;
    }
    return PhosphorIconsLight.hardDrives;
  }
}


