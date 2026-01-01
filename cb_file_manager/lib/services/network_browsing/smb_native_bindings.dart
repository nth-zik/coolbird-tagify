import 'dart:ffi';

import 'package:ffi/ffi.dart';

// --- C Structs definitions for Dart ---

class NativeFileInfo extends Struct {
  external Pointer<Utf16> name;
  @Int64()
  external int size;
  @Int64()
  external int modification_time;
  @Bool()
  external bool is_directory;
}

class NativeFileList extends Struct {
  @Int32()
  external int count;
  external Pointer<NativeFileInfo> files;
}

class NativeShareInfo extends Struct {
  external Pointer<Utf16> name;
  external Pointer<Utf16> comment;
  @Int32()
  external int type;
}

class NativeShareList extends Struct {
  @Int32()
  external int count;
  external Pointer<NativeShareInfo> shares;
}

class ReadResult extends Struct {
  @Int64()
  external int bytes_read;
  external Pointer<Uint8> data;
}

class ThumbnailResult extends Struct {
  external Pointer<Uint8> data;
  @Int32()
  external int size;
}

// --- FFI Function Signatures ---

// Connection
typedef _ConnectNative = Int32 Function(
    Pointer<Utf16> path, Pointer<Utf16> username, Pointer<Utf16> password);
typedef _ConnectDart = int Function(
    Pointer<Utf16> path, Pointer<Utf16> username, Pointer<Utf16> password);
typedef _DisconnectNative = Int32 Function(Pointer<Utf16> path);
typedef _DisconnectDart = int Function(Pointer<Utf16> path);

// File Operations
typedef _ListDirectoryNative = Pointer<NativeFileList> Function(
    Pointer<Utf16> path);
typedef _ListDirectoryDart = Pointer<NativeFileList> Function(
    Pointer<Utf16> path);
typedef _EnumerateSharesNative = Pointer<NativeShareList> Function(
    Pointer<Utf16> server);
typedef _EnumerateSharesDart = Pointer<NativeShareList> Function(
    Pointer<Utf16> server);
typedef _DeleteFileOrDirNative = Bool Function(Pointer<Utf16> path);
typedef _DeleteFileOrDirDart = bool Function(Pointer<Utf16> path);
typedef _CreateDirNative = Bool Function(Pointer<Utf16> path);
typedef _CreateDirDart = bool Function(Pointer<Utf16> path);
typedef _RenameNative = Bool Function(
    Pointer<Utf16> oldPath, Pointer<Utf16> newPath);
typedef _RenameDart = bool Function(
    Pointer<Utf16> oldPath, Pointer<Utf16> newPath);

// File I/O
typedef _OpenFileForReadingNative = IntPtr Function(Pointer<Utf16> path);
typedef _OpenFileForReadingDart = int Function(Pointer<Utf16> path);
typedef _CreateFileForWritingNative = IntPtr Function(Pointer<Utf16> path);
typedef _CreateFileForWritingDart = int Function(Pointer<Utf16> path);
typedef _ReadFileChunkNative = ReadResult Function(
    IntPtr handle, Int64 chunkSize);
typedef _ReadFileChunkDart = ReadResult Function(int handle, int chunkSize);
typedef _WriteFileChunkNative = Bool Function(
    IntPtr handle, Pointer<Uint8> data, Int32 length);
typedef _WriteFileChunkDart = bool Function(
    int handle, Pointer<Uint8> data, int length);
typedef _CloseFileNative = Void Function(IntPtr handle);
typedef _CloseFileDart = void Function(int handle);

// Thumbnail
typedef _GetThumbnailNative = ThumbnailResult Function(
    Pointer<Utf16> path, Int32 size);
typedef _GetThumbnailDart = ThumbnailResult Function(
    Pointer<Utf16> path, int size);

// Memory Management
typedef _FreeFileListNative = Void Function(Pointer<NativeFileList> list);
typedef _FreeFileListDart = void Function(Pointer<NativeFileList> list);
typedef _FreeShareListNative = Void Function(Pointer<NativeShareList> list);
typedef _FreeShareListDart = void Function(Pointer<NativeShareList> list);
typedef _FreeReadResultDataNative = Void Function(Pointer<Uint8> data);
typedef _FreeReadResultDataDart = void Function(Pointer<Uint8> data);
typedef _FreeThumbnailResultNative = Void Function(ThumbnailResult result);
typedef _FreeThumbnailResultDart = void Function(ThumbnailResult result);

/// A class that provides a high-level Dart interface to the native SMB functions.
class SMBNativeBindings {
  late final DynamicLibrary _lib;

  // Function lookups
  late final _ConnectDart connect;
  late final _DisconnectDart disconnect;
  late final _ListDirectoryDart listDirectory;
  late final _EnumerateSharesDart enumerateShares;
  late final _DeleteFileOrDirDart deleteFileOrDir;
  late final _CreateDirDart createDir;
  late final _RenameDart rename;
  late final _OpenFileForReadingDart openFileForReading;
  late final _CreateFileForWritingDart createFileForWriting;
  late final _ReadFileChunkDart readFileChunk;
  late final _WriteFileChunkDart writeFileChunk;
  late final _CloseFileDart closeFile;
  late final _GetThumbnailDart getThumbnail;
  late final _FreeFileListDart freeFileList;
  late final _FreeShareListDart freeShareList;
  late final _FreeReadResultDataDart freeReadResultData;
  late final _FreeThumbnailResultDart freeThumbnailResult;

  SMBNativeBindings() {
    _lib = DynamicLibrary.open('smb_native.dll');

    // Look up the functions
    connect = _lib
        .lookup<NativeFunction<_ConnectNative>>('Connect')
        .asFunction<_ConnectDart>();
    disconnect = _lib
        .lookup<NativeFunction<_DisconnectNative>>('Disconnect')
        .asFunction<_DisconnectDart>();
    listDirectory = _lib
        .lookup<NativeFunction<_ListDirectoryNative>>('ListDirectory')
        .asFunction<_ListDirectoryDart>();
    enumerateShares = _lib
        .lookup<NativeFunction<_EnumerateSharesNative>>('EnumerateShares')
        .asFunction<_EnumerateSharesDart>();
    deleteFileOrDir = _lib
        .lookup<NativeFunction<_DeleteFileOrDirNative>>('DeleteFileOrDir')
        .asFunction<_DeleteFileOrDirDart>();
    createDir = _lib
        .lookup<NativeFunction<_CreateDirNative>>('CreateDir')
        .asFunction<_CreateDirDart>();
    rename = _lib
        .lookup<NativeFunction<_RenameNative>>('Rename')
        .asFunction<_RenameDart>();
    openFileForReading = _lib
        .lookup<NativeFunction<_OpenFileForReadingNative>>('OpenFileForReading')
        .asFunction<_OpenFileForReadingDart>();
    createFileForWriting = _lib
        .lookup<NativeFunction<_CreateFileForWritingNative>>(
            'CreateFileForWriting')
        .asFunction<_CreateFileForWritingDart>();
    readFileChunk = _lib
        .lookup<NativeFunction<_ReadFileChunkNative>>('ReadFileChunk')
        .asFunction<_ReadFileChunkDart>();
    writeFileChunk = _lib
        .lookup<NativeFunction<_WriteFileChunkNative>>('WriteFileChunk')
        .asFunction<_WriteFileChunkDart>();
    closeFile = _lib
        .lookup<NativeFunction<_CloseFileNative>>('CloseFile')
        .asFunction<_CloseFileDart>();
    getThumbnail = _lib
        .lookup<NativeFunction<_GetThumbnailNative>>('GetThumbnail')
        .asFunction<_GetThumbnailDart>();
    freeFileList = _lib
        .lookup<NativeFunction<_FreeFileListNative>>('FreeFileList')
        .asFunction<_FreeFileListDart>();
    freeShareList = _lib
        .lookup<NativeFunction<_FreeShareListNative>>('FreeShareList')
        .asFunction<_FreeShareListDart>();
    freeReadResultData = _lib
        .lookup<NativeFunction<_FreeReadResultDataNative>>('FreeReadResultData')
        .asFunction<_FreeReadResultDataDart>();
    freeThumbnailResult = _lib
        .lookup<NativeFunction<_FreeThumbnailResultNative>>(
            'FreeThumbnailResult')
        .asFunction<_FreeThumbnailResultDart>();
  }
}
