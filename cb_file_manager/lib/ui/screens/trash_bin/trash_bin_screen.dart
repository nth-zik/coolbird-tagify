import 'dart:io';
import 'package:flutter/material.dart';
import 'package:remixicon/remixicon.dart' as remix;
import 'package:cb_file_manager/helpers/files/trash_manager.dart';
import 'package:intl/intl.dart';
import 'package:cb_file_manager/ui/utils/file_type_utils.dart';
import '../../utils/format_utils.dart';
import '../mixins/selection_mixin.dart';

class TrashBinScreen extends StatefulWidget {
  const TrashBinScreen({Key? key}) : super(key: key);

  @override
  State<TrashBinScreen> createState() => _TrashBinScreenState();
}

class _TrashBinScreenState extends State<TrashBinScreen> with SelectionMixin {
  final TrashManager _trashManager = TrashManager();
  List<TrashItem> _trashItems = [];
  bool _isLoading = true;
  String? _errorMessage;
  bool _showSystemOptions = false;

  @override
  void initState() {
    super.initState();
    _loadTrashItems();
  }

  Future<void> _loadTrashItems() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final items = await _trashManager.getTrashItems();
      setState(() {
        _trashItems = items;
        _isLoading = false;

        // Determine if we have system items to show system-specific options
        _showSystemOptions =
            Platform.isWindows && items.any((item) => item.isSystemTrashItem);
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading trash items: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _restoreItem(TrashItem item) async {
    setState(() {
      _isLoading = true;
    });

    try {
      bool success = false;

      if (item.isSystemTrashItem && Platform.isWindows) {
        // Restore from Windows Recycle Bin
        success = await _trashManager
            .restoreFromWindowsRecycleBin(item.trashFileName);
      } else {
        // Restore from internal trash
        success = await _trashManager.restoreFromTrash(item.trashFileName);
      }

      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content:
                    Text('${item.displayNameValue} restored successfully')),
          );
        }
        // Refresh the trash items
        await _loadTrashItems();
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to restore ${item.displayNameValue}';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error restoring item: $e';
      });
    }
  }

  Future<void> _deleteItem(TrashItem item) async {
    final bool confirm = await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Permanently Delete'),
            content: Text(
              'Are you sure you want to permanently delete "${item.displayNameValue}"? This action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('CANCEL'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child:
                    const Text('DELETE', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ) ??
        false;

    if (confirm) {
      setState(() {
        _isLoading = true;
      });

      try {
        bool success = false;

        if (item.isSystemTrashItem && Platform.isWindows) {
          // Delete from Windows Recycle Bin
          success = await _trashManager
              .deleteFromWindowsRecycleBin(item.trashFileName);
        } else {
          // Delete from internal trash
          success = await _trashManager.deleteFromTrash(item.trashFileName);
        }

        if (success) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content:
                      Text('${item.displayNameValue} permanently deleted')),
            );
          }
          // Refresh the trash items
          await _loadTrashItems();
        } else {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Failed to delete ${item.displayNameValue}';
          });
        }
      } catch (e) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error deleting item: $e';
        });
      }
    }
  }

  Future<void> _emptyTrash() async {
    final bool confirm = await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Empty Trash'),
            content: const Text(
              'Are you sure you want to permanently delete all items in the trash? This action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('CANCEL'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('EMPTY TRASH',
                    style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ) ??
        false;

    if (confirm) {
      setState(() {
        _isLoading = true;
      });

      try {
        final success = await _trashManager.emptyTrash();

        if (success) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Trash emptied successfully')),
            );
          }
          // Refresh the trash items
          await _loadTrashItems();
        } else {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Failed to empty trash';
          });
        }
      } catch (e) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error emptying trash: $e';
        });
      }
    }
  }

  Future<void> _openSystemRecycleBin() async {
    if (Platform.isWindows) {
      try {
        await _trashManager.openWindowsRecycleBin();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error opening Recycle Bin: $e')),
          );
        }
      }
    }
  }

  Future<void> _restoreSelectedItems() async {
    setState(() {
      _isLoading = true;
    });

    try {
      int successCount = 0;
      int failedCount = 0;

      for (final trashFileName in selectedPaths) {
        final item = _trashItems.firstWhere(
          (item) => item.trashFileName == trashFileName,
          orElse: () => throw Exception('Item not found'),
        );

        bool success = false;
        if (item.isSystemTrashItem && Platform.isWindows) {
          success = await _trashManager
              .restoreFromWindowsRecycleBin(item.trashFileName);
        } else {
          success = await _trashManager.restoreFromTrash(item.trashFileName);
        }

        if (success) {
          successCount++;
        } else {
          failedCount++;
        }
      }

      String message = '$successCount items restored successfully';
      if (failedCount > 0) {
        message += ', $failedCount failed';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );

        // Clear selection and refresh
        exitSelectionMode();
      }

      await _loadTrashItems();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error restoring items: $e';
      });
    }
  }

  Future<void> _deleteSelectedItems() async {
    final bool confirm = await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Permanently Delete ${selectedPaths.length} items?'),
            content: const Text(
              'This action cannot be undone. Are you sure you want to permanently delete these items?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('CANCEL'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child:
                    const Text('DELETE', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ) ??
        false;

    if (confirm) {
      setState(() {
        _isLoading = true;
      });

      try {
        int successCount = 0;
        int failedCount = 0;

        for (final trashFileName in selectedPaths) {
          final item = _trashItems.firstWhere(
            (item) => item.trashFileName == trashFileName,
            orElse: () => throw Exception('Item not found'),
          );

          bool success = false;
          if (item.isSystemTrashItem && Platform.isWindows) {
            success = await _trashManager
                .deleteFromWindowsRecycleBin(item.trashFileName);
          } else {
            success = await _trashManager.deleteFromTrash(item.trashFileName);
          }

          if (success) {
            successCount++;
          } else {
            failedCount++;
          }
        }

        String message = '$successCount items permanently deleted';
        if (failedCount > 0) {
          message += ', $failedCount failed';
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message)),
          );

          // Clear selection and refresh
          exitSelectionMode();
        }

        await _loadTrashItems();
      } catch (e) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error deleting items: $e';
        });
      }
    }
  }

  void _toggleSelectionMode() {
    toggleSelectionMode();
  }

  void _toggleItemSelection(String trashFileName) {
    setState(() {
      if (selectedPaths.contains(trashFileName)) {
        selectedPaths.remove(trashFileName);
      } else {
        selectedPaths.add(trashFileName);
      }
    });
  }

  void _selectAll() {
    setState(() {
      if (selectedPaths.length == _trashItems.length) {
        // If all are selected, deselect all
        selectedPaths.clear();
      } else {
        // Otherwise, select all
        selectedPaths.clear();
        for (final item in _trashItems) {
          selectedPaths.add(item.trashFileName);
        }
      }
    });
  }

  // Helper methods using FormatUtils
  String _formatDate(DateTime date) => FormatUtils.formatDateWithTime(date);
  String _formatFileSize(int bytes) => FormatUtils.formatFileSize(bytes);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trash Bin'),
        actions: [
          if (isSelectionMode) ...[
            IconButton(
              icon: const Icon(remix.Remix.checkbox_line),
              tooltip: 'Select All',
              onPressed: _selectAll,
            ),
            IconButton(
              icon: const Icon(remix.Remix.refresh_line),
              tooltip: 'Restore Selected',
              onPressed: selectedPaths.isEmpty ? null : _restoreSelectedItems,
            ),
            IconButton(
              icon: const Icon(remix.Remix.delete_bin_2_line),
              tooltip: 'Delete Selected',
              onPressed: selectedPaths.isEmpty ? null : _deleteSelectedItems,
            ),
          ] else ...[
            IconButton(
              icon: const Icon(remix.Remix.checkbox_line),
              tooltip: 'Select Items',
              onPressed: _trashItems.isEmpty ? null : _toggleSelectionMode,
            ),
            if (Platform.isWindows && _showSystemOptions)
              IconButton(
                icon: const Icon(remix.Remix.external_link_line),
                tooltip: 'Open Recycle Bin',
                onPressed: _openSystemRecycleBin,
              ),
            IconButton(
              icon: const Icon(remix.Remix.delete_bin_line),
              tooltip: 'Empty Trash',
              onPressed: _trashItems.isEmpty ? null : _emptyTrash,
            ),
          ],
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                remix.Remix.alert_line,
                color: Colors.red,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadTrashItems,
                icon: const Icon(remix.Remix.refresh_line),
                label: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    if (_trashItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              remix.Remix.delete_bin_2_line,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            const Text(
              'Trash is empty',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Items you delete will appear here',
              style: TextStyle(
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadTrashItems,
              icon: const Icon(remix.Remix.refresh_line),
              label: const Text('Refresh'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadTrashItems,
      child: ListView.builder(
        itemCount: _trashItems.length,
        itemBuilder: (context, index) {
          final item = _trashItems[index];
          final isSelected = selectedPaths.contains(item.trashFileName);

          return ListTile(
            leading: _getFileIcon(item.displayNameValue),
            title: Text(
              item.displayNameValue,
              style: item.isSystemTrashItem
                  ? TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    )
                  : null,
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Original location: ${item.originalPath}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Row(
                  children: [
                    Text(
                      'Deleted: ${_formatDate(item.trashedDate)} • ${_formatFileSize(item.size)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    if (item.isSystemTrashItem) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'System',
                          style: TextStyle(
                            fontSize: 10,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            isThreeLine: true,
            selected: isSelected,
            trailing: isSelectionMode
                ? Checkbox(
                    value: isSelected,
                    onChanged: (value) =>
                        _toggleItemSelection(item.trashFileName),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(remix.Remix.refresh_line, size: 20),
                        tooltip: 'Restore',
                        onPressed: () => _restoreItem(item),
                      ),
                      IconButton(
                        icon:
                            const Icon(remix.Remix.delete_bin_2_line, size: 20),
                        tooltip: 'Delete permanently',
                        onPressed: () => _deleteItem(item),
                      ),
                    ],
                  ),
            onTap: isSelectionMode
                ? () => _toggleItemSelection(item.trashFileName)
                : null,
            onLongPress: () {
              if (!isSelectionMode) {
                _toggleSelectionMode();
                _toggleItemSelection(item.trashFileName);
              }
            },
          );
        },
      ),
    );
  }

  Widget _getFileIcon(String fileName) {
    // Use FileTypeUtils to determine file type
    if (FileTypeUtils.isImageFile(fileName)) {
      return const CircleAvatar(
        backgroundColor: Colors.blue,
        child: Icon(remix.Remix.image_line, color: Colors.white),
      );
    }

    // Video file
    if (FileTypeUtils.isVideoFile(fileName)) {
      return const CircleAvatar(
        backgroundColor: Colors.red,
        child: Icon(remix.Remix.video_line, color: Colors.white),
      );
    }

    // Audio file
    if (FileTypeUtils.isAudioFile(fileName)) {
      return const CircleAvatar(
        backgroundColor: Colors.purple,
        child: Icon(remix.Remix.music_2_line, color: Colors.white),
      );
    }

    // Document file
    if (FileTypeUtils.isDocumentFile(fileName) ||
        FileTypeUtils.isSpreadsheetFile(fileName) ||
        FileTypeUtils.isPresentationFile(fileName)) {
      return const CircleAvatar(
        backgroundColor: Colors.orange,
        child: Icon(remix.Remix.file_text_line, color: Colors.white),
      );
    }

    // Default icon
    return const CircleAvatar(
      backgroundColor: Colors.grey,
      child: Icon(remix.Remix.file_3_line, color: Colors.white),
    );
  }
}
