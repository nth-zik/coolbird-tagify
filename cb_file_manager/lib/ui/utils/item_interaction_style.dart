import 'package:flutter/material.dart';

class ItemInteractionStyle {
  static Color backgroundColor({
    required ThemeData theme,
    required bool isDesktopMode,
    required bool isSelected,
    required bool isHovering,
  }) {
    if (isSelected) {
      return theme.colorScheme.primaryContainer.withValues(alpha: 0.7);
    }

    if (isHovering && isDesktopMode) {
      final bool isDarkMode = theme.brightness == Brightness.dark;
      return isDarkMode ? Colors.grey[800]! : Colors.grey[100]!;
    }

    return Colors.transparent;
  }

  static Color thumbnailOverlayColor({
    required ThemeData theme,
    required bool isDesktopMode,
    required bool isSelected,
    required bool isHovering,
  }) {
    if (isSelected) {
      return theme.colorScheme.primaryContainer.withValues(alpha: 0.35);
    }

    if (isHovering && isDesktopMode) {
      final bool isDarkMode = theme.brightness == Brightness.dark;
      final Color base = isDarkMode ? Colors.grey[800]! : Colors.grey[100]!;
      return base.withValues(alpha: 0.25);
    }

    return Colors.transparent;
  }
}

