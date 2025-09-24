import 'dart:io';
import 'package:flutter/material.dart';
import 'package:remixicon/remixicon.dart' as remix;
import 'external_app_helper.dart';
import 'windows_app_icon.dart';
import 'package:cb_file_manager/ui/utils/file_type_utils.dart';

/// Helper class to get file icons, including app icons for file types
class FileIconHelper {
  // Cache for file extensions icons
  static final Map<String, Widget> _iconCache = {};

  // Cache for app paths by extension
  static final Map<String, String> _appPathCache = {};

  /// Get an icon for a file. If possible, return the icon of the default application.
  /// If no default app is found, return an appropriate icon based on file type.
  static Future<Widget> getIconForFile(File file, {double size = 24}) async {
    final String extension = _getFileExtension(file);

    // For APK files, use file-specific cache key to avoid cache conflicts
    final String cacheKey =
        extension == 'apk' ? '${file.path}_$size' : '${extension}_$size';
    print('APK_ICON_DEBUG: Cache key: $cacheKey');
    print(
        'APK_ICON_DEBUG: Cache contains key: ${_iconCache.containsKey(cacheKey)}');

    if (_iconCache.containsKey(cacheKey)) {
      print('APK_ICON_DEBUG: Using cached icon for: $cacheKey');
      final cachedIcon = _iconCache[cacheKey]!;
      print('APK_ICON_DEBUG: Cached icon type: ${cachedIcon.runtimeType}');
      return cachedIcon;
    }

    print('APK_ICON_DEBUG: No cached icon for: $cacheKey');

    // For images and videos, return a generic icon
    if (_isImageFile(extension)) {
      final icon = Icon(remix.Remix.image_line, size: size, color: Colors.blue);
      _iconCache[cacheKey] = icon;
      return icon;
    }

    if (_isVideoFile(extension)) {
      final icon = Icon(remix.Remix.video_line, size: size, color: Colors.red);
      _iconCache[cacheKey] = icon;
      return icon;
    }

    // Try to get the application icon for this file type
    try {
      // For APK files on Android, try to get the installed app icon
      if (extension == 'apk' && Platform.isAndroid) {
        print('APK_ICON_DEBUG: Processing APK file: ${file.path}');

        // Test APK info first
        final testInfo = await ExternalAppHelper.testApkInfo(file.path);
        if (testInfo != null) {
          print('APK_ICON_DEBUG: Test info: $testInfo');
        }

        final appInfo =
            await ExternalAppHelper.getApkInstalledAppInfo(file.path);
        if (appInfo != null) {
          print(
              'APK_ICON_DEBUG: Got app info: ${appInfo.appName} (installed: ${appInfo.isInstalled})');
          print('APK_ICON_DEBUG: App icon type: ${appInfo.icon.runtimeType}');

          // Use the installed app icon
          final Widget appIcon = SizedBox(
            width: size,
            height: size,
            child: appInfo.icon,
          );
          print(
              'APK_ICON_DEBUG: Created appIcon widget: ${appIcon.runtimeType}');
          _iconCache[cacheKey] = appIcon;
          print('APK_ICON_DEBUG: Cached appIcon with key: $cacheKey');
          print('APK_ICON_DEBUG: Returning appIcon widget');
          return appIcon;
        } else {
          print('APK_ICON_DEBUG: No app info returned for APK, using fallback');
          // Use fallback APK icon
          final Widget fallbackIcon = Icon(
            remix.Remix.smartphone_line,
            size: size,
            color: Colors.green,
          );
          print(
              'APK_ICON_DEBUG: Created fallback icon: ${fallbackIcon.runtimeType}');
          _iconCache[cacheKey] = fallbackIcon;
          print('APK_ICON_DEBUG: Cached fallback icon with key: $cacheKey');
          print('APK_ICON_DEBUG: Returning fallback icon');
          return fallbackIcon;
        }
      }

      // For other file types or non-Android platforms
      String? appPath;

      // Check cache first
      if (_appPathCache.containsKey(extension)) {
        appPath = _appPathCache[extension];
      } else {
        // Get the default application path for this extension (Windows only)
        if (Platform.isWindows) {
          appPath = await WindowsAppIcon.getAssociatedAppPath(extension);
          if (appPath != null && appPath.isNotEmpty) {
            _appPathCache[extension] = appPath;
          }
        }
      }

      if (appPath != null && appPath.isNotEmpty) {
        // Get the default app info
        final apps = await ExternalAppHelper.getInstalledAppsForFile(file.path);
        if (apps.isNotEmpty) {
          // Use the first app icon
          final Widget appIcon = SizedBox(
            width: size,
            height: size,
            child: apps[0].icon,
          );
          _iconCache[cacheKey] = appIcon;
          return appIcon;
        }
      }
    } catch (e) {
      debugPrint('Error getting app icon: $e');
    }

    // Fallback to generic file type icons
    Widget icon;

    if (_isAudioFile(extension)) {
      icon = Icon(remix.Remix.music_2_line, size: size, color: Colors.purple);
    } else if (_isDocumentFile(extension)) {
      icon = Icon(remix.Remix.file_text_line, size: size, color: Colors.indigo);
    } else if (_isSpreadsheetFile(extension)) {
      icon =
          Icon(remix.Remix.grid_line, size: size, color: Colors.green);
    } else if (_isPresentationFile(extension)) {
      icon = Icon(remix.Remix.file_3_line, size: size, color: Colors.orange);
    } else if (_isPdfFile(extension)) {
      icon = Icon(remix.Remix.file_3_line, size: size, color: Colors.red[800]);
    } else if (extension == 'apk') {
      icon = Icon(remix.Remix.smartphone_line, size: size, color: Colors.green);
      print('APK_ICON_DEBUG: Created generic APK icon: ${icon.runtimeType}');
    } else {
      icon = Icon(remix.Remix.file_3_line, size: size, color: Colors.grey);
    }

    _iconCache[cacheKey] = icon;
    print('APK_ICON_DEBUG: Cached generic icon with key: $cacheKey');
    print('APK_ICON_DEBUG: Returning generic icon');
    return icon;
  }

  /// Get the default application icon for a file extension
  static Future<Widget?> getDefaultAppIconForExtension(String extension,
      {double size = 24}) async {
    try {
      // For APK files on Android, try to get the installed app icon
      if (extension == 'apk' && Platform.isAndroid) {
        final tempFile =
            File('temp.$extension'); // Dummy file với extension cần thiết
        final appInfo =
            await ExternalAppHelper.getApkInstalledAppInfo(tempFile.path);
        if (appInfo != null) {
          return SizedBox(
            width: size,
            height: size,
            child: appInfo.icon,
          );
        }
      }

      // For other file types or non-Android platforms
      String? appPath;

      // Check cache first
      if (_appPathCache.containsKey(extension)) {
        appPath = _appPathCache[extension];
      } else {
        // Get the default application path for this extension (Windows only)
        if (Platform.isWindows) {
          appPath = await WindowsAppIcon.getAssociatedAppPath(extension);
          if (appPath != null && appPath.isNotEmpty) {
            _appPathCache[extension] = appPath;
          }
        }
      }

      if (appPath != null && appPath.isNotEmpty) {
        // Sử dụng phương thức public để lấy biểu tượng ứng dụng
        final tempFile =
            File('temp.$extension'); // Dummy file với extension cần thiết
        final apps =
            await ExternalAppHelper.getInstalledAppsForFile(tempFile.path);
        if (apps.isNotEmpty) {
          return SizedBox(
            width: size,
            height: size,
            child: apps[0].icon,
          );
        }
      }
    } catch (e) {
      debugPrint('Error getting default app icon: $e');
    }

    return null;
  }

  /// Clear the icon cache
  static void clearCache() {
    _iconCache.clear();
  }

  /// Clear cache for APK files specifically
  static void clearApkCache() {
    _iconCache.removeWhere((key, value) => key.contains('.apk_'));
  }

  /// Force refresh APK icon (bypass cache)
  static Future<Widget> getApkIconForced(File file, {double size = 24}) async {
    final String cacheKey = '${file.path}_$size';
    _iconCache.remove(cacheKey); // Remove from cache first

    print('APK_ICON_DEBUG: Force refreshing APK icon for: ${file.path}');
    return await getIconForFile(file, size: size);
  }

  /// Test method to debug APK icon issues
  static Future<void> debugApkIcons() async {
    print('APK_ICON_DEBUG: === Starting APK Icon Debug ===');
    print('APK_ICON_DEBUG: Cache size: ${_iconCache.length}');
    print('APK_ICON_DEBUG: APK cache entries:');
    _iconCache.forEach((key, value) {
      if (key.contains('.apk')) {
        print('APK_ICON_DEBUG:   $key -> ${value.runtimeType}');
      }
    });

    // Clear all APK cache
    clearApkCache();
    print('APK_ICON_DEBUG: Cleared APK cache');
    print('APK_ICON_DEBUG: New cache size: ${_iconCache.length}');

    // Test creating a simple APK icon
    print('APK_ICON_DEBUG: Testing simple APK icon creation...');
    final testIcon = Icon(
      remix.Remix.smartphone_line,
      size: 24,
      color: Colors.green,
    );
    print('APK_ICON_DEBUG: Test icon created: ${testIcon.runtimeType}');

    // Force clear all cache
    _iconCache.clear();
    print('APK_ICON_DEBUG: Cleared ALL cache');
    print('APK_ICON_DEBUG: Final cache size: ${_iconCache.length}');

    print('APK_ICON_DEBUG: === End APK Icon Debug ===');
  }

  // Helper methods to identify file types using FileTypeUtils
  static String _getFileExtension(File file) {
    return file.path.split('.').last.toLowerCase();
  }

  static bool _isImageFile(String extension) {
    return FileTypeUtils.isImageFile('dummy.$extension');
  }

  static bool _isVideoFile(String extension) {
    return FileTypeUtils.isVideoFile('dummy.$extension');
  }

  static bool _isAudioFile(String extension) {
    return FileTypeUtils.isAudioFile('dummy.$extension');
  }

  static bool _isDocumentFile(String extension) {
    return FileTypeUtils.isDocumentFile('dummy.$extension');
  }

  static bool _isSpreadsheetFile(String extension) {
    return FileTypeUtils.isSpreadsheetFile('dummy.$extension');
  }

  static bool _isPresentationFile(String extension) {
    return FileTypeUtils.isPresentationFile('dummy.$extension');
  }

  static bool _isPdfFile(String extension) {
    return FileTypeUtils.isDocumentFile('dummy.$extension') &&
        extension == 'pdf';
  }
}
