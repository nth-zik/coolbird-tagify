#include "fc_native_video_thumbnail_plugin.h"

// This must be included before many other Windows headers.
#include <atlimage.h>
#include <comdef.h>
#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>
#include <gdiplus.h>
#include <gdiplusimaging.h>
#include <shlwapi.h>
#include <thumbcache.h>
#include <wincodec.h>
#include <windows.h>
#include <wingdi.h>
// MediaFoundation headers for timestamp-based extraction
#include <mfapi.h>
#include <mfidl.h>
#include <mfreadwrite.h>
#include <propvarutil.h>

#include <codecvt>
#include <iostream>
#include <locale>
#include <memory>
#include <sstream>
#include <string>

const std::string kGetThumbnailFailedExtraction = "Failed extraction";

// Need to link with these libraries for MediaFoundation
#pragma comment(lib, "mfplat.lib")
#pragma comment(lib, "mfuuid.lib")
#pragma comment(lib, "mfreadwrite.lib")
#pragma comment(lib, "propsys.lib")

namespace fc_native_video_thumbnail {

const flutter::EncodableValue* ValueOrNull(const flutter::EncodableMap& map, const char* key) {
  auto it = map.find(flutter::EncodableValue(key));
  if (it == map.end()) {
    return nullptr;
  }
  return &(it->second);
}

std::optional<int64_t> GetInt64ValueOrNull(const flutter::EncodableMap& map,
                                           const char* key) {
  auto value = ValueOrNull(map, key);
  if (!value) {
    return std::nullopt;
  }

  if (std::holds_alternative<int32_t>(*value)) {
    return static_cast<int64_t>(std::get<int32_t>(*value));
  }
  auto val64 = std::get_if<int64_t>(value);
  if (!val64) {
    return std::nullopt;
  }
  return *val64;
}

std::wstring Utf16FromUtf8(const std::string& utf8_string) {
  if (utf8_string.empty()) {
    return std::wstring();
  }
  int target_length =
      ::MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, utf8_string.data(),
                            static_cast<int>(utf8_string.length()), nullptr, 0);
  if (target_length == 0) {
    return std::wstring();
  }
  std::wstring utf16_string;
  utf16_string.resize(target_length);
  int converted_length =
      ::MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, utf8_string.data(),
                            static_cast<int>(utf8_string.length()),
                            utf16_string.data(), target_length);
  if (converted_length == 0) {
    return std::wstring();
  }
  return utf16_string;
}

std::string HRESULTToString(HRESULT hr) {
  _com_error error(hr);
  CString cs;
  cs.Format(_T("Error 0x%08x: %s"), hr, error.ErrorMessage());

  std::string res;

#ifdef UNICODE
  int wlen = lstrlenW(cs);
  int len = WideCharToMultiByte(CP_ACP, 0, cs, wlen, NULL, 0, NULL, NULL);
  res.resize(len);
  WideCharToMultiByte(CP_ACP, 0, cs, wlen, &res[0], len, NULL, NULL);
#else
  res = errMsg;
#endif
  return res;
}

int GetEncoderClsid(const WCHAR* format, CLSID* pClsid) {
  UINT num = 0;
  UINT size = 0;

  Gdiplus::ImageCodecInfo* pImageCodecInfo = NULL;

  Gdiplus::GetImageEncodersSize(&num, &size);
  if (size == 0) return -1;

  pImageCodecInfo = (Gdiplus::ImageCodecInfo*)(malloc(size));
  if (pImageCodecInfo == NULL) return -1;

  Gdiplus::GetImageEncoders(num, size, pImageCodecInfo);

  for (UINT j = 0; j < num; ++j) {
    if (wcscmp(pImageCodecInfo[j].MimeType, format) == 0) {
      *pClsid = pImageCodecInfo[j].Clsid;
      free(pImageCodecInfo);
      return j;
    }
  }

  free(pImageCodecInfo);
  return -1;
}

std::string ExtractVideoFrameAtTime(PCWSTR srcFile, PCWSTR destFile, int width, REFGUID format, int timeSeconds) {
  HRESULT hr = S_OK;

  hr = MFStartup(MF_VERSION, MFSTARTUP_LITE);
  if (FAILED(hr)) {
    return "MFStartup failed with " + HRESULTToString(hr);
  }

  IMFSourceReader* pReader = NULL;

  hr = MFCreateSourceReaderFromURL(srcFile, NULL, &pReader);
  if (FAILED(hr)) {
    MFShutdown();
    return "MFCreateSourceReaderFromURL failed with " + HRESULTToString(hr);
  }

  // Fix signed/unsigned mismatch - cast to DWORD explicitly
  hr = pReader->SetStreamSelection(static_cast<DWORD>(MF_SOURCE_READER_ALL_STREAMS), FALSE);
  if (FAILED(hr)) {
    pReader->Release();
    MFShutdown();
    return "Failed to deselect all streams with " + HRESULTToString(hr);
  }

  // Fix signed/unsigned mismatch - cast to DWORD explicitly
  hr = pReader->SetStreamSelection(static_cast<DWORD>(MF_SOURCE_READER_FIRST_VIDEO_STREAM), TRUE);
  if (FAILED(hr)) {
    pReader->Release();
    MFShutdown();
    return "Failed to select video stream with " + HRESULTToString(hr);
  }
  
  // Get the native media type from the source
  IMFMediaType* pNativeType = NULL;
  hr = pReader->GetNativeMediaType(static_cast<DWORD>(MF_SOURCE_READER_FIRST_VIDEO_STREAM), 0, &pNativeType);
  if (FAILED(hr)) {
    pReader->Release();
    MFShutdown();
    return "Failed to get native media type with " + HRESULTToString(hr);
  }

  // Create a new media type for the output
  IMFMediaType* pType = NULL;
  hr = MFCreateMediaType(&pType);
  if (FAILED(hr)) {
    pNativeType->Release();
    pReader->Release();
    MFShutdown();
    return "MFCreateMediaType failed with " + HRESULTToString(hr);
  }

  // Setup output media type based on native type
  hr = pType->SetGUID(MF_MT_MAJOR_TYPE, MFMediaType_Video);
  if (FAILED(hr)) {
    pType->Release();
    pNativeType->Release();
    pReader->Release();
    MFShutdown();
    return "Failed to set media type with " + HRESULTToString(hr);
  }

  // Try different pixel formats in order of preference
  const GUID pixelFormats[] = {
    MFVideoFormat_RGB32,   // Try RGB32 first
    MFVideoFormat_RGB24,   // Then RGB24
    MFVideoFormat_YUY2,    // Then YUY2
    MFVideoFormat_NV12     // Then NV12 (commonly supported)
  };
  
  bool formatSet = false;
  
  for (int i = 0; i < 4; i++) {
    hr = pType->SetGUID(MF_MT_SUBTYPE, pixelFormats[i]);
    if (FAILED(hr)) {
      continue;
    }
    
    // Try to set this media type
    hr = pReader->SetCurrentMediaType(static_cast<DWORD>(MF_SOURCE_READER_FIRST_VIDEO_STREAM), NULL, pType);
    if (SUCCEEDED(hr)) {
      formatSet = true;
      break;
    }
  }
  
  // If none of our preferred formats worked, try using the native format
  if (!formatSet) {
    GUID nativeSubtype;
    hr = pNativeType->GetGUID(MF_MT_SUBTYPE, &nativeSubtype);
    if (SUCCEEDED(hr)) {
      hr = pType->SetGUID(MF_MT_SUBTYPE, nativeSubtype);
      if (SUCCEEDED(hr)) {
        hr = pReader->SetCurrentMediaType(static_cast<DWORD>(MF_SOURCE_READER_FIRST_VIDEO_STREAM), NULL, pType);
        formatSet = SUCCEEDED(hr);
      }
    }
  }
  
  pNativeType->Release();

  if (!formatSet) {
    pType->Release();
    pReader->Release();
    MFShutdown();
    return "Failed to set any compatible media type for this video";
  }

  pType->Release();
  pType = NULL;

  // Get the current media type to determine actual format
  IMFMediaType* pCurrentType = NULL;
  hr = pReader->GetCurrentMediaType(static_cast<DWORD>(MF_SOURCE_READER_FIRST_VIDEO_STREAM), &pCurrentType);
  if (FAILED(hr)) {
    pReader->Release();
    MFShutdown();
    return "Failed to get current media type with " + HRESULTToString(hr);
  }

  // Get the actual pixel format we're using
  GUID actualFormat;
  hr = pCurrentType->GetGUID(MF_MT_SUBTYPE, &actualFormat);
  if (FAILED(hr)) {
    pCurrentType->Release();
    pReader->Release();
    MFShutdown();
    return "Failed to get pixel format with " + HRESULTToString(hr);
  }

  PROPVARIANT var;
  PropVariantInit(&var);
  var.vt = VT_I8;
  var.hVal.QuadPart = ULONGLONG(timeSeconds) * 10000000;

  hr = pReader->SetCurrentPosition(GUID_NULL, var);
  PropVariantClear(&var);
  if (FAILED(hr)) {
    pCurrentType->Release();
    pReader->Release();
    MFShutdown();
    return "Failed to seek to position with " + HRESULTToString(hr);
  }

  DWORD streamIndex, flags;
  LONGLONG timestamp;
  IMFSample* pSample = NULL;

  // Fix signed/unsigned mismatch - cast to DWORD explicitly
  hr = pReader->ReadSample(static_cast<DWORD>(MF_SOURCE_READER_FIRST_VIDEO_STREAM), 0, &streamIndex, &flags, &timestamp, &pSample);
  if (FAILED(hr) || !pSample) {
    if (pSample) pSample->Release();
    pCurrentType->Release();
    pReader->Release();
    MFShutdown();
    return "ReadSample failed with " + HRESULTToString(hr);
  }

  IMFMediaBuffer* pBuffer = NULL;
  hr = pSample->ConvertToContiguousBuffer(&pBuffer);
  if (FAILED(hr)) {
    pSample->Release();
    pCurrentType->Release();
    pReader->Release();
    MFShutdown();
    return "ConvertToContiguousBuffer failed with " + HRESULTToString(hr);
  }

  BYTE* pBitmapData = NULL;
  DWORD cbBitmapData = 0;
  hr = pBuffer->Lock(&pBitmapData, NULL, &cbBitmapData);
  if (FAILED(hr)) {
    pBuffer->Release();
    pSample->Release();
    pCurrentType->Release();
    pReader->Release();
    MFShutdown();
    return "Buffer lock failed with " + HRESULTToString(hr);
  }

  UINT32 videoWidth = 0, videoHeight = 0;
  hr = MFGetAttributeSize(pCurrentType, MF_MT_FRAME_SIZE, &videoWidth, &videoHeight);
  if (FAILED(hr)) {
    pBuffer->Unlock();
    pBuffer->Release();
    pSample->Release();
    pCurrentType->Release();
    pReader->Release();
    MFShutdown();
    return "MFGetAttributeSize failed with " + HRESULTToString(hr);
  }

  // Get stride information (needed for correct image rendering)
  LONG stride = 0;
  hr = pCurrentType->GetUINT32(MF_MT_DEFAULT_STRIDE, (UINT32*)&stride);
  
  // If we couldn't get the stride, calculate it based on pixel format
  if (FAILED(hr)) {
    if (actualFormat == MFVideoFormat_RGB32) {
      stride = videoWidth * 4;
    } else if (actualFormat == MFVideoFormat_RGB24) {
      stride = videoWidth * 3;
    } else if (actualFormat == MFVideoFormat_YUY2) {
      stride = videoWidth * 2;
    } else if (actualFormat == MFVideoFormat_NV12) {
      stride = videoWidth;
    } else {
      // Default to width * 4 for unknown formats
      stride = videoWidth * 4;
    }
  }

  pCurrentType->Release();

  // Initialize GDI+
  Gdiplus::GdiplusStartupInput gdiplusStartupInput;
  ULONG_PTR gdiplusToken;
  Gdiplus::GdiplusStartup(&gdiplusToken, &gdiplusStartupInput, NULL);

  Gdiplus::Bitmap* pGdiPlusBitmap = NULL;
  
  // Create a bitmap with the appropriate pixel format
  if (actualFormat == MFVideoFormat_RGB32) {
    pGdiPlusBitmap = new Gdiplus::Bitmap(videoWidth, videoHeight, stride, PixelFormat32bppRGB, pBitmapData);
  } else if (actualFormat == MFVideoFormat_RGB24) {
    pGdiPlusBitmap = new Gdiplus::Bitmap(videoWidth, videoHeight, stride, PixelFormat24bppRGB, pBitmapData);
  } else {
    // For non-RGB formats, we need to convert the data
    // Create an empty bitmap and set the pixels
    pGdiPlusBitmap = new Gdiplus::Bitmap(videoWidth, videoHeight, PixelFormat32bppRGB);
    
    // Use GDI+ to draw into the bitmap since we can't directly use the pixel data
    Gdiplus::BitmapData bitmapData;
    Gdiplus::Rect rect(0, 0, videoWidth, videoHeight);
    
    if (pGdiPlusBitmap->LockBits(&rect, Gdiplus::ImageLockModeWrite, 
                                PixelFormat32bppRGB, &bitmapData) == Gdiplus::Ok) {
      // Simple handling for YUY2 and NV12 formats
      // Note: This is a simplified conversion that won't be perfect
      // For production use, consider using a proper colorspace conversion library
      if (actualFormat == MFVideoFormat_YUY2) {
        // YUY2 to RGB conversion - simplified implementation
        for (UINT y = 0; y < videoHeight; y++) {
          const BYTE* srcRow = pBitmapData + (y * abs(stride));
          BYTE* dstRow = (BYTE*)bitmapData.Scan0 + (y * bitmapData.Stride);
          
          for (UINT x = 0; x < videoWidth; x += 2) {
            // YUY2 is Y0, U0, Y1, V0
            BYTE Y0 = srcRow[x * 2];
            BYTE U0 = srcRow[x * 2 + 1];
            BYTE Y1 = srcRow[x * 2 + 2];
            BYTE V0 = srcRow[x * 2 + 3];
            
            // Convert two pixels at once
            for (int i = 0; i < 2; i++) {
              BYTE Y = (i == 0) ? Y0 : Y1;
              
              // Very basic YUV to RGB conversion
              int C = Y - 16;
              int D = U0 - 128;
              int E = V0 - 128;
              
              int R = (298 * C + 409 * E + 128) >> 8;
              int G = (298 * C - 100 * D - 208 * E + 128) >> 8;
              int B = (298 * C + 516 * D + 128) >> 8;
              
              // Clamp values
              R = (R < 0) ? 0 : (R > 255) ? 255 : R;
              G = (G < 0) ? 0 : (G > 255) ? 255 : G;
              B = (B < 0) ? 0 : (B > 255) ? 255 : B;
              
              // Fix C4244 warnings - explicit cast to BYTE
              dstRow[(x + i) * 4 + 0] = static_cast<BYTE>(B);
              dstRow[(x + i) * 4 + 1] = static_cast<BYTE>(G);
              dstRow[(x + i) * 4 + 2] = static_cast<BYTE>(R);
              dstRow[(x + i) * 4 + 3] = 255; // Alpha
            }
          }
        }
      } else if (actualFormat == MFVideoFormat_NV12) {
        // NV12 to RGB conversion - simplified implementation
        UINT chromaOffset = videoHeight * stride;
        
        for (UINT y = 0; y < videoHeight; y++) {
          const BYTE* srcY = pBitmapData + (y * stride);
          const BYTE* srcUV = pBitmapData + chromaOffset + ((y / 2) * stride);
          BYTE* dstRow = (BYTE*)bitmapData.Scan0 + (y * bitmapData.Stride);
          
          for (UINT x = 0; x < videoWidth; x++) {
            BYTE Y = srcY[x];
            BYTE U = srcUV[(x / 2) * 2];
            BYTE V = srcUV[(x / 2) * 2 + 1];
            
            // Basic YUV to RGB conversion
            int C = Y - 16;
            int D = U - 128;
            int E = V - 128;
            
            int R = (298 * C + 409 * E + 128) >> 8;
            int G = (298 * C - 100 * D - 208 * E + 128) >> 8;
            int B = (298 * C + 516 * D + 128) >> 8;
            
            // Clamp values
            R = (R < 0) ? 0 : (R > 255) ? 255 : R;
            G = (G < 0) ? 0 : (G > 255) ? 255 : G;
            B = (B < 0) ? 0 : (B > 255) ? 255 : B;
            
            // Fix C4244 warnings - explicit cast to BYTE
            dstRow[x * 4 + 0] = static_cast<BYTE>(B);
            dstRow[x * 4 + 1] = static_cast<BYTE>(G);
            dstRow[x * 4 + 2] = static_cast<BYTE>(R);
            dstRow[x * 4 + 3] = 255; // Alpha
          }
        }
      } else {
        // For unsupported formats, just fill with gray
        for (UINT y = 0; y < videoHeight; y++) {
          BYTE* dstRow = (BYTE*)bitmapData.Scan0 + (y * bitmapData.Stride);
          for (UINT x = 0; x < videoWidth; x++) {
            dstRow[x * 4 + 0] = 128;
            dstRow[x * 4 + 1] = 128;
            dstRow[x * 4 + 2] = 128;
            dstRow[x * 4 + 3] = 255;
          }
        }
      }
      
      pGdiPlusBitmap->UnlockBits(&bitmapData);
    }
  }

  int thumbnailWidth = width;
  int thumbnailHeight = (int)(((float)videoHeight / videoWidth) * width);

  Gdiplus::Bitmap* pResizedBitmap = new Gdiplus::Bitmap(thumbnailWidth, thumbnailHeight, PixelFormat32bppRGB);
  Gdiplus::Graphics* pGraphics = Gdiplus::Graphics::FromImage(pResizedBitmap);
  pGraphics->SetInterpolationMode(Gdiplus::InterpolationModeHighQualityBicubic);
  pGraphics->DrawImage(pGdiPlusBitmap, 0, 0, thumbnailWidth, thumbnailHeight);

  CLSID clsid;
  if (format == Gdiplus::ImageFormatPNG) {
    GetEncoderClsid(L"image/png", &clsid);
  } else {
    GetEncoderClsid(L"image/jpeg", &clsid);
  }

  Gdiplus::Status status = pResizedBitmap->Save(destFile, &clsid, NULL);

  delete pGraphics;
  delete pResizedBitmap;
  delete pGdiPlusBitmap;

  pBuffer->Unlock();
  pBuffer->Release();
  pSample->Release();
  pReader->Release();
  Gdiplus::GdiplusShutdown(gdiplusToken);
  MFShutdown();

  if (status != Gdiplus::Ok) {
    return "Failed to save image with GDI+ status code: " + std::to_string(status);
  }

  return "";
}

std::string SaveThumbnail(PCWSTR srcFile, PCWSTR destFile, int size, REFGUID type, int* timeSeconds) {
  if (timeSeconds != nullptr) {
    Gdiplus::GdiplusStartupInput gdiplusStartupInput;
    ULONG_PTR gdiplusToken;
    Gdiplus::GdiplusStartup(&gdiplusToken, &gdiplusStartupInput, NULL);

    std::string result = ExtractVideoFrameAtTime(srcFile, destFile, size, type, *timeSeconds);

    Gdiplus::GdiplusShutdown(gdiplusToken);
    return result;
  }

  IShellItem* pSI;
  HRESULT hr = SHCreateItemFromParsingName(srcFile, NULL, IID_IShellItem, (void**)&pSI);
  if (!SUCCEEDED(hr)) {
    return "`SHCreateItemFromParsingName` failed with " + HRESULTToString(hr);
  }

  IThumbnailCache* pThumbCache;
  hr = CoCreateInstance(CLSID_LocalThumbnailCache,
                        NULL,
                        CLSCTX_INPROC_SERVER,
                        IID_PPV_ARGS(&pThumbCache));

  if (!SUCCEEDED(hr)) {
    pSI->Release();
    return "`CoCreateInstance` failed with " + HRESULTToString(hr);
  }
  ISharedBitmap* pSharedBitmap = NULL;
  hr = pThumbCache->GetThumbnail(pSI,
                                 size,
                                 WTS_EXTRACT | WTS_SCALETOREQUESTEDSIZE,
                                 &pSharedBitmap,
                                 NULL,
                                 NULL);

  if (!SUCCEEDED(hr) || !pSharedBitmap) {
    pSI->Release();
    pThumbCache->Release();
    if (hr == WTS_E_FAILEDEXTRACTION) {
      return kGetThumbnailFailedExtraction;
    }
    return "`GetThumbnail` failed with " + HRESULTToString(hr);
  }
  HBITMAP hBitmap;
  hr = pSharedBitmap->GetSharedBitmap(&hBitmap);
  if (!SUCCEEDED(hr) || !hBitmap) {
    pSI->Release();
    pSharedBitmap->Release();
    pThumbCache->Release();
    return "`GetSharedBitmap` failed with " + HRESULTToString(hr);
  }

  pSI->Release();
  pSharedBitmap->Release();
  pThumbCache->Release();

  CImage image;
  image.Attach(hBitmap);
  hr = image.Save(destFile, type);
  if (!SUCCEEDED(hr)) {
    return "`image.Attach` failed with " + HRESULTToString(hr);
  }
  return "";
}

void FcNativeVideoThumbnailPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows* registrar) {
  auto channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(), "fc_native_video_thumbnail",
          &flutter::StandardMethodCodec::GetInstance());

  auto plugin = std::make_unique<FcNativeVideoThumbnailPlugin>();

  channel->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto& call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });

  registrar->AddPlugin(std::move(plugin));
}

FcNativeVideoThumbnailPlugin::FcNativeVideoThumbnailPlugin() {}

FcNativeVideoThumbnailPlugin::~FcNativeVideoThumbnailPlugin() {}

void FcNativeVideoThumbnailPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const auto* argsPtr = std::get_if<flutter::EncodableMap>(method_call.arguments());
  assert(argsPtr);
  auto args = *argsPtr;
  if (method_call.method_name().compare("getVideoThumbnail") == 0) {
    const auto* src_file =
        std::get_if<std::string>(ValueOrNull(args, "srcFile"));
    assert(src_file);

    const auto* dest_file =
        std::get_if<std::string>(ValueOrNull(args, "destFile"));
    assert(dest_file);

    const auto* width =
        std::get_if<int>(ValueOrNull(args, "width"));
    assert(width);

    const auto* outType =
        std::get_if<std::string>(ValueOrNull(args, "format"));
    assert(outType);

    int* timeSeconds = nullptr;
    int timeSecondsValue = 0;
    const auto* time_seconds_val = ValueOrNull(args, "timeSeconds");
    if (time_seconds_val != nullptr && std::holds_alternative<int>(*time_seconds_val)) {
      timeSecondsValue = std::get<int>(*time_seconds_val);
      timeSeconds = &timeSecondsValue;
    }

    auto oper_res = SaveThumbnail(
        Utf16FromUtf8(*src_file).c_str(), 
        Utf16FromUtf8(*dest_file).c_str(), 
        *width, 
        outType->compare("png") == 0 ? Gdiplus::ImageFormatPNG : Gdiplus::ImageFormatJPEG,
        timeSeconds);

    if (oper_res == kGetThumbnailFailedExtraction) {
      result->Success(flutter::EncodableValue(false));
    } else if (oper_res != "") {
      result->Error("PluginError", "Operation failed. " + oper_res);
    } else {
      result->Success(flutter::EncodableValue(true));
    }
  } else {
    result->NotImplemented();
  }
}

}  // namespace fc_native_video_thumbnail
