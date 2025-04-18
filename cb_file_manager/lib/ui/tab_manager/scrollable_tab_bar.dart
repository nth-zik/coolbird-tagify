import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:eva_icons_flutter/eva_icons_flutter.dart';

/// A custom TabBar wrapper that translates vertical mouse wheel scrolling
/// to horizontal scrolling of the tab bar, with Chrome-like styling.
class ScrollableTabBar extends StatefulWidget {
  final TabController controller;
  final List<Widget> tabs;
  final bool isScrollable;
  final EdgeInsetsGeometry? labelPadding;
  final TabBarIndicatorSize? indicatorSize;
  final ScrollPhysics? physics;
  final Decoration? indicator;
  final TextStyle? labelStyle;
  final TextStyle? unselectedLabelStyle;
  final Color? labelColor;
  final Color? unselectedLabelColor;
  final Function(int)? onTap;
  final VoidCallback? onAddTabPressed;
  final Function(int)? onTabClose; // Added callback for tab closing

  const ScrollableTabBar({
    Key? key,
    required this.controller,
    required this.tabs,
    this.isScrollable = true,
    this.labelPadding,
    this.indicatorSize,
    this.physics,
    this.indicator,
    this.labelStyle,
    this.unselectedLabelStyle,
    this.labelColor,
    this.unselectedLabelColor,
    this.onTap,
    this.onAddTabPressed,
    this.onTabClose, // Added parameter
  }) : super(key: key);

  @override
  State<ScrollableTabBar> createState() => _ScrollableTabBarState();
}

class _ScrollableTabBarState extends State<ScrollableTabBar> {
  // Create a scroll controller for the horizontal scroll view
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    // Chrome-like colors
    final tabBackgroundColor =
        isDarkMode ? Color(0xFF292A2D) : Color(0xFFDEE1E6);
    final activeTabColor = isDarkMode ? Color(0xFF3C4043) : Colors.white;
    final hoverColor = isDarkMode
        ? Color(0xFF3C4043).withOpacity(0.7)
        : Color(0xFFDEE1E6).withOpacity(0.7);

    return Container(
      decoration: BoxDecoration(
        color: tabBackgroundColor,
        // Removed bottom border as requested
      ),
      child: Listener(
        onPointerSignal: (PointerSignalEvent event) {
          // Check if it's a mouse wheel event
          if (event is PointerScrollEvent && _scrollController.hasClients) {
            // Prevent the default behavior (vertical scrolling)
            GestureBinding.instance.pointerSignalResolver
                .register(event, (_) {});

            // Calculate the new scroll position
            final double newPosition =
                _scrollController.offset + event.scrollDelta.dy;

            // Smooth horizontal scrolling based on vertical mouse wheel delta
            _scrollController.animateTo(
              // Clamp value between min and max scroll extent
              newPosition.clamp(
                _scrollController.position.minScrollExtent,
                _scrollController.position.maxScrollExtent,
              ),
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
            );
          }
        },
        // Use a SingleChildScrollView to enable horizontal scrolling with our controller
        child: SingleChildScrollView(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: _ChromeStyleTabBar(
            controller: widget.controller,
            tabs: widget.tabs,
            labelColor: isDarkMode ? Colors.white : theme.colorScheme.primary,
            unselectedLabelColor:
                isDarkMode ? Colors.white70 : theme.colorScheme.onSurface,
            labelStyle: widget.labelStyle,
            unselectedLabelStyle: widget.unselectedLabelStyle,
            onTap: widget.onTap,
            activeTabColor: activeTabColor,
            hoverColor: hoverColor,
            tabBackgroundColor: tabBackgroundColor,
            onAddTabPressed: widget.onAddTabPressed, // Pass the callback
            onTabClose: widget.onTabClose, // Pass the callback
          ),
        ),
      ),
    );
  }
}

/// Custom TabBar implementation with Chrome-like tab appearance
class _ChromeStyleTabBar extends StatelessWidget {
  final TabController controller;
  final List<Widget> tabs;
  final Color? labelColor;
  final Color? unselectedLabelColor;
  final TextStyle? labelStyle;
  final TextStyle? unselectedLabelStyle;
  final Function(int)? onTap;
  final Color activeTabColor;
  final Color hoverColor;
  final Color tabBackgroundColor;
  final VoidCallback? onAddTabPressed; // Added parameter for add tab button
  final Function(int)? onTabClose; // Added parameter for tab closing

  const _ChromeStyleTabBar({
    Key? key,
    required this.controller,
    required this.tabs,
    this.labelColor,
    this.unselectedLabelColor,
    this.labelStyle,
    this.unselectedLabelStyle,
    this.onTap,
    required this.activeTabColor,
    required this.hoverColor,
    required this.tabBackgroundColor,
    this.onAddTabPressed, // Added parameter
    this.onTabClose, // Added parameter
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Row(
      children: [
        ...List.generate(tabs.length, (index) {
          final isActive = controller.index == index;
          return _ChromeTab(
            isActive: isActive,
            onTap: () => onTap?.call(index),
            activeTabColor: activeTabColor,
            hoverColor: hoverColor,
            tabBackgroundColor: tabBackgroundColor,
            labelColor: isActive ? labelColor : unselectedLabelColor,
            labelStyle: isActive ? labelStyle : unselectedLabelStyle,
            child: tabs[index],
            onClose: () {
              // Close this specific tab
              if (controller.index == index && controller.length > 1) {
                // If this is the active tab, we need to move to another tab first
                // The tab manager will handle this logic, we just need to trigger the close
              }
              // We need to dispatch a CloseTab event with the tab's ID
              // This will be handled by the TabManagerBloc
              onTabClose?.call(index); // Trigger the callback
            },
          );
        }),

        // "New Tab" button moved to be inside the scrollable area
        if (onAddTabPressed != null)
          Material(
            color: Colors.transparent,
            child: Tooltip(
              message: 'Add new tab',
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: onAddTabPressed,
                hoverColor: hoverColor,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  margin: const EdgeInsets.only(left: 2, top: 6, right: 2),
                  height: 40,
                  decoration: BoxDecoration(
                    color: tabBackgroundColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    EvaIcons.plus,
                    size: 22,
                    color: isDarkMode ? Colors.white70 : Colors.black87,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Individual Chrome-style tab with curved borders and proper styling
class _ChromeTab extends StatefulWidget {
  final bool isActive;
  final VoidCallback onTap;
  final Color activeTabColor;
  final Color hoverColor;
  final Color tabBackgroundColor;
  final Color? labelColor;
  final TextStyle? labelStyle;
  final Widget child;
  final VoidCallback? onClose; // Added parameter for tab closing

  const _ChromeTab({
    Key? key,
    required this.isActive,
    required this.onTap,
    required this.activeTabColor,
    required this.hoverColor,
    required this.tabBackgroundColor,
    this.labelColor,
    this.labelStyle,
    required this.child,
    this.onClose, // Added parameter
  }) : super(key: key);

  @override
  State<_ChromeTab> createState() => _ChromeTabState();
}

class _ChromeTabState extends State<_ChromeTab>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );

    if (widget.isActive) {
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(_ChromeTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tabWidth = 220.0;
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    // Chrome-like hover color with opacity
    final hoverColor = isDarkMode
        ? Colors.white.withOpacity(0.04)
        : Colors.black.withOpacity(0.04);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            return Container(
              width: tabWidth,
              height: 40,
              margin: const EdgeInsets.only(left: 2, top: 6, right: 2),
              decoration: BoxDecoration(
                color: widget.isActive
                    ? widget.activeTabColor
                    : (_isHovered
                        ? widget.hoverColor
                        : widget.tabBackgroundColor),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
                border: widget.isActive
                    ? Border(
                        top: BorderSide(
                          color: theme.brightness == Brightness.dark
                              ? Colors.grey.withOpacity(0.3)
                              : Colors.white,
                          width: 1.5,
                        ),
                        left: BorderSide(
                          color: theme.brightness == Brightness.dark
                              ? Colors.grey.withOpacity(0.3)
                              : Colors.white,
                          width: 1,
                        ),
                        right: BorderSide(
                          color: theme.brightness == Brightness.dark
                              ? Colors.grey.withOpacity(0.3)
                              : Colors.white,
                          width: 1,
                        ),
                      )
                    : null,
                boxShadow: widget.isActive
                    ? [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 2,
                          offset: const Offset(0, 1),
                        ),
                      ]
                    : null,
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
                child: Stack(
                  children: [
                    // Tab content
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: DefaultTextStyle(
                          style: TextStyle(
                            color: widget.labelColor,
                            fontSize: 13,
                          ).merge(widget.labelStyle),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(
                                      right:
                                          24.0), // Make space for the close button
                                  child: Center(child: widget.child),
                                ),
                              ),
                              // Close button
                              if (widget.onClose != null)
                                GestureDetector(
                                  onTap: () {
                                    widget.onClose?.call();
                                  },
                                  child: MouseRegion(
                                    cursor: SystemMouseCursors.click,
                                    child: Container(
                                      width: 16,
                                      height: 16,
                                      decoration: BoxDecoration(
                                        color: _isHovered
                                            ? (isDarkMode
                                                ? Colors.white24
                                                : Colors.black12)
                                            : Colors.transparent,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.close,
                                        size: 14,
                                        color: isDarkMode
                                            ? Colors.white70
                                            : Colors.black54,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Tab highlight when hovered (Chrome-like)
                    if (_isHovered && !widget.isActive)
                      Positioned.fill(
                        child: Material(
                          color: hoverColor,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(12),
                            topRight: Radius.circular(12),
                          ),
                        ),
                      ),

                    // Active tab indicators
                    if (widget.isActive) ...[
                      // Subtle highlight line at top of active tab (Chrome style)
                      Positioned(
                        left: 0,
                        right: 0,
                        top: 0,
                        height: 3,
                        child: Container(
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary
                                .withOpacity(_animation.value * 0.9),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(12),
                              topRight: Radius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
