import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cb_file_manager/helpers/core/io_extensions.dart';
import '../../../components/common/shared_file_context_menu.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../bloc/selection/selection_bloc.dart';
import '../../../../bloc/selection/selection_event.dart';
import 'folder_thumbnail.dart';
import '../../../components/common/optimized_interaction_handler.dart';

class FolderGridItem extends StatefulWidget {
  final Directory folder;
  final Function(String) onNavigate;
  final bool isSelected;
  final Function(String, {bool shiftSelect, bool ctrlSelect})?
      toggleFolderSelection;
  final bool isDesktopMode;
  final String? lastSelectedPath;
  final Function()? clearSelectionMode;

  const FolderGridItem({
    Key? key,
    required this.folder,
    required this.onNavigate,
    this.isSelected = false,
    this.toggleFolderSelection,
    this.isDesktopMode = false,
    this.lastSelectedPath,
    this.clearSelectionMode,
  }) : super(key: key);

  @override
  State<FolderGridItem> createState() => _FolderGridItemState();
}

class _FolderGridItemState extends State<FolderGridItem> {
  bool _isHovering = false;
  bool _visuallySelected = false;

  @override
  void initState() {
    super.initState();
    _visuallySelected = widget.isSelected;
  }

  @override
  void didUpdateWidget(FolderGridItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only update when external selection state changes
    if (widget.isSelected != oldWidget.isSelected) {
      _visuallySelected = widget.isSelected;
    }
  }

  // Handle folder selection with immediate visual feedback
  void _handleFolderSelection() {
    if (widget.toggleFolderSelection == null) return;

    // Get keyboard state
    final HardwareKeyboard keyboard = HardwareKeyboard.instance;
    final bool isShiftPressed = keyboard.isShiftPressed;
    final bool isCtrlPressed =
        keyboard.isControlPressed || keyboard.isMetaPressed;

    // Visual update depends on the selection type
    if (!isShiftPressed) {
      // For single selection or Ctrl+click, toggle this item
      setState(() {
        if (!isCtrlPressed) {
          // Single selection: this item will be selected
          _visuallySelected = true;
        } else {
          // Ctrl+click: toggle this item's selection
          _visuallySelected = !_visuallySelected;
        }
      });
    }

    // Call the selection handler with the appropriate modifiers
    widget.toggleFolderSelection!(widget.folder.path,
        shiftSelect: isShiftPressed, ctrlSelect: isCtrlPressed);
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // Flat layout for mobile without a label background.
    if (!widget.isDesktopMode) {
      return GestureDetector(
        onSecondaryTapDown: (details) =>
            _showFolderContextMenu(context, details.globalPosition),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8.0),
          child: Stack(
            children: [
              Column(
                children: [
                  // Thumbnail/Icon section
                  Expanded(
                    flex: 3,
                    child: FolderThumbnail(folder: widget.folder),
                  ),
                  // Text section
                  SizedBox(
                    height: 40,
                    width: double.infinity,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          widget.folder.basename(),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDarkMode ? Colors.white : Colors.black87,
                            fontWeight: _visuallySelected
                                ? FontWeight.bold
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              // Interaction overlay
              Positioned.fill(
                child: OptimizedInteractionLayer(
                  onTap: () {
                    // Navigate to folder on mobile
                    widget.onNavigate(widget.folder.path);
                  },
                  onDoubleTap: () {
                    if (widget.clearSelectionMode != null) {
                      widget.clearSelectionMode!();
                    }
                    widget.onNavigate(widget.folder.path);
                  },
                  onLongPress: () => _showFolderContextMenu(context, null),
                ),
              ),

              // Selected overlay tint (flat)
              if (_visuallySelected)
                IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .primaryColor
                          .withValues(alpha: 0.12),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    // Desktop: flat container with hover/selection cues
    final Color backgroundColor = _visuallySelected
        ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.25)
        : _isHovering
            ? Theme.of(context).colorScheme.surface.withValues(alpha: 0.08)
            : Colors.transparent;

    final Color borderColor = _visuallySelected
        ? Theme.of(context).primaryColor.withValues(alpha: 0.7)
        : _isHovering
            ? Theme.of(context).dividerColor.withValues(alpha: 0.6)
            : Colors.transparent;

    return GestureDetector(
      onSecondaryTapDown: (details) =>
          _showFolderContextMenu(context, details.globalPosition),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovering = true),
        onExit: (_) => setState(() => _isHovering = false),
        cursor: SystemMouseCursors.click,
        child: Container(
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(8.0),
            border: Border.all(
              color: borderColor,
              width: 1.0,
            ),
          ),
          child: Stack(
            children: [
              Column(
                children: [
                  // Thumbnail/Icon section
                  Expanded(
                    flex: 3,
                    child: FolderThumbnail(folder: widget.folder),
                  ),
                  // Text section
                  SizedBox(
                    height: 40,
                    width: double.infinity,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          widget.folder.basename(),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDarkMode ? Colors.white : Colors.black87,
                            fontWeight: _visuallySelected
                                ? FontWeight.bold
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Positioned.fill(
                child: OptimizedInteractionLayer(
                  onTap: () {
                    if (widget.isDesktopMode &&
                        widget.toggleFolderSelection != null) {
                      _handleFolderSelection();
                    } else {
                      widget.onNavigate(widget.folder.path);
                    }
                  },
                  onDoubleTap: () {
                    if (widget.clearSelectionMode != null) {
                      widget.clearSelectionMode!();
                    }
                    widget.onNavigate(widget.folder.path);
                  },
                  onLongPress: () => _showFolderContextMenu(context, null),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFolderContextMenu(BuildContext context, Offset? globalPosition) {
    // Check for multiple selection
    try {
      final selectionBloc = context.read<SelectionBloc>();
      final selectionState = selectionBloc.state;

      if (selectionState.allSelectedPaths.length > 1 &&
          selectionState.allSelectedPaths.contains(widget.folder.path)) {
        showMultipleFilesContextMenu(
          context: context,
          selectedPaths: selectionState.allSelectedPaths,
          globalPosition: globalPosition ?? Offset.zero,
          onClearSelection: () {
            selectionBloc.add(ClearSelection());
          },
        );
        return;
      }
    } catch (e) {
      debugPrint('Error showing context menu: $e');
    }

    // Use the shared folder context menu
    showFolderContextMenu(
      context: context,
      folder: widget.folder,
      onNavigate: widget.onNavigate,
      folderTags: [], // Pass empty tags or fetch from database in real implementation
      globalPosition: globalPosition, // Pass position for desktop popup menu
    );
  }
}
