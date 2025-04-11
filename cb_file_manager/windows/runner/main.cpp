#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

// Function to get the primary monitor dimensions
void GetPrimaryMonitorDimensions(int *width, int *height)
{
  HMONITOR primaryMonitor = MonitorFromPoint({0, 0}, MONITOR_DEFAULTTOPRIMARY);
  MONITORINFO monitorInfo = {0};
  monitorInfo.cbSize = sizeof(MONITORINFO);

  if (GetMonitorInfo(primaryMonitor, &monitorInfo))
  {
    *width = monitorInfo.rcMonitor.right - monitorInfo.rcMonitor.left;
    *height = monitorInfo.rcMonitor.bottom - monitorInfo.rcMonitor.top;
  }
  else
  {
    // Fallback to system metrics if GetMonitorInfo fails
    *width = GetSystemMetrics(SM_CXSCREEN);
    *height = GetSystemMetrics(SM_CYSCREEN);
  }
}

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command)
{
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent())
  {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  // Get screen dimensions
  int screenWidth = 0;
  int screenHeight = 0;
  GetPrimaryMonitorDimensions(&screenWidth, &screenHeight);

  FlutterWindow window(project);
  // Set the origin to (0, 0) to align with the top-left corner of the screen
  Win32Window::Point origin(0, 0);
  // Use the detected screen dimensions (adjust if needed for taskbar, etc.)
  Win32Window::Size size(screenWidth, screenHeight);

  if (!window.Create(L"cb_file_manager", origin, size))
  {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  // Show the window maximized for best experience
  window.ShowMaximized();

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0))
  {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
