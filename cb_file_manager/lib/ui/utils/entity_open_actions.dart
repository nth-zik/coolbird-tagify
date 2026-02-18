import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as pathlib;

import '../../core/service_locator.dart';
import '../../services/windowing/desktop_windowing_service.dart';
import '../../services/windowing/window_startup_payload.dart';
import '../tab_manager/core/tab_manager.dart';

class EntityOpenActions {
  static void openInNewTab(
    BuildContext context, {
    required String sourcePath,
    String? preferredTabName,
  }) {
    final target =
        _resolveTarget(sourcePath, preferredTabName: preferredTabName);
    if (target == null) return;

    TabNavigator.openTab(
      context,
      target.path,
      title: target.tabName,
      highlightedFileName: target.highlightedFileName,
    );
  }

  static Future<bool> openInNewWindow(
    BuildContext context, {
    required String sourcePath,
    String? preferredTabName,
  }) async {
    final target =
        _resolveTarget(sourcePath, preferredTabName: preferredTabName);
    if (target == null) return false;

    final isDesktop =
        Platform.isWindows || Platform.isLinux || Platform.isMacOS;
    if (!isDesktop) {
      openInNewTab(
        context,
        sourcePath: sourcePath,
        preferredTabName: preferredTabName,
      );
      return true;
    }

    final service = locator<DesktopWindowingService>();
    return service.openNewWindow(
      tabs: <WindowTabPayload>[
        WindowTabPayload(
          path: target.path,
          name: target.tabName,
          highlightedFileName: target.highlightedFileName,
        ),
      ],
    );
  }

  static void openInNewPane(
    BuildContext context, {
    required String sourcePath,
    String? preferredTabName,
  }) {
    final target =
        _resolveTarget(sourcePath, preferredTabName: preferredTabName);
    if (target == null) return;

    final tabBloc = BlocProvider.of<TabManagerBloc>(context);
    tabBloc.add(
      AddTab(
        path: target.path,
        name: target.tabName,
        switchToTab: false,
        highlightedFileName: target.highlightedFileName,
      ),
    );
  }

  /// Opens the given [sourcePath] in the right-hand split pane of the active tab.
  /// If the active tab is already split, replaces the right pane's path.
  static void openInSplitView(
    BuildContext context, {
    required String sourcePath,
    String? preferredTabName,
  }) {
    final target =
        _resolveTarget(sourcePath, preferredTabName: preferredTabName);
    if (target == null) return;

    final tabBloc = BlocProvider.of<TabManagerBloc>(context);
    final activeTab = tabBloc.state.activeTab;
    if (activeTab == null) return;

    tabBloc.add(OpenSplitPane(tabId: activeTab.id, path: target.path));
  }

  static _ResolvedOpenTarget? _resolveTarget(
    String sourcePath, {
    String? preferredTabName,
  }) {
    final trimmed = sourcePath.trim();
    if (trimmed.isEmpty) return null;

    if (trimmed.startsWith('#')) {
      return _ResolvedOpenTarget(
        path: trimmed,
        tabName: preferredTabName ?? trimmed,
        highlightedFileName: null,
      );
    }

    final entityType = FileSystemEntity.typeSync(trimmed, followLinks: false);
    if (entityType == FileSystemEntityType.notFound) return null;

    if (entityType == FileSystemEntityType.file) {
      final file = File(trimmed);
      final parentPath = file.parent.path;
      return _ResolvedOpenTarget(
        path: parentPath,
        tabName: preferredTabName ?? _nameFromPath(parentPath),
        highlightedFileName: pathlib.basename(trimmed),
      );
    }

    return _ResolvedOpenTarget(
      path: trimmed,
      tabName: preferredTabName ?? _nameFromPath(trimmed),
      highlightedFileName: null,
    );
  }

  static String _nameFromPath(String path) {
    final normalized = path.replaceAll('\\', '/');
    final parts =
        normalized.split('/').where((part) => part.isNotEmpty).toList();
    if (parts.isEmpty) return path;
    return parts.last;
  }
}

class _ResolvedOpenTarget {
  final String path;
  final String tabName;
  final String? highlightedFileName;

  const _ResolvedOpenTarget({
    required this.path,
    required this.tabName,
    required this.highlightedFileName,
  });
}
