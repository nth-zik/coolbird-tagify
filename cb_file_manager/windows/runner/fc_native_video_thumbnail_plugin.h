#ifndef FLUTTER_PLUGIN_FC_NATIVE_VIDEO_THUMBNAIL_PLUGIN_H_
#define FLUTTER_PLUGIN_FC_NATIVE_VIDEO_THUMBNAIL_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <gdiplus.h>

#include <memory>

namespace fc_native_video_thumbnail {

// Helper function to get the CLSID of an image encoder
int GetEncoderClsid(const WCHAR* format, CLSID* pClsid);

// Extract a frame from a video at a specific timestamp using MediaFoundation
std::string ExtractVideoFrameAtTime(PCWSTR srcFile, PCWSTR destFile, int width, REFGUID format, int timeSeconds);

// Save a thumbnail, either using Windows thumbnail cache or MediaFoundation based on if timeSeconds is provided
std::string SaveThumbnail(PCWSTR srcFile, PCWSTR destFile, int size, REFGUID type, int* timeSeconds = nullptr);

class FcNativeVideoThumbnailPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  FcNativeVideoThumbnailPlugin();

  virtual ~FcNativeVideoThumbnailPlugin();

  // Disallow copy and assign.
  FcNativeVideoThumbnailPlugin(const FcNativeVideoThumbnailPlugin&) = delete;
  FcNativeVideoThumbnailPlugin& operator=(const FcNativeVideoThumbnailPlugin&) = delete;

 private:
  // Called when a method is called on this plugin's channel from Dart.
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};

}  // namespace fc_native_video_thumbnail

#endif  // FLUTTER_PLUGIN_FC_NATIVE_VIDEO_THUMBNAIL_PLUGIN_H_
