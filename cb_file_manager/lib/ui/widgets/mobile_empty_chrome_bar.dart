import 'package:flutter/material.dart';
import 'package:remixicon/remixicon.dart' as remix;
import 'package:cb_file_manager/ui/shared/address_bar_widget.dart';

class MobileEmptyChromeBar extends StatelessWidget {
  final bool isDarkMode;
  final VoidCallback onMenu;
  final VoidCallback onAddNewTab;
  final VoidCallback onMore;
  final VoidCallback onAddressTap;

  const MobileEmptyChromeBar({
    Key? key,
    required this.isDarkMode,
    required this.onMenu,
    required this.onAddNewTab,
    required this.onMore,
    required this.onAddressTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final backgroundColor = isDarkMode ? Colors.black : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: backgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(remix.Remix.menu_line, color: textColor),
            onPressed: onMenu,
          ),
          Expanded(
            child: AddressBarWidget(
              path: "",
              name: "CoolBird Tagify",
              onTap: onAddressTap,
              isDarkMode: isDarkMode,
              showDropdownIndicator: true,
            ),
          ),
          IconButton(
            icon: Icon(remix.Remix.add_line, color: textColor),
            tooltip: 'Add new tab',
            onPressed: onAddNewTab,
          ),
          IconButton(
            icon: Icon(remix.Remix.more_2_line, color: textColor),
            onPressed: onMore,
          ),
        ],
      ),
    );
  }
}

