import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'tab_manager.dart';
import 'tab_data.dart';
import 'tabbed_folder_list_screen.dart';

/// A widget that displays tabs and their content
class TabView extends StatelessWidget {
  final VoidCallback? onAddNewTab;

  const TabView({
    Key? key,
    this.onAddNewTab,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TabManagerBloc, TabManagerState>(
      builder: (context, state) {
        if (state.tabs.isEmpty) {
          return _buildEmptyTabsView(context);
        }

        return Column(
          children: [
            _buildTabBar(context, state),
            Expanded(
              child: _buildTabContent(state),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEmptyTabsView(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.tab_unselected,
            size: 64,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          const Text(
            'No tabs open',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Open a new tab to get started',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('New Tab'),
            onPressed: () => onAddNewTab?.call(),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(BuildContext context, TabManagerState state) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Theme.of(context).canvasColor,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 1.0,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: state.tabs.length,
              itemBuilder: (context, index) {
                final tab = state.tabs[index];
                final isActive = tab.id == state.activeTabId;

                return _buildTab(context, tab, isActive);
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'New Tab',
            onPressed: () => onAddNewTab?.call(),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(BuildContext context, TabData tab, bool isActive) {
    final tabBloc = context.read<TabManagerBloc>();

    return InkWell(
      onTap: () => tabBloc.add(SwitchToTab(tab.id)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        decoration: BoxDecoration(
          color: isActive
              ? Theme.of(context).primaryColor.withOpacity(0.1)
              : Colors.transparent,
          border: Border(
            bottom: BorderSide(
              color: isActive
                  ? Theme.of(context).primaryColor
                  : Colors.transparent,
              width: 2.0,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(
              tab.isPinned ? Icons.push_pin : tab.icon,
              size: 16,
              color: isActive
                  ? Theme.of(context).primaryColor
                  : Theme.of(context).iconTheme.color,
            ),
            const SizedBox(width: 4),
            Text(
              tab.name,
              style: TextStyle(
                color: isActive
                    ? Theme.of(context).primaryColor
                    : Theme.of(context).textTheme.bodyMedium?.color,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            const SizedBox(width: 4),
            InkWell(
              onTap: () => tabBloc.add(CloseTab(tab.id)),
              borderRadius: BorderRadius.circular(12),
              child: const Padding(
                padding: EdgeInsets.all(4.0),
                child: Icon(Icons.close, size: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabContent(TabManagerState state) {
    final activeTab = state.activeTab;

    if (activeTab == null) {
      return const Center(child: Text('No active tab'));
    }

    // Use Navigator with a unique key to maintain navigation state per tab
    return Navigator(
      key: activeTab.navigatorKey,
      onGenerateRoute: (settings) {
        return MaterialPageRoute(
          settings: settings,
          builder: (context) => TabbedFolderListScreen(
            path: activeTab.path,
            tabId: activeTab.id,
          ),
        );
      },
    );
  }
}
