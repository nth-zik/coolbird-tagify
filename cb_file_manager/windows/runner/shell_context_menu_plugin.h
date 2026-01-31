#pragma once

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>

class ShellContextMenuPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows* registrar);

  explicit ShellContextMenuPlugin(flutter::PluginRegistrarWindows* registrar);
  ~ShellContextMenuPlugin() override;

  ShellContextMenuPlugin(const ShellContextMenuPlugin&) = delete;
  ShellContextMenuPlugin& operator=(const ShellContextMenuPlugin&) = delete;

 private:
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  flutter::PluginRegistrarWindows* registrar_;
};
