import 'package:flutter/material.dart';
import 'package:cb_file_manager/main.dart' show goHome;

class RouteUtils {
  static void toNewScreen(BuildContext context, Widget screen) {
    // Check if we can pop before attempting to pop
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }

    Navigator.of(context)
        .push(PageRouteBuilder(pageBuilder: (BuildContext context, _, __) {
      return screen;
    }, transitionsBuilder: (_, Animation<double> animation, __, Widget child) {
      return FadeTransition(opacity: animation, child: child);
    }));
  }

  static void toNewScreenWithoutPop(BuildContext context, Widget screen) {
    try {
      Navigator.of(context).push(PageRouteBuilder(
          pageBuilder: (BuildContext context, _, __) {
        return screen;
      }, transitionsBuilder:
              (_, Animation<double> animation, __, Widget child) {
        return FadeTransition(opacity: animation, child: child);
      }));
    } catch (e) {
      print('Navigation error in toNewScreenWithoutPop: $e');
      // If regular navigation fails, try using goHome as fallback
      if (context.mounted) {
        goHome(context);
      }
    }
  }

  static void replaceScreen(BuildContext context, Widget screen) {
    try {
      Navigator.of(context).pushReplacement(PageRouteBuilder(
          pageBuilder: (BuildContext context, _, __) {
        return screen;
      }, transitionsBuilder:
              (_, Animation<double> animation, __, Widget child) {
        return FadeTransition(opacity: animation, child: child);
      }));
    } catch (e) {
      print('Navigation error in replaceScreen: $e');
      // If navigation replacement fails, try using goHome
      if (context.mounted) {
        goHome(context);
      }
    }
  }

  // Add a safe navigation method that ensures we never get an empty stack
  static void safeNavigate(BuildContext context, Widget screen) {
    try {
      // First check if we can navigate at all
      if (!context.mounted) {
        print('Context not mounted, cannot navigate');
        return;
      }

      // Create a fresh route
      final route = MaterialPageRoute(builder: (_) => screen);

      // If we can pop, replace this route, otherwise push a new one
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pushReplacement(route);
      } else {
        Navigator.of(context).push(route);
      }
    } catch (e) {
      print('Error in safeNavigate: $e');
      // Last resort fallback
      if (context.mounted) {
        goHome(context);
      }
    }
  }
}
