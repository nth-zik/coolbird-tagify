import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cb_file_manager/helpers/io_extensions.dart';
import 'package:cb_file_manager/ui/screens/folder_list/folder_list_state.dart';
import 'package:eva_icons_flutter/eva_icons_flutter.dart';
import 'package:flutter/services.dart';
import 'package:cb_file_manager/ui/components/shared_file_context_menu.dart';

class FolderDetailsItem extends StatefulWidget {
  final Directory folder;
  final Function(String)? onTap;
  final bool isSelected;
  final ColumnVisibility columnVisibility;
  final Function(String, {bool shiftSelect, bool ctrlSelect})?
      toggleFolderSelection;
  final bool isDesktopMode;
  final String? lastSelectedPath;

  const FolderDetailsItem({
    Key? key,
    required this.folder,
    this.onTap,
    this.isSelected = false,
    required this.columnVisibility,
    this.toggleFolderSelection,
    this.isDesktopMode = false,
    this.lastSelectedPath,
  }) : super(key: key);

  @override
  State<FolderDetailsItem> createState() => _FolderDetailsItemState();
}

class _FolderDetailsItemState extends State<FolderDetailsItem> {
  bool _isHovering = false;
  bool _visuallySelected = false;
  FileStat? _fileStat;

  @override
  void initState() {
    super.initState();
    _visuallySelected = widget.isSelected;
    _loadFolderStats();
  }

  @override
  void didUpdateWidget(FolderDetailsItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSelected != oldWidget.isSelected) {
      setState(() {
        _visuallySelected = widget.isSelected;
      });
    }

    if (widget.folder.path != oldWidget.folder.path) {
      _loadFolderStats();
    }
  }

  Future<void> _loadFolderStats() async {
    try {
      final stat = await widget.folder.stat();
      if (mounted) {
        setState(() {
          _fileStat = stat;
        });
      }
    } catch (e) {
      print('Error loading folder stats: $e');
    }
  }

  void _handleFolderSelection() {
    if (widget.toggleFolderSelection == null) return;

    // Check for Shift and Ctrl keys
    final HardwareKeyboard keyboard = HardwareKeyboard.instance;
    final bool isShiftPressed = keyboard.isShiftPressed;
    final bool isCtrlPressed =
        keyboard.isControlPressed || keyboard.isMetaPressed;

    // Log selection attempt
    print("Folder selection: ${widget.folder.path}");
    print("Shift: $isShiftPressed, Ctrl: $isCtrlPressed");

    // Visual update for immediate feedback
    if (!isShiftPressed) {
      setState(() {
        if (!isCtrlPressed) {
          // Single selection without Ctrl: this item will be selected
          _visuallySelected = true;
        } else {
          // Ctrl+click: toggle this item's selection
          _visuallySelected = !_visuallySelected;
        }
      });
    }

    // Call toggleFolderSelection with appropriate parameters
    widget.toggleFolderSelection!(
      widget.folder.path,
      shiftSelect: isShiftPressed,
      ctrlSelect: isCtrlPressed,
    );
  }

  void _showFolderContextMenu(BuildContext context) {
    // Use the shared folder context menu
    showFolderContextMenu(
      context: context,
      folder: widget.folder,
      onNavigate: widget.onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // Calculate colors based on selection state
    final Color itemBackgroundColor = _visuallySelected
        ? Theme.of(context).primaryColor.withOpacity(0.15)
        : _isHovering && widget.isDesktopMode
            ? isDarkMode
                ? Colors.grey[800]!
                : Colors.grey[100]!
            : Colors.transparent;

    final BoxDecoration boxDecoration = _visuallySelected
        ? BoxDecoration(
            color: itemBackgroundColor,
          )
        : BoxDecoration(
            color: itemBackgroundColor,
          );

    return GestureDetector(
      onSecondaryTap: () => _showFolderContextMenu(context),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovering = true),
        onExit: (_) => setState(() => _isHovering = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () {
            if (widget.isDesktopMode && widget.toggleFolderSelection != null) {
              _handleFolderSelection();
            } else if (widget.onTap != null) {
              widget.onTap!(widget.folder.path);
            }
          },
          onDoubleTap: widget.isDesktopMode
              ? () {
                  if (widget.onTap != null) {
                    widget.onTap!(widget.folder.path);
                  }
                }
              : null,
          child: Container(
            decoration: boxDecoration,
            child: Row(
              children: [
                // Name column (always visible)
                Expanded(
                  flex: 3,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12.0, vertical: 10.0),
                    child: Row(
                      children: [
                        const Icon(EvaIcons.folderOutline, color: Colors.amber),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            widget.folder.basename(),
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: _visuallySelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Type column
                if (widget.columnVisibility.type)
                  Expanded(
                    flex: 2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12.0, vertical: 10.0),
                      child: const Text(
                        'Thư mục',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),

                // Size column
                if (widget.columnVisibility.size)
                  Expanded(
                    flex: 1,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12.0, vertical: 10.0),
                      child: const Text(
                        '', // Folders don't typically show size in explorer
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),

                // Date modified column
                if (widget.columnVisibility.dateModified)
                  Expanded(
                    flex: 2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12.0, vertical: 10.0),
                      child: Text(
                        _fileStat != null
                            ? _fileStat!.modified.toString().split('.')[0]
                            : 'Loading...',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),

                // Date created column
                if (widget.columnVisibility.dateCreated)
                  Expanded(
                    flex: 2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12.0, vertical: 10.0),
                      child: Text(
                        _fileStat != null
                            ? _fileStat!.changed.toString().split('.')[0]
                            : 'Loading...',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),

                // Attributes column
                if (widget.columnVisibility.attributes)
                  Expanded(
                    flex: 1,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12.0, vertical: 10.0),
                      child: Text(
                        _getAttributes(_fileStat),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getAttributes(FileStat? stat) {
    if (stat == null) return '';

    final List<String> attrs = [];

    if (stat.modeString()[0] == 'd') attrs.add('D');
    if (stat.modeString()[1] == 'r') attrs.add('R');
    if (stat.modeString()[2] == 'w') attrs.add('W');
    if (stat.modeString()[3] == 'x') attrs.add('X');

    return attrs.join(' ');
  }
}
