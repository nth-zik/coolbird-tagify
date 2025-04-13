import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import 'ui/home.dart';
import 'package:permission_handler/permission_handler.dart';
import 'helpers/tag_manager.dart';
import 'package:media_kit/media_kit.dart'; // Import Media Kit
import 'package:window_manager/window_manager.dart'; // Import window_manager
import 'helpers/media_kit_audio_helper.dart'; // Import our audio helper

// Global key for app state access
final GlobalKey<MyHomePageState> homeKey = GlobalKey<MyHomePageState>();

void main() async {
  // Catch any errors during app initialization
  runZonedGuarded(() async {
    // Ensure Flutter is initialized before using platform plugins
    WidgetsFlutterBinding.ensureInitialized();

    // Initialize Media Kit with proper audio configuration
    MediaKit.ensureInitialized();

    // Initialize our audio helper to ensure sound works
    if (Platform.isWindows) {
      debugPrint('Setting up Windows-specific audio configuration');
      await MediaKitAudioHelper.initialize();
    }

    // Initialize window_manager if on desktop platform
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      await windowManager.ensureInitialized();

      // Create standard window options
      WindowOptions windowOptions = const WindowOptions(
        size: Size(800, 600),
        center: true,
        backgroundColor: Colors.transparent,
        skipTaskbar: false,
        titleBarStyle: TitleBarStyle.normal,
      );

      // Pre-configure window if on Windows
      if (Platform.isWindows) {
        await windowManager.setAsFrameless();
        await windowManager.maximize();
      }

      // Now show the window with our configured options
      await windowManager.waitUntilReadyToShow(windowOptions, () async {
        await windowManager.show();
        await windowManager.focus();
      });
    }

    // Request storage permissions at startup
    await _requestPermissions();

    // Initialize the global tag system
    await TagManager.initialize();

    runApp(CBFileApp());
  }, (error, stackTrace) {
    print('Error during app initialization: $error');
    print(stackTrace);
  });
}

// Navigate directly to home screen
void goHome(BuildContext context) {
  try {
    // Check if the context is mounted before navigating
    if (!context.mounted) {
      print('Context not mounted, cannot navigate');
      return;
    }

    // Most reliable way to navigate home - create a fresh route
    final route = MaterialPageRoute(
      builder: (_) => MyHomePage(
        key: homeKey,
        title: 'CoolBird - File Manager',
      ),
    );

    // Replace entire navigation stack with home
    Navigator.of(context, rootNavigator: true)
        .pushAndRemoveUntil(route, (r) => false);
  } catch (e) {
    print('Error navigating home: $e');
    // Last resort fallback
    runApp(CBFileApp());
  }
}

Future<void> _requestPermissions() async {
  // Request storage permissions
  var storageStatus = await Permission.storage.request();

  // For Android 11+, try to request manage external storage permission
  if (Platform.isAndroid) {
    try {
      await Permission.manageExternalStorage.request();
    } catch (e) {
      print('Manage external storage permission not available: $e');
    }
  }

  print('Storage permission status: $storageStatus');
}

class CBFileApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CoolBird - File Manager',
      // Simplified navigation - ONLY define home, no routes, no initialRoute
      home: MyHomePage(
        key: homeKey,
        title: 'CoolBird - File Manager',
      ),
      theme: ThemeData(
        primarySwatch: Colors.green,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
        ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.green,
        primaryColor: Colors.green[700],
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: Colors.green[700],
        ),
      ),
      themeMode: ThemeMode.system,
      debugShowCheckedModeBanner: false,
    );
  }
}
