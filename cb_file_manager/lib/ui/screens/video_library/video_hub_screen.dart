import 'package:flutter/material.dart';
import 'package:cb_file_manager/models/objectbox/video_library.dart';
import 'package:cb_file_manager/services/video_library_service.dart';
import 'package:cb_file_manager/config/languages/app_localizations.dart';
import 'package:cb_file_manager/ui/screens/video_library/create_video_library_dialog.dart';
import 'package:cb_file_manager/ui/screens/video_library/video_library_settings_screen.dart';
import 'package:cb_file_manager/ui/tab_manager/core/tab_manager.dart';
import 'package:cb_file_manager/ui/utils/base_screen.dart';
import 'package:cb_file_manager/ui/screens/video_library/widgets/video_library_helpers.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:remixicon/remixicon.dart' as remix;

/// Video Hub Screen - Main screen for managing video libraries
class VideoHubScreen extends StatefulWidget {
  const VideoHubScreen({Key? key}) : super(key: key);

  @override
  State<VideoHubScreen> createState() => _VideoHubScreenState();
}

class _VideoHubScreenState extends State<VideoHubScreen> {
  final VideoLibraryService _service = VideoLibraryService();
  List<VideoLibrary> _libraries = [];
  bool _isLoading = true;
  int _totalVideos = 0;

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  /// Refresh both libraries and video count
  Future<void> _refreshData() async {
    setState(() {
      _isLoading = true;
    });

    final libraries = await _service.getAllLibraries();
    
    if (!mounted) return;
    
    setState(() {
      _libraries = libraries;
    });

    // Load video count for all libraries
    int total = 0;
    for (final library in libraries) {
      final count = await _service.getLibraryVideoCount(library.id);
      total += count;
    }
    
    if (mounted) {
      setState(() {
        _totalVideos = total;
        _isLoading = false;
      });
    }
  }

  Future<void> _showCreateLibraryDialog() async {
    final result = await showDialog<VideoLibrary>(
      context: context,
      builder: (context) => const CreateVideoLibraryDialog(),
    );

    if (result != null) {
      _refreshData();
    }
  }

  Future<void> _deleteLibrary(VideoLibrary library) async {
    final localizations = AppLocalizations.of(context)!;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations.deleteVideoLibrary),
        content: Text(localizations.deleteVideoLibraryConfirmation(library.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(localizations.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: Text(localizations.delete),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await _service.deleteLibrary(library.id);
      
      if (success && mounted) {
        VideoLibraryHelpers.showSuccessMessage(context, localizations.libraryDeletedSuccessfully);
        _refreshData();
      }
    }
  }

  void _navigateToLibrary(VideoLibrary library) {
    // Navigate within current tab to keep tab history
    final tabManager = context.read<TabManagerBloc>();
    final activeTab = tabManager.state.activeTab;

    if (activeTab != null) {
      final path = '#video-library/${library.id}';
      TabNavigator.updateTabPath(context, activeTab.id, path);
      tabManager.add(UpdateTabName(activeTab.id, library.name));
    }
  }

  void _navigateToSettings(VideoLibrary library) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => VideoLibrarySettingsScreen(library: library),
      ),
    ).then((_) {
      // Refresh libraries after returning from settings
      _refreshData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localizations = AppLocalizations.of(context)!;

    return BaseScreen(
      title: localizations.videoHubTitle,
      actions: [
        IconButton(
          icon: const Icon(Icons.add_rounded),
          onPressed: _showCreateLibraryDialog,
          tooltip: localizations.createVideoLibrary,
        ),
        PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'refresh':
                _refreshData();
                break;
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'refresh',
              child: Row(
                children: [
                  const Icon(Icons.refresh),
                  const SizedBox(width: 8),
                  Text(localizations.refresh),
                ],
              ),
            ),
          ],
        ),
      ],
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: CustomScrollView(
          slivers: [
            // Welcome Section
            SliverToBoxAdapter(
              child: _buildWelcomeSection(theme, localizations),
            ),

            // Statistics
            SliverToBoxAdapter(
              child: _buildStatistics(theme, localizations),
            ),

            // Libraries Grid
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: _isLoading
                  ? const SliverFillRemaining(
                      child: Center(
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : _libraries.isEmpty
                      ? SliverFillRemaining(
                          child: _buildEmptyState(theme, localizations),
                        )
                      : SliverGrid(
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 300,
                            mainAxisSpacing: 16,
                            crossAxisSpacing: 16,
                            childAspectRatio: 1.2,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              return _buildLibraryCard(
                                  theme, localizations, _libraries[index]);
                            },
                            childCount: _libraries.length,
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeSection(ThemeData theme, AppLocalizations localizations) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primaryContainer,
            theme.colorScheme.secondaryContainer,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            remix.Remix.movie_2_line,
            size: 48,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            localizations.videoHubWelcome,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatistics(ThemeData theme, AppLocalizations localizations) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              theme,
              localizations.videoLibraries,
              '${_libraries.length}',
              remix.Remix.folder_video_line,
              theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildStatCard(
              theme,
              localizations.totalVideos,
              '$_totalVideos',
              remix.Remix.film_line,
              theme.colorScheme.tertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    ThemeData theme,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLibraryCard(
    ThemeData theme,
    AppLocalizations localizations,
    VideoLibrary library,
  ) {
    final cardColor = VideoLibraryHelpers.getColorFromHex(
      library.colorTheme,
      theme.colorScheme.primaryContainer,
    );

    return FutureBuilder<int>(
      future: _service.getLibraryVideoCount(library.id),
      builder: (context, snapshot) {
        final videoCount = snapshot.data ?? 0;

        return Card(
          elevation: 2,
          child: InkWell(
            onTap: () => _navigateToLibrary(library),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  colors: [
                    cardColor.withValues(alpha: 0.3),
                    cardColor.withValues(alpha: 0.1),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with menu
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Icon(
                          remix.Remix.movie_2_fill,
                          color: cardColor,
                          size: 32,
                        ),
                        PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'settings') {
                              _navigateToSettings(library);
                            } else if (value == 'delete') {
                              _deleteLibrary(library);
                            }
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: 'settings',
                              child: Row(
                                children: [
                                  const Icon(Icons.settings),
                                  const SizedBox(width: 8),
                                  Text(localizations.settings),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  const Icon(Icons.delete, color: Colors.red),
                                  const SizedBox(width: 8),
                                  Text(localizations.delete),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Library info
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            library.name,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (library.description != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              library.description!,
                              style: theme.textTheme.bodySmall,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  // Footer with count
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(12),
                        bottomRight: Radius.circular(12),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          remix.Remix.film_line,
                          size: 16,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$videoCount ${localizations.videos.toLowerCase()}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(ThemeData theme, AppLocalizations localizations) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            remix.Remix.movie_2_line,
            size: 80,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            localizations.noVideoSources,
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            localizations.createVideoLibrary,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _showCreateLibraryDialog,
            icon: const Icon(Icons.add),
            label: Text(localizations.createVideoLibrary),
          ),
        ],
      ),
    );
  }
}
