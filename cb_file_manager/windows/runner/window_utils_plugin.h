#ifndef RUNNER_WINDOW_UTILS_PLUGIN_H_
#define RUNNER_WINDOW_UTILS_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <windows.h>

#include <memory>

struct IDropTarget;

class WindowUtilsPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows* registrar);

  explicit WindowUtilsPlugin(flutter::PluginRegistrarWindows* registrar);
  virtual ~WindowUtilsPlugin();

  WindowUtilsPlugin(const WindowUtilsPlugin&) = delete;
  WindowUtilsPlugin& operator=(const WindowUtilsPlugin&) = delete;

 private:
  void EnsureDropTargetRegistered();
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  flutter::PluginRegistrarWindows* registrar_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
  HWND drop_target_hwnd_ = nullptr;
  IDropTarget* drop_target_ = nullptr;
};

#endif  // RUNNER_WINDOW_UTILS_PLUGIN_H_
