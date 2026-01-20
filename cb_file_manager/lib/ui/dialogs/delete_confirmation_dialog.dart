import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A delete confirmation dialog with keyboard support and visual focus indication
/// - Enter key confirms deletion (focused on delete button by default)
/// - Esc key cancels
/// - Tab key navigates between buttons
class DeleteConfirmationDialog extends StatefulWidget {
  final String title;
  final String message;
  final String confirmText;
  final String cancelText;

  const DeleteConfirmationDialog({
    Key? key,
    required this.title,
    required this.message,
    required this.confirmText,
    required this.cancelText,
  }) : super(key: key);

  @override
  State<DeleteConfirmationDialog> createState() =>
      _DeleteConfirmationDialogState();
}

class _DeleteConfirmationDialogState extends State<DeleteConfirmationDialog> {
  final FocusNode _dialogFocusNode = FocusNode();
  final FocusNode _confirmButtonFocusNode = FocusNode();
  final FocusNode _cancelButtonFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // Auto-focus the confirm (delete) button after dialog is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _confirmButtonFocusNode.requestFocus();
    });
    
    // Listen to focus changes to rebuild UI
    _confirmButtonFocusNode.addListener(_onFocusChange);
    _cancelButtonFocusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    // Rebuild when focus changes to update visual indicators
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _confirmButtonFocusNode.removeListener(_onFocusChange);
    _cancelButtonFocusNode.removeListener(_onFocusChange);
    _dialogFocusNode.dispose();
    _confirmButtonFocusNode.dispose();
    _cancelButtonFocusNode.dispose();
    super.dispose();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      // Enter key to confirm (when confirm button is focused)
      if (event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.numpadEnter) {
        if (_confirmButtonFocusNode.hasFocus) {
          Navigator.of(context).pop(true);
          return KeyEventResult.handled;
        } else if (_cancelButtonFocusNode.hasFocus) {
          Navigator.of(context).pop(false);
          return KeyEventResult.handled;
        }
      }
      // Escape key to cancel
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        Navigator.of(context).pop(false);
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Focus(
      focusNode: _dialogFocusNode,
      onKeyEvent: _handleKeyEvent,
      child: AlertDialog(
        title: Text(widget.title),
        content: Text(widget.message),
        actions: [
          // Cancel button
          Focus(
            focusNode: _cancelButtonFocusNode,
            child: Builder(
              builder: (context) {
                final isFocused = _cancelButtonFocusNode.hasFocus;
                return TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  style: TextButton.styleFrom(
                    backgroundColor: isFocused 
                        ? colorScheme.primary.withOpacity(0.1)
                        : null,
                    side: isFocused 
                        ? BorderSide(color: colorScheme.primary, width: 2)
                        : null,
                  ),
                  child: Text(widget.cancelText),
                );
              },
            ),
          ),
          const SizedBox(width: 8),
          // Confirm (Delete) button - auto-focused
          Focus(
            focusNode: _confirmButtonFocusNode,
            child: Builder(
              builder: (context) {
                final isFocused = _confirmButtonFocusNode.hasFocus;
                return TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                    backgroundColor: isFocused 
                        ? Colors.red.withOpacity(0.1)
                        : null,
                    side: isFocused 
                        ? const BorderSide(color: Colors.red, width: 2)
                        : null,
                  ),
                  child: Text(
                    widget.confirmText,
                    style: TextStyle(
                      fontWeight: isFocused ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
