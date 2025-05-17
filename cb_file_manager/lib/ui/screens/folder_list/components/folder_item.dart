import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cb_file_manager/helpers/io_extensions.dart';
import 'package:cb_file_manager/ui/components/shared_file_context_menu.dart';

class FolderItem extends StatefulWidget {
  final Directory folder;
  final Function(String)? onTap;
  final bool isSelected;
  final Function(String, {bool shiftSelect, bool ctrlSelect})?
      toggleFolderSelection;
  final bool isDesktopMode;
  final String? lastSelectedPath;

  const FolderItem({
    Key? key,
    required this.folder,
    this.onTap,
    this.isSelected = false,
    this.toggleFolderSelection,
    this.isDesktopMode = false,
    this.lastSelectedPath,
  }) : super(key: key);

  @override
  State<FolderItem> createState() => _FolderItemState();
}

class _FolderItemState extends State<FolderItem> {
  bool _isHovering = false;
  bool _visuallySelected = false;

  @override
  void initState() {
    super.initState();
    _visuallySelected = widget.isSelected;
  }

  @override
  void didUpdateWidget(FolderItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSelected != oldWidget.isSelected) {
      setState(() {
        _visuallySelected = widget.isSelected;
      });
    }
  }

  void _handleFolderSelection() {
    if (widget.toggleFolderSelection == null) return;

    // Check for Shift and Ctrl keys
    final HardwareKeyboard keyboard = HardwareKeyboard.instance;
    final bool isShiftPressed = keyboard.isShiftPressed;
    final bool isCtrlPressed =
        keyboard.isControlPressed || keyboard.isMetaPressed;

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
    widget.toggleFolderSelection!(widget.folder.path,
        shiftSelect: isShiftPressed, ctrlSelect: isCtrlPressed);
  }

  void _showFolderContextMenu(BuildContext context) {
    // Use the shared folder context menu
    showFolderContextMenu(
      context: context,
      folder: widget.folder,
      onNavigate: widget.onTap,
      folderTags: [], // Pass empty tags or fetch from database in real implementation
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color itemBackgroundColor = _visuallySelected
        ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.7)
        : _isHovering && widget.isDesktopMode
            ? Theme.of(context).hoverColor
            : Theme.of(context).cardColor;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      cursor: SystemMouseCursors.click,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 2.0),
        decoration: BoxDecoration(
          color: itemBackgroundColor,
          borderRadius: BorderRadius.circular(4.0),
        ),
        child: GestureDetector(
          onSecondaryTap: () => _showFolderContextMenu(context),
          onDoubleTap: widget.isDesktopMode
              ? () => widget.onTap?.call(widget.folder.path)
              : null,
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12.0, vertical: 0),
            leading: const Icon(Icons.folder, color: Colors.amber),
            title: Text(
              widget.folder.basename(),
              style: TextStyle(
                fontWeight:
                    _visuallySelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            subtitle: FutureBuilder<FileStat>(
              future: widget.folder.stat(),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  return Text(
                    snapshot.data!.modified.toString().split('.')[0],
                  );
                }
                return const Text('Loading...');
              },
            ),
            onTap: () {
              if (widget.isDesktopMode &&
                  widget.toggleFolderSelection != null) {
                _handleFolderSelection();
              } else if (widget.onTap != null) {
                widget.onTap!(widget.folder.path);
              }
            },
          ),
        ),
      ),
    );
  }
}
