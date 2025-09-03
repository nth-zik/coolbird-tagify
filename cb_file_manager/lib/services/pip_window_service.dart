import 'dart:convert';
import 'dart:io';

/// Simple PiP window launcher for desktop (Windows-focused).
/// Spawns a new process of the app with environment variables
/// used by main.dart to boot into a small PiP window.
class PipWindowService {
  static const _envFlag = 'CB_PIP_MODE';
  static const _envArgs = 'CB_PIP_ARGS';

  /// Launch a PiP window as a separate process on Windows.
  /// Returns true if the process was started successfully.
  static Future<bool> openDesktopPipWindow(Map<String, dynamic> args) async {
    try {
      if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) {
        return false;
      }

      final env = Map<String, String>.from(Platform.environment);
      env[_envFlag] = '1';
      env[_envArgs] = jsonEncode(args);

      // In debug, Platform.resolvedExecutable points to the engine.
      // We forward the same executable & args to spawn a sibling process.
      final executable = Platform.resolvedExecutable;
      final execArgs = List<String>.from(Platform.executableArguments);

      // Detach so the child keeps running if the parent closes.
      await Process.start(
        executable,
        execArgs,
        environment: env,
        mode: ProcessStartMode.detached,
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}

