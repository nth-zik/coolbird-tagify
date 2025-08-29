import 'package:flutter/material.dart';
import 'package:cb_file_manager/main.dart' show goHome, CBFileApp;

/// A wrapper widget that provides safe navigation handling
/// This widget should wrap the entire app to catch navigation errors
class SafeNavigationWrapper extends StatefulWidget {
  final Widget child;

  const SafeNavigationWrapper({
    Key? key,
    required this.child,
  }) : super(key: key);

  @override
  State<SafeNavigationWrapper> createState() => _SafeNavigationWrapperState();
}

class _SafeNavigationWrapperState extends State<SafeNavigationWrapper> {
  @override
  void initState() {
    super.initState();

    // Set up global error handling for navigation
    FlutterError.onError = (FlutterErrorDetails details) {
      debugPrint(
          'Flutter Error in SafeNavigationWrapper: ${details.exception}');

      // Check if this is a navigation-related error
      if (details.exception.toString().contains('_history.isNotEmpty') ||
          details.exception.toString().contains('Navigator') ||
          details.exception.toString().contains('pop')) {
        debugPrint('Navigation error detected, attempting recovery...');
        _handleNavigationError();
      }
    };
  }

  void _handleNavigationError() {
    try {
      // Try to go home as a recovery mechanism
      if (mounted) {
        goHome(context);
      }
    } catch (e) {
      debugPrint('Failed to recover from navigation error: $e');
      // Last resort: restart the app
      runApp(const CBFileApp());
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

/// Extension to provide safe navigation methods on BuildContext
extension SafeNavigation on BuildContext {
  /// Safely pop the current route
  void safePop() {
    try {
      if (mounted && Navigator.of(this).canPop()) {
        Navigator.of(this).pop();
      } else {
        debugPrint('Cannot pop, going home');
        goHome(this);
      }
    } catch (e) {
      debugPrint('Error in safePop: $e');
      goHome(this);
    }
  }

  /// Safely pop with result
  void safePopWithResult(dynamic result) {
    try {
      if (mounted && Navigator.of(this).canPop()) {
        Navigator.of(this).pop(result);
      } else {
        debugPrint('Cannot pop with result, going home');
        goHome(this);
      }
    } catch (e) {
      debugPrint('Error in safePopWithResult: $e');
      goHome(this);
    }
  }

  /// Check if navigation is safe
  bool get canNavigateSafely {
    return mounted && Navigator.of(this).canPop();
  }
}
