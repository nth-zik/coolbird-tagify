import 'dart:io';
import 'package:flutter/material.dart';
import 'package:remixicon/remixicon.dart' as remix;

/// Widget hiển thị thanh địa chỉ có thể nhấn để thay đổi đường dẫn
/// Component này có thể tái sử dụng trong nhiều màn hình khác nhau
class AddressBarWidget extends StatelessWidget {
  final String path;
  final String name;
  final VoidCallback onTap;
  final bool isDarkMode;
  final bool showDropdownIndicator;

  const AddressBarWidget({
    Key? key,
    required this.path,
    required this.name,
    required this.onTap,
    required this.isDarkMode,
    this.showDropdownIndicator = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20.0),
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12.0),
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
          borderRadius: BorderRadius.circular(20.0),
          border: Border.all(
            color: isDarkMode
                ? Colors.grey[700]!
                : theme.colorScheme.outline.withOpacity(0.3),
          ),
        ),
        child: Row(
          children: [
            Icon(
              remix.Remix.folder_3_line,
              size: 16,
              color: isDarkMode ? Colors.white70 : Colors.black87,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: path.isEmpty
                  ? Text(
                      name,
                      style: TextStyle(
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                      overflow: TextOverflow.ellipsis,
                    )
                  : _buildPathDisplay(context, path),
            ),
            if (showDropdownIndicator)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  remix.Remix.arrow_down_lineOutline,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPathDisplay(BuildContext context, String path) {
    final theme = Theme.of(context);

    // For empty path (drives view)
    if (path.isEmpty) {
      return Row(
        children: [
          Icon(remix.Remix.computer_lineOutline,
              size: 14, color: theme.colorScheme.primary),
          const SizedBox(width: 4),
          Text(
            'Thiết bị lưu trữ',
            style: TextStyle(
              color: isDarkMode ? Colors.white : Colors.black87,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    }

    // Handle path separators and display only the last part with parent
    final parts = path
        .split(Platform.pathSeparator)
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) {
      return Text(
        Platform.isWindows ? 'Thiết bị lưu trữ' : '/',
        style: TextStyle(
          color: isDarkMode ? Colors.white : Colors.black87,
        ),
      );
    }

    // Get last part of the path
    final lastPart = parts.last;

    // If we have parent folders, show a truncated path
    if (parts.length > 1) {
      final parentFolder = parts[parts.length - 2];
      return Row(
        children: [
          Flexible(
            child: Text(
              '.../$parentFolder/',
              style: TextStyle(
                color: isDarkMode ? Colors.grey[400] : Colors.grey[700],
                fontSize: 13,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Flexible(
            flex: 2,
            child: Text(
              lastPart,
              style: TextStyle(
                color: isDarkMode ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }

    // If it's just one level deep, show the full path
    return Text(
      lastPart,
      style: TextStyle(
        color: isDarkMode ? Colors.white : Colors.black87,
        fontWeight: FontWeight.w500,
      ),
      overflow: TextOverflow.ellipsis,
    );
  }
}
