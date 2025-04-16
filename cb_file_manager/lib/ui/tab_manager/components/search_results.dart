import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../screens/folder_list/folder_list_bloc.dart';
import '../../screens/folder_list/folder_list_event.dart';
import '../../screens/folder_list/folder_list_state.dart';
import '../../screens/folder_list/components/index.dart';

/// Component that displays search results header and list
class SearchResultsView extends StatelessWidget {
  final FolderListState state;
  final bool isSelectionMode;
  final List<String> selectedFiles;
  final Function(String) toggleFileSelection;
  final Function() toggleSelectionMode;
  final Function(BuildContext, String, List<String>) showDeleteTagDialog;
  final Function(BuildContext, String) showAddTagToFileDialog;
  final Function() onClearSearch;

  const SearchResultsView({
    Key? key,
    required this.state,
    required this.isSelectionMode,
    required this.selectedFiles,
    required this.toggleFileSelection,
    required this.toggleSelectionMode,
    required this.showDeleteTagDialog,
    required this.showAddTagToFileDialog,
    required this.onClearSearch,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildSearchHeader(context),
        Expanded(
          child: _buildSearchResultsList(context),
        ),
      ],
    );
  }

  // Build header for search results
  Widget _buildSearchHeader(BuildContext context) {
    String searchTitle = '';
    IconData searchIcon;

    // Determine the search type and appropriate display
    if (state.isSearchByName) {
      searchTitle = 'Search results for name: "${state.currentSearchQuery}"';
      searchIcon = Icons.search;
    } else {
      searchTitle = 'Search results for tag: "${state.currentSearchTag}"';
      searchIcon = Icons.label;
    }

    return Container(
      color: Colors.grey[100],
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Icon(searchIcon, size: 20, color: Colors.blue),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              searchTitle,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          TextButton.icon(
            icon: const Icon(Icons.clear),
            label: const Text('Clear'),
            onPressed: onClearSearch,
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResultsList(BuildContext context) {
    return FileView(
      files: state.searchResults.whereType<File>().toList(),
      folders: const [], // No folders in search results view
      state: state,
      isSelectionMode: isSelectionMode,
      isGridView: state.viewMode == ViewMode.grid,
      selectedFiles: selectedFiles,
      toggleFileSelection: toggleFileSelection,
      toggleSelectionMode: toggleSelectionMode,
      showDeleteTagDialog: showDeleteTagDialog,
      showAddTagToFileDialog: showAddTagToFileDialog,
    );
  }
}
