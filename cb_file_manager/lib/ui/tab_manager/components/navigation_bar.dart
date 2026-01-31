import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:remixicon/remixicon.dart' as remix;
import '../core/tab_manager.dart';
import 'address_bar_menu.dart';
import 'path_autocomplete_text_field.dart';

/// Navigation bar component that includes back/forward buttons and path input field
class PathNavigationBar extends StatefulWidget {
  final String tabId;
  final TextEditingController pathController;
  final Function(String) onPathSubmitted;
  final String currentPath;
  final bool isNetworkPath;
  final List<AddressBarMenuItem>? menuItems;

  const PathNavigationBar({
    Key? key,
    required this.tabId,
    required this.pathController,
    required this.onPathSubmitted,
    required this.currentPath,
    this.isNetworkPath = false,
    this.menuItems,
  }) : super(key: key);

  @override
  State<PathNavigationBar> createState() => _PathNavigationBarState();
}

class _PathNavigationBarState extends State<PathNavigationBar> {
  // Lưu trữ tham chiếu đến TabManagerBloc
  TabManagerBloc? _tabBloc;
  bool _canNavigateBack = false;
  bool _canNavigateForward = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Lấy TabManagerBloc mỗi khi dependencies thay đổi
    try {
      _tabBloc = context.read<TabManagerBloc>();
      _updateNavigationState();
    } catch (e) {
      _tabBloc = null;
    }
  }

  void _updateNavigationState() {
    if (_tabBloc != null) {
      setState(() {
        _canNavigateBack = _tabBloc!.canTabNavigateBack(widget.tabId);
        _canNavigateForward = _tabBloc!.canTabNavigateForward(widget.tabId);
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    // Gọi lại _updateNavigationState để đảm bảo trạng thái mới nhất
    if (_tabBloc != null) {
      _updateNavigationState();
    }

    return Row(
      children: [
        IconButton(
          icon: const Icon(remix.Remix.arrow_left_line),
          onPressed: _canNavigateBack
              ? () => BlocProvider.of<TabManagerBloc>(context)
                  .backNavigationToPath(widget.tabId)
              : null,
          tooltip: 'Go back',
        ),
        IconButton(
          icon: const Icon(remix.Remix.arrow_right_line),
          onPressed: _canNavigateForward
              ? () => BlocProvider.of<TabManagerBloc>(context)
                  .forwardNavigationToPath(widget.tabId)
              : null,
          tooltip: 'Go forward',
        ),

        // Special display for network paths
        if (widget.isNetworkPath) ...[
          const Icon(remix.Remix.wifi_line),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _formatNetworkPath(widget.currentPath),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ] else ...[
          Expanded(
            child: PathAutocompleteTextField(
              controller: widget.pathController,
              onSubmitted: widget.onPathSubmitted,
              decoration: InputDecoration(
                hintText: 'Path',
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 8.0,
                  horizontal: 12.0,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Theme.of(context)
                    .inputDecorationTheme
                    .fillColor
                    ?.withValues(alpha: 0.7),
              ),
              textInputAction: TextInputAction.go,
            ),
          ),
        ],
        if (widget.menuItems != null && widget.menuItems!.isNotEmpty)
          AddressBarMenu(
            items: widget.menuItems!,
            tooltip: 'Tùy chọn',
          ),
      ],
    );
  }

  // Format a network path for display
  String _formatNetworkPath(String path) {
    if (!path.startsWith('#network/')) return path;

    try {
      final parts = path.split('/');
      if (parts.length < 3) return path;

      final protocol = parts[1].toUpperCase(); // SMB, FTP, etc.
      final server = Uri.decodeComponent(parts[2]);

      if (parts.length >= 4 && parts[3].startsWith('S')) {
        // We have a share
        final share = Uri.decodeComponent(parts[3].substring(1));

        if (parts.length > 4) {
          // We have a subfolder
          final remainingPath = parts.sublist(4).join('/');
          return '$protocol://$server/$share/$remainingPath';
        } else {
          return '$protocol://$server/$share';
        }
      } else {
        return '$protocol://$server';
      }
    } catch (_) {
      return path;
    }
  }
}
