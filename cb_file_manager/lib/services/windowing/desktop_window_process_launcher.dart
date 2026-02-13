import 'dart:convert';
import 'dart:io';

import 'package:cb_file_manager/services/windowing/window_startup_payload.dart';
import 'package:cb_file_manager/utils/app_logger.dart';

class DesktopWindowProcessLauncher {
  static Future<bool> openWindow({
    List<WindowTabPayload> tabs = const <WindowTabPayload>[],
    int? activeIndex,
    bool startHidden = false,
    String windowRole = 'normal',
  }) async {
    if (!(Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      return false;
    }

    try {
      final executable = Platform.resolvedExecutable;
      final workingDir = File(executable).parent.path;

      final env = Map<String, String>.from(Platform.environment);
      env[WindowStartupPayload.envSecondaryWindowKey] = '1';
      env[WindowStartupPayload.envStartHiddenKey] = startHidden ? '1' : '0';
      env[WindowStartupPayload.envWindowRoleKey] = windowRole;

      if (tabs.isNotEmpty) {
        final payload = <String, dynamic>{
          'tabs': tabs.map((t) => t.toJson()).toList(growable: false),
          if (activeIndex != null) 'activeIndex': activeIndex,
        };
        env[WindowStartupPayload.envTabsKey] = jsonEncode(payload);
      }

      final lowerExecutable = executable.toLowerCase();
      final isDartRuntime = lowerExecutable.endsWith(r'\dart.exe') ||
          lowerExecutable.endsWith('/dart');
      final launchArgs = isDartRuntime
          ? Platform.executableArguments.where((a) {
              final al = a.toLowerCase();
              return !(al.startsWith('--vm-service') ||
                  al.startsWith('--observatory-port') ||
                  al.startsWith('--dds-port') ||
                  al.startsWith('--devtools-server-address'));
            }).toList(growable: false)
          : const <String>[];

      await Process.start(
        executable,
        launchArgs,
        environment: env,
        workingDirectory: workingDir,
        mode: ProcessStartMode.detached,
      );
      return true;
    } catch (e, st) {
      AppLogger.warning('Failed to open a new window.',
          error: e, stackTrace: st);
      return false;
    }
  }
}
