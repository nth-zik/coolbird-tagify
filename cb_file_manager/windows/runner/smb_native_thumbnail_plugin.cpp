#include "smb_native_thumbnail_plugin.h"
#include "../smb_native/smb_native.h"

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <sstream>
#include <codecvt>

namespace {

class SmbNativeThumbnailPluginImpl : public flutter::Plugin {
public:
    static void RegisterWithRegistrar(flutter::PluginRegistrarWindows* registrar);

    SmbNativeThumbnailPluginImpl();
    virtual ~SmbNativeThumbnailPluginImpl();

private:
    void HandleMethodCall(
        const flutter::MethodCall<flutter::EncodableValue>& method_call,
        std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

    // Native thumbnail generation methods
    bool IsAvailable();
    std::vector<uint8_t> GetThumbnail(const std::string& file_path, int32_t thumbnail_size);
    std::vector<uint8_t> GetThumbnailFast(const std::string& file_path, int32_t thumbnail_size);

    // Helper methods
    std::wstring StringToWString(const std::string& str);
    std::string WStringToString(const std::wstring& wstr);
};

// static
void SmbNativeThumbnailPluginImpl::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows* registrar) {
    auto channel =
        std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
            registrar->messenger(), "smb_native_thumbnail",
            &flutter::StandardMethodCodec::GetInstance());

    auto plugin = std::make_unique<SmbNativeThumbnailPluginImpl>();

    channel->SetMethodCallHandler(
        [plugin_pointer = plugin.get()](const auto& call, auto result) {
            plugin_pointer->HandleMethodCall(call, std::move(result));
        });

    registrar->AddPlugin(std::move(plugin));
}

SmbNativeThumbnailPluginImpl::SmbNativeThumbnailPluginImpl() {}

SmbNativeThumbnailPluginImpl::~SmbNativeThumbnailPluginImpl() {}

void SmbNativeThumbnailPluginImpl::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
    
    if (method_call.method_name().compare("isAvailable") == 0) {
        result->Success(flutter::EncodableValue(IsAvailable()));
        return;
    }

    if (method_call.method_name().compare("getThumbnail") == 0) {
        const auto* arguments = std::get_if<flutter::EncodableMap>(method_call.arguments());
        if (!arguments) {
            result->Error("INVALID_ARGUMENTS", "Expected map arguments");
            return;
        }

        auto file_path_it = arguments->find(flutter::EncodableValue("filePath"));
        auto thumbnail_size_it = arguments->find(flutter::EncodableValue("thumbnailSize"));

        if (file_path_it == arguments->end() || thumbnail_size_it == arguments->end()) {
            result->Error("MISSING_ARGUMENTS", "filePath and thumbnailSize are required");
            return;
        }

        const std::string* file_path = std::get_if<std::string>(&file_path_it->second);
        const int* thumbnail_size = std::get_if<int>(&thumbnail_size_it->second);

        if (!file_path || !thumbnail_size) {
            result->Error("INVALID_ARGUMENT_TYPES", "filePath must be string, thumbnailSize must be int");
            return;
        }

        auto thumbnail_data = GetThumbnail(*file_path, static_cast<int32_t>(*thumbnail_size));
        if (thumbnail_data.empty()) {
            result->Success(flutter::EncodableValue());
        } else {
            result->Success(flutter::EncodableValue(thumbnail_data));
        }
        return;
    }

    if (method_call.method_name().compare("getThumbnailFast") == 0) {
        const auto* arguments = std::get_if<flutter::EncodableMap>(method_call.arguments());
        if (!arguments) {
            result->Error("INVALID_ARGUMENTS", "Expected map arguments");
            return;
        }

        auto file_path_it = arguments->find(flutter::EncodableValue("filePath"));
        auto thumbnail_size_it = arguments->find(flutter::EncodableValue("thumbnailSize"));

        if (file_path_it == arguments->end() || thumbnail_size_it == arguments->end()) {
            result->Error("MISSING_ARGUMENTS", "filePath and thumbnailSize are required");
            return;
        }

        const std::string* file_path = std::get_if<std::string>(&file_path_it->second);
        const int* thumbnail_size = std::get_if<int>(&thumbnail_size_it->second);

        if (!file_path || !thumbnail_size) {
            result->Error("INVALID_ARGUMENT_TYPES", "filePath must be string, thumbnailSize must be int");
            return;
        }

        auto thumbnail_data = GetThumbnailFast(*file_path, static_cast<int32_t>(*thumbnail_size));
        if (thumbnail_data.empty()) {
            result->Success(flutter::EncodableValue());
        } else {
            result->Success(flutter::EncodableValue(thumbnail_data));
        }
        return;
    }

    result->NotImplemented();
}

bool SmbNativeThumbnailPluginImpl::IsAvailable() {
    // Simple availability check - just return true since we're on Windows
    // Could add more sophisticated checks here if needed
    return true;
}

std::vector<uint8_t> SmbNativeThumbnailPluginImpl::GetThumbnail(const std::string& file_path, int32_t thumbnail_size) {
    std::vector<uint8_t> result;
    
    try {
        // Convert string to wstring for native call
        std::wstring wfile_path = StringToWString(file_path);
        
        // Call native SMB thumbnail function
        ThumbnailResult thumbnail_result = ::GetThumbnail(wfile_path.c_str(), thumbnail_size);
        
        if (thumbnail_result.data && thumbnail_result.size > 0) {
            // Copy data to vector
            result.assign(thumbnail_result.data, thumbnail_result.data + thumbnail_result.size);
            
            // Free the native memory
            ::FreeThumbnailResult(thumbnail_result);
        }
    } catch (const std::exception& e) {
        // Log error but don't crash
        OutputDebugStringA(("SmbNativeThumbnailPlugin::GetThumbnail error: " + std::string(e.what())).c_str());
    } catch (...) {
        OutputDebugStringA("SmbNativeThumbnailPlugin::GetThumbnail unknown error");
    }
    
    return result;
}

std::vector<uint8_t> SmbNativeThumbnailPluginImpl::GetThumbnailFast(const std::string& file_path, int32_t thumbnail_size) {
    std::vector<uint8_t> result;
    
    try {
        // Convert string to wstring for native call
        std::wstring wfile_path = StringToWString(file_path);
        
        // Call native SMB thumbnail function (fast version)
        ThumbnailResult thumbnail_result = ::GetThumbnailFast(wfile_path.c_str(), thumbnail_size);
        
        if (thumbnail_result.data && thumbnail_result.size > 0) {
            // Copy data to vector
            result.assign(thumbnail_result.data, thumbnail_result.data + thumbnail_result.size);
            
            // Free the native memory
            ::FreeThumbnailResult(thumbnail_result);
        }
    } catch (const std::exception& e) {
        // Log error but don't crash
        OutputDebugStringA(("SmbNativeThumbnailPlugin::GetThumbnailFast error: " + std::string(e.what())).c_str());
    } catch (...) {
        OutputDebugStringA("SmbNativeThumbnailPlugin::GetThumbnailFast unknown error");
    }
    
    return result;
}

std::wstring SmbNativeThumbnailPluginImpl::StringToWString(const std::string& str) {
    if (str.empty()) return std::wstring();
    
    int size_needed = MultiByteToWideChar(CP_UTF8, 0, &str[0], (int)str.size(), NULL, 0);
    std::wstring wstrTo(size_needed, 0);
    MultiByteToWideChar(CP_UTF8, 0, &str[0], (int)str.size(), &wstrTo[0], size_needed);
    return wstrTo;
}

std::string SmbNativeThumbnailPluginImpl::WStringToString(const std::wstring& wstr) {
    if (wstr.empty()) return std::string();
    
    int size_needed = WideCharToMultiByte(CP_UTF8, 0, &wstr[0], (int)wstr.size(), NULL, 0, NULL, NULL);
    std::string strTo(size_needed, 0);
    WideCharToMultiByte(CP_UTF8, 0, &wstr[0], (int)wstr.size(), &strTo[0], size_needed, NULL, NULL);
    return strTo;
}

}  // namespace

void SmbNativeThumbnailPluginRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
    SmbNativeThumbnailPluginImpl::RegisterWithRegistrar(
        flutter::PluginRegistrarManager::GetInstance()
            ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}