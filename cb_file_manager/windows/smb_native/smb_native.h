#pragma once

#include <windows.h>
#include <cstdint>    // For int32_t, int64_t, uint8_t etc.
#include <shobjidl.h> // For thumbnail interfaces
#include <winnetwk.h>
#include <lm.h>

#if defined(_WIN32)
#define FFI_EXPORT extern "C" __declspec(dllexport)
#else
#define FFI_EXPORT extern "C"
#endif

// Struct to pass file information back to Dart.
// This must match the structure in Dart FFI.
struct NativeFileInfo
{
    wchar_t *name;
    int64_t size;
    int64_t modification_time; // UTC milliseconds since epoch
    bool is_directory;
};

struct NativeFileList
{
    int32_t count;
    NativeFileInfo *files;
};

struct NativeShareInfo
{
    wchar_t *name;
    wchar_t *comment;
    int32_t type;
};

struct NativeShareList
{
    int32_t count;
    NativeShareInfo *shares;
};

struct ReadResult
{
    int64_t bytes_read;
    uint8_t *data; // Pointer to the data buffer
};

struct ThumbnailResult
{
    uint8_t *data;
    int32_t size;
};

// --- Connection Management ---
FFI_EXPORT int32_t Connect(const wchar_t *path, const wchar_t *username, const wchar_t *password);
FFI_EXPORT int32_t Disconnect(const wchar_t *path);

// --- File and Directory Operations ---
FFI_EXPORT NativeFileList *ListDirectory(const wchar_t *path);
FFI_EXPORT NativeShareList *EnumerateShares(const wchar_t *server);
FFI_EXPORT bool DeleteFileOrDir(const wchar_t *path);
FFI_EXPORT bool CreateDir(const wchar_t *path);
FFI_EXPORT bool Rename(const wchar_t *old_path, const wchar_t *new_path);

// --- File I/O (Streaming) ---
FFI_EXPORT HANDLE OpenFileForReading(const wchar_t *path);
FFI_EXPORT HANDLE CreateFileForWriting(const wchar_t *path);
FFI_EXPORT ReadResult ReadFileChunk(HANDLE handle, int64_t chunk_size);
FFI_EXPORT bool WriteFileChunk(HANDLE handle, uint8_t *data, int32_t length);
FFI_EXPORT void CloseFile(HANDLE handle);

// --- Thumbnail Generation ---
FFI_EXPORT ThumbnailResult GetThumbnail(const wchar_t *path, int32_t size);
FFI_EXPORT ThumbnailResult GetThumbnailFast(const wchar_t *path, int32_t size);

// --- Memory Management ---
FFI_EXPORT void FreeFileList(NativeFileList *file_list);
FFI_EXPORT void FreeShareList(NativeShareList *share_list);
FFI_EXPORT void FreeReadResultData(uint8_t *data);
FFI_EXPORT void FreeThumbnailResult(ThumbnailResult result);