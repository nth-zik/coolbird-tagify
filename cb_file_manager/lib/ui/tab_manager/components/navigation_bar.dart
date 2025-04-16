import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../tab_manager.dart';

/// Navigation bar component that includes back/forward buttons and path input field
class PathNavigationBar extends StatelessWidget {
  final String tabId;
  final TextEditingController pathController;
  final Function(String) onPathSubmitted;
  final String currentPath;

  const PathNavigationBar({
    Key? key,
    required this.tabId,
    required this.pathController,
    required this.onPathSubmitted,
    required this.currentPath,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Back button
        IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: context.read<TabManagerBloc>().canTabNavigateBack(tabId)
              ? () {
                  final tabBloc = context.read<TabManagerBloc>();
                  final state = tabBloc.state;
                  final tab = state.tabs.firstWhere((t) => t.id == tabId);
                  if (tab.navigationHistory.length > 1) {
                    // Push currentPath into forwardHistory
                    final newForward = List<String>.from(tab.forwardHistory)
                      ..add(tab.path);
                    // Remove currentPath from navigationHistory
                    final newHistory = List<String>.from(tab.navigationHistory)
                      ..removeLast();
                    final newPath = newHistory.last;
                    // Update TabData
                    tabBloc.emit(state.copyWith(
                      tabs: state.tabs
                          .map((t) => t.id == tabId
                              ? t.copyWith(
                                  path: newPath,
                                  navigationHistory: newHistory,
                                  forwardHistory: newForward)
                              : t)
                          .toList(),
                    ));
                    // Update UI through the parent's onPathSubmitted
                    onPathSubmitted(newPath);
                  }
                }
              : null,
          padding: const EdgeInsets.only(right: 4.0),
        ),

        // Forward button
        IconButton(
          icon: const Icon(Icons.arrow_forward),
          tooltip: 'Forward',
          onPressed: context.read<TabManagerBloc>().canTabNavigateForward(tabId)
              ? () {
                  final tabBloc = context.read<TabManagerBloc>();
                  final state = tabBloc.state;
                  final tab = state.tabs.firstWhere((t) => t.id == tabId);
                  if (tab.forwardHistory.isNotEmpty) {
                    // Get next path
                    final nextPath = tab.forwardHistory.last;
                    // Remove this path from forwardHistory
                    final newForward = List<String>.from(tab.forwardHistory)
                      ..removeLast();
                    // Push currentPath into navigationHistory
                    final newHistory = List<String>.from(tab.navigationHistory)
                      ..add(nextPath);
                    // Update TabData
                    tabBloc.emit(state.copyWith(
                      tabs: state.tabs
                          .map((t) => t.id == tabId
                              ? t.copyWith(
                                  path: nextPath,
                                  navigationHistory: newHistory,
                                  forwardHistory: newForward)
                              : t)
                          .toList(),
                    ));
                    // Update UI through the parent's onPathSubmitted
                    onPathSubmitted(nextPath);
                  }
                }
              : null,
          padding: const EdgeInsets.only(right: 8.0),
        ),

        // Small spacing between buttons and text field
        const SizedBox(width: 4.0),

        // Address bar / path input field
        Expanded(
          child: TextField(
            controller: pathController,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4.0),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey[800]
                  : Colors.grey[200],
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              isDense: true,
              suffixIcon: IconButton(
                icon: const Icon(Icons.navigate_next, size: 20),
                onPressed: () => onPathSubmitted(pathController.text),
                padding: const EdgeInsets.all(0),
                constraints: const BoxConstraints(),
              ),
            ),
            style: const TextStyle(fontSize: 14),
            onSubmitted: onPathSubmitted,
          ),
        ),
      ],
    );
  }
}
