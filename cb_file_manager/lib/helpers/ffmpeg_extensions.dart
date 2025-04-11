import 'dart:io';
import 'package:ffmpeg_helper/ffmpeg_helper.dart';
import 'package:path/path.dart' as path_util;
import 'package:path_provider/path_provider.dart';

/// Extensions for FFMpegHelper class
extension FFMpegHelperExtensions on FFMpegHelper {
  /// Check if FFmpeg is installed on the system
  /// Returns true if FFmpeg is installed and available
  Future<bool> isFFmpegInstalled() async {
    try {
      // Check for FFmpeg in the application's directory first (for bundled FFmpeg)
      final String? bundledFFmpegPath = await _getBundledFFmpegPath();
      if (bundledFFmpegPath != null && File(bundledFFmpegPath).existsSync()) {
        // Try running the bundled ffmpeg to verify it works
        final result = await Process.run(bundledFFmpegPath, ['-version']);
        if (result.exitCode == 0) {
          return true;
        }
      }

      // Check in system PATH
      final String ffmpegCommand = Platform.isWindows ? 'ffmpeg.exe' : 'ffmpeg';
      final result = await Process.run(ffmpegCommand, ['-version']);

      // Exit code 0 means ffmpeg executed successfully
      return result.exitCode == 0;
    } catch (e) {
      // Command failed or process couldn't be started
      print('FFmpeg not found: $e');
      return false;
    }
  }

  /// Get path to bundled FFmpeg if available
  Future<String?> _getBundledFFmpegPath() async {
    try {
      if (Platform.isWindows) {
        // Check in app's directory
        final appDir = Directory(Platform.resolvedExecutable).parent;
        final ffmpegPath = path_util.join(appDir.path, 'ffmpeg', 'ffmpeg.exe');
        if (File(ffmpegPath).existsSync()) {
          return ffmpegPath;
        }

        // Check in app's data directory
        final appDataDir = await getApplicationDocumentsDirectory();
        final ffmpegDataPath =
            path_util.join(appDataDir.path, 'ffmpeg', 'ffmpeg.exe');
        if (File(ffmpegDataPath).existsSync()) {
          return ffmpegDataPath;
        }
      } else if (Platform.isMacOS) {
        // Check in app's bundled resources
        final appDir = Directory(Platform.resolvedExecutable).parent.parent;
        final ffmpegPath = path_util.join(appDir.path, 'Resources', 'ffmpeg');
        if (File(ffmpegPath).existsSync()) {
          return ffmpegPath;
        }
      } else if (Platform.isLinux) {
        // Check in app's directory
        final appDir = Directory(Platform.resolvedExecutable).parent;
        final ffmpegPath = path_util.join(appDir.path, 'ffmpeg');
        if (File(ffmpegPath).existsSync()) {
          return ffmpegPath;
        }
      }

      // For mobile platforms, check in app's data directory
      if (Platform.isAndroid || Platform.isIOS) {
        final appDir = await getApplicationDocumentsDirectory();
        final ffmpegPath = path_util.join(appDir.path, 'ffmpeg');
        if (File(ffmpegPath).existsSync()) {
          return ffmpegPath;
        }
      }

      return null;
    } catch (e) {
      print('Error checking for bundled FFmpeg: $e');
      return null;
    }
  }
}
