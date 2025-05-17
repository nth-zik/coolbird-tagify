import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Thêm import để xử lý sự kiện bàn phím
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:eva_icons_flutter/eva_icons_flutter.dart';
import 'package:cb_file_manager/helpers/tag_manager.dart';
import 'package:cb_file_manager/ui/screens/folder_list/folder_list_bloc.dart';
import 'package:cb_file_manager/ui/screens/folder_list/folder_list_event.dart';
import 'dart:io';
import 'package:path/path.dart' as pathlib;

/// Thanh tìm kiếm nằm trực tiếp trên thanh công cụ
class SearchBar extends StatefulWidget {
  final String currentPath;
  final VoidCallback onCloseSearch;

  const SearchBar({
    Key? key,
    required this.currentPath,
    required this.onCloseSearch,
  }) : super(key: key);

  @override
  State<SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<SearchBar> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _isSearchingTags = false;
  List<String> _suggestedTags = [];
  bool _isGlobalSearch = false;

  // Biến để lưu trữ overlay entry
  OverlayEntry? _overlayEntry;

  // Biến để theo dõi tag đang được chọn trong danh sách gợi ý
  int _selectedTagIndex = -1;
  List<String> _currentTags = [];

  // Key để bọc KeyboardListener

  @override
  void initState() {
    super.initState();
    // Tự động focus vào trường tìm kiếm khi hiển thị
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });

    _searchController.addListener(_onSearchChanged);

    // Tải các tag phổ biến
    _loadPopularTags();
  }

  Future<void> _loadPopularTags() async {
    try {
      final popularTags = await TagManager.instance.getPopularTags(limit: 10);
      setState(() {
        _suggestedTags = popularTags.keys.toList();
      });
    } catch (e) {
      debugPrint('Error loading popular tags: $e');
    }
  }

  @override
  void dispose() {
    // Đảm bảo xóa overlay khi widget bị hủy
    _removeOverlay();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  // Xóa overlay khi không cần thiết nữa
  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();

    // Kiểm tra xem có đang tìm kiếm theo tag không
    if (query.contains('#')) {
      final int hashPosition = query.lastIndexOf('#');
      final String tagQuery = query.substring(hashPosition + 1).trim();

      // Khi người dùng nhập sau dấu #, hiển thị và cập nhật gợi ý autocomplete
      if (_searchFocusNode.hasFocus) {
        // Nếu overlay đang hiển thị và có query mới, cập nhật kết quả
        if (_overlayEntry != null) {
          _updateTagSuggestions(tagQuery);
        } else if (query.endsWith('#') || tagQuery.isNotEmpty) {
          // Hiển thị gợi ý khi người dùng gõ # hoặc có ký tự sau #
          _showTagSuggestionsDialog(tagQuery);
        }
      }

      setState(() {
        _isSearchingTags = true;
      });
    } else {
      setState(() {
        _isSearchingTags = false;
      });
      // Đóng overlay nếu không còn tìm kiếm theo tag
      _removeOverlay();
    }
  }

  // Cập nhật danh sách gợi ý tag dựa trên input
  Future<void> _updateTagSuggestions(String tagQuery) async {
    List<String> tags = [];

    if (tagQuery.isEmpty) {
      // Nếu không có query, hiển thị các tag phổ biến
      tags = _suggestedTags;
    } else {
      // Tìm kiếm tag phù hợp với query
      tags = await TagManager.instance.searchTags(tagQuery);
    }

    // Cập nhật danh sách tag và UI
    if (mounted) {
      setState(() {
        _currentTags = List.from(tags);
        // Reset lựa chọn khi danh sách thay đổi
        _selectedTagIndex = tags.isNotEmpty ? 0 : -1;
      });

      // Cập nhật overlay nếu đang hiển thị
      _updateOverlay();
    }
  }

  // Hiển thị gợi ý tag bằng Overlay (thay vì Dialog) để không block input
  void _showTagSuggestionsDialog(String tagQuery) async {
    // Đảm bảo xóa overlay cũ nếu có
    _removeOverlay();

    // Tìm kiếm tag phù hợp
    List<String> tags = [];
    if (tagQuery.isEmpty) {
      tags = _suggestedTags;
    } else {
      tags = await TagManager.instance.searchTags(tagQuery);
    }

    // Nếu không có kết quả và không có query, không hiển thị
    if (tags.isEmpty && tagQuery.isEmpty) return;

    // Nếu không mounted, không tiếp tục
    if (!mounted) return;

    // Reset chỉ mục tag được chọn
    _selectedTagIndex = tags.isNotEmpty ? 0 : -1;
    _currentTags = List.from(tags);

    // Lấy vị trí của textfield để định vị overlay
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Tạo overlay entry mới
    _overlayEntry = OverlayEntry(
      builder: (context) {
        return Positioned(
          top: offset.dy + size.height + 4, // Hiển thị ngay dưới text field
          left: offset.dx + 12,
          width: size.width - 24,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(16),
            color: Colors.transparent,
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[850] : theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
                border: Border.all(
                  color: theme.colorScheme.outline.withOpacity(0.2),
                  width: 1,
                ),
              ),
              constraints: BoxConstraints(
                maxHeight: 300,
                minWidth: size.width - 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Tags gợi ý (${_currentTags.length} kết quả)',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                        // Nút đóng overlay
                        InkWell(
                          onTap: _removeOverlay,
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(4.0),
                            child: Icon(
                              EvaIcons.close,
                              size: 16,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, thickness: 1),
                  _currentTags.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            'Không tìm thấy tag phù hợp',
                            style: TextStyle(
                              fontStyle: FontStyle.italic,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        )
                      : Flexible(
                          child: ListView.builder(
                            shrinkWrap: true,
                            padding: EdgeInsets.zero,
                            itemCount: _currentTags.length,
                            itemBuilder: (context, index) {
                              final bool isSelected =
                                  index == _selectedTagIndex;
                              return InkWell(
                                onTap: () {
                                  // Xử lý khi chọn tag
                                  _applySelectedTag(_currentTags[index]);
                                  _removeOverlay();
                                },
                                child: Container(
                                  color: isSelected
                                      ? theme.colorScheme.primaryContainer
                                          .withOpacity(0.5)
                                      : Colors.transparent,
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 8.0, horizontal: 16.0),
                                  child: Row(
                                    children: [
                                      Icon(
                                        EvaIcons.shoppingBag,
                                        size: 16,
                                        color: isSelected
                                            ? theme.colorScheme.primary
                                            : theme.colorScheme.primary
                                                .withOpacity(0.7),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          _currentTags[index],
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: isSelected
                                                ? theme.colorScheme
                                                    .onPrimaryContainer
                                                : theme.colorScheme.onSurface,
                                            fontWeight: isSelected
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                          ),
                                        ),
                                      ),
                                      if (isSelected)
                                        Icon(
                                          EvaIcons.arrowRight,
                                          size: 14,
                                          color: theme.colorScheme.primary,
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                ],
              ),
            ),
          ),
        );
      },
    );

    // Hiển thị overlay
    Overlay.of(context).insert(_overlayEntry!);

    // Đảm bảo focus vẫn ở text field và keyboard listener cũng được focus
    _searchFocusNode.requestFocus();
  }

  // Áp dụng tag đã chọn vào text input
  void _applySelectedTag(String tag) {
    if (!mounted) return;

    debugPrint('Applying selected tag: $tag');

    // Cập nhật text input với tag đã chọn
    final text = _searchController.text;
    final hashIndex = text.lastIndexOf('#');
    final newText = text.substring(0, hashIndex + 1) + tag;

    // Cập nhật văn bản và vị trí con trỏ
    setState(() {
      _searchController.text = newText;
      _searchController.selection = TextSelection.fromPosition(
        TextPosition(offset: newText.length),
      );
    });

    // Đảm bảo cập nhật UI
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();

      // Tự động thực hiện tìm kiếm sau khi chọn tag
      _performSearch();
    });

    debugPrint(
        'Applied tag. New text: $newText - Performing search automatically');
  }

  void _performSearch() {
    final query = _searchController.text.trim();

    if (query.isEmpty) {
      return;
    }

    final folderListBloc = BlocProvider.of<FolderListBloc>(context);
    debugPrint('Performing search with query: "$query"');

    // Kiểm tra xem có đang tìm kiếm theo tag không
    if (query.contains('#')) {
      final int hashPosition = query.lastIndexOf('#');
      String tagQuery = query.substring(hashPosition + 1).trim();

      debugPrint('Detected tag search. Tag query: "$tagQuery"');

      if (tagQuery.isNotEmpty) {
        // Xóa cache để đảm bảo dữ liệu mới nhất
        TagManager.clearCache();

        // Thông báo trạng thái tìm kiếm
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isGlobalSearch
                ? 'Đang tìm kiếm tag "$tagQuery" trên toàn hệ thống...'
                : 'Đang tìm kiếm tag "$tagQuery" trong thư mục hiện tại...'),
            duration: const Duration(seconds: 1),
          ),
        );

        // Thực hiện tìm kiếm theo tag
        if (_isGlobalSearch) {
          debugPrint('Searching for tag globally: "$tagQuery"');
          folderListBloc.add(SearchByTagGlobally(tagQuery));

          // Show loading indicator for global search (which takes longer)
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text('Đang tìm kiếm tag "$tagQuery" trên toàn hệ thống...'),
                ],
              ),
              duration: const Duration(seconds: 3),
            ),
          );
        } else {
          debugPrint('Searching for tag in current directory: "$tagQuery"');
          folderListBloc.add(SearchByTag(tagQuery));
        }
      }
    } else {
      // Tìm kiếm theo tên file
      debugPrint('Searching by filename: "$query"');
      folderListBloc.add(SearchByFileName(query));
    }
  }

  // Phương thức xử lý phím mũi tên để điều hướng trong danh sách gợi ý

  // Cập nhật overlay khi thay đổi lựa chọn
  void _updateOverlay() {
    if (_overlayEntry != null) {
      _overlayEntry!.markNeedsBuild();
    }
  }

  /// Helper method to scan a specific folder for files with a given tag
  /// This helps with lazy loading of tag search results in deeper directories
  Future<void> _scanFolderForTaggedFiles(String folderPath, String tag) async {
    try {
      // Check if folder exists
      final folder = Directory(folderPath);
      if (!await folder.exists()) {
        return;
      }

      // Inform user we're scanning
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Đang quét thư mục ${pathlib.basename(folderPath)} cho tag "$tag"...'),
            duration: const Duration(milliseconds: 800),
          ),
        );
      }

      // Use TagManager to find files with tag in this specific folder
      final results = await TagManager.findFilesByTag(folderPath, tag);

      if (results.isNotEmpty && mounted) {
        // Add these results to the main search
        final folderListBloc = BlocProvider.of<FolderListBloc>(context);
        folderListBloc.add(AddTagSearchResults(results));

        // Notify user of results
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Tìm thấy thêm ${results.length} kết quả trong ${pathlib.basename(folderPath)}'),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error scanning folder $folderPath: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: double.infinity,
      height: 48,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: _isSearchingTags
              ? theme.colorScheme.primary.withOpacity(0.5)
              : theme.colorScheme.outline.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 4),
          // Animated icon that changes between search and tag
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (Widget child, Animation<double> animation) {
              return ScaleTransition(scale: animation, child: child);
            },
            child: _isSearchingTags
                ? Icon(
                    EvaIcons.shoppingBag,
                    key: const ValueKey('tagIcon'),
                    color: theme.colorScheme.primary,
                  )
                : Icon(
                    EvaIcons.search,
                    key: const ValueKey('searchIcon'),
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
          ),
          Expanded(
            child: Focus(
              // Bắt sự kiện phím mũi tên và ngăn chặn nó lan truyền
              onKeyEvent: (FocusNode node, KeyEvent event) {
                if (_overlayEntry != null &&
                    _currentTags.isNotEmpty &&
                    _isSearchingTags) {
                  if (event is KeyDownEvent) {
                    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                      setState(() {
                        if (_selectedTagIndex < _currentTags.length - 1) {
                          _selectedTagIndex++;
                        } else {
                          _selectedTagIndex = 0; // Quay lại đầu danh sách
                        }
                      });
                      _updateOverlay();
                      return KeyEventResult.handled; // Chặn sự kiện này
                    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                      setState(() {
                        if (_selectedTagIndex > 0) {
                          _selectedTagIndex--;
                        } else {
                          _selectedTagIndex = _currentTags.length -
                              1; // Chuyển đến cuối danh sách
                        }
                      });
                      _updateOverlay();
                      return KeyEventResult.handled; // Chặn sự kiện này
                    } else if ((event.logicalKey == LogicalKeyboardKey.enter ||
                            event.logicalKey == LogicalKeyboardKey.tab) &&
                        _selectedTagIndex >= 0) {
                      // Chọn tag hiện tại khi nhấn Enter hoặc Tab
                      _applySelectedTag(_currentTags[_selectedTagIndex]);
                      _removeOverlay();
                      return KeyEventResult.handled;
                    } else if (event.logicalKey == LogicalKeyboardKey.escape) {
                      // Đóng overlay khi nhấn ESC
                      _removeOverlay();
                      return KeyEventResult.handled;
                    }
                  }
                }
                return KeyEventResult
                    .ignored; // Cho phép các phím khác hoạt động bình thường
              },
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                style: TextStyle(
                  fontSize: 15,
                  color: theme.colorScheme.onSurface,
                ),
                decoration: InputDecoration(
                  hintText: _isSearchingTags
                      ? 'Tìm theo tag... (ví dụ: #important)'
                      : 'Tìm kiếm tệp hoặc dùng # để tìm theo tag',
                  hintStyle: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  isDense: true,
                ),
                onSubmitted: (_) => _performSearch(),
              ),
            ),
          ),
          // Tag suggestion button - Only show when in tag search mode
          if (_isSearchingTags)
            Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () {
                  final query = _searchController.text;
                  if (query.contains('#')) {
                    final hashPosition = query.lastIndexOf('#');
                    final tagQuery = query.substring(hashPosition + 1).trim();
                    _showTagSuggestionsDialog(tagQuery);
                  }
                },
                child: Tooltip(
                  message: 'Xem gợi ý tag',
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Icon(
                      EvaIcons.listOutline,
                      color: theme.colorScheme.primary,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ),
          // Global search toggle button
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                setState(() {
                  _isGlobalSearch = !_isGlobalSearch;
                });
                // Hiển thị snackbar ngắn khi chuyển chế độ
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(_isGlobalSearch
                        ? 'Đã chuyển sang tìm kiếm toàn cục'
                        : 'Đã chuyển sang tìm kiếm thư mục hiện tại'),
                    duration: const Duration(milliseconds: 1000),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    margin: const EdgeInsets.all(8),
                  ),
                );
              },
              child: Tooltip(
                message: _isGlobalSearch
                    ? 'Đang tìm kiếm toàn cục (nhấn để chuyển)'
                    : 'Đang tìm kiếm thư mục hiện tại (nhấn để chuyển)',
                child: Container(
                  padding: const EdgeInsets.all(8),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _isGlobalSearch
                        ? Icon(
                            EvaIcons.globe2Outline,
                            key: const ValueKey('globalIcon'),
                            color: theme.colorScheme.primary,
                            size: 20,
                          )
                        : Icon(
                            EvaIcons.folderOutline,
                            key: const ValueKey('folderIcon'),
                            size: 20,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                  ),
                ),
              ),
            ),
          ),
          // Search button
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: _performSearch,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Icon(
                  EvaIcons.search,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
              ),
            ),
          ),
          // Close button
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: widget.onCloseSearch,
              child: Tooltip(
                message: 'Đóng',
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Icon(
                    EvaIcons.close,
                    color: theme.colorScheme.onSurfaceVariant,
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}
