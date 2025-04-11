import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import 'ui/home.dart';
import 'ui/main_ui.dart';
import 'package:permission_handler/permission_handler.dart';

void main() async {
  // Ensure Flutter is initialized before using platform plugins
  WidgetsFlutterBinding.ensureInitialized();

  // Catch any errors during app initialization
  runZonedGuarded(() async {
    // Request storage permissions at startup
    await _requestPermissions();

    runApp(CBFileApp());
  }, (error, stackTrace) {
    print('Error during app initialization: $error');
    print(stackTrace);
    // In a production app, you might want to report this to a crash reporting service
  });
}

Future<void> _requestPermissions() async {
  // Request storage permissions
  var storageStatus = await Permission.storage.request();

  // For Android 11+, try to request manage external storage permission
  // Check if we're on Android to avoid errors on iOS
  if (Platform.isAndroid) {
    try {
      await Permission.manageExternalStorage.request();
    } catch (e) {
      // This permission might not be available in older permission_handler versions
      print('Manage external storage permission not available: $e');
    }
  }

  // Log permission status for debugging
  print('Storage permission status: $storageStatus');
}

class CBFileApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CoolBird - File Manager',
      initialRoute: '/',
      routes: {
        '/local/home': (context) => LocalHome(),
      },
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
      themeMode: ThemeMode.system, // Use system theme by default
      home: MyHomePage(title: 'CoolBird - File Manager'),
      debugShowCheckedModeBanner: false,
    );
  }
}
