# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**CoolBird File Manager** is a cross-platform Flutter application that provides advanced file management capabilities with network browsing support (FTP, SMB, WebDAV), media playback, and a sophisticated tagging system.

## Development Commands

### Essential Commands
- `flutter run` - Run the application in debug mode
- `flutter run --release` - Run in release mode
- `flutter build windows` - Build for Windows desktop
- `flutter build apk` - Build Android APK
- `flutter test` - Run all tests
- `flutter analyze` - Analyze code for issues
- `dart format .` - Format all Dart files

### Build System
- `flutter pub get` - Install dependencies
- `flutter packages pub run build_runner build` - Generate ObjectBox code
- `flutter packages pub run build_runner build --delete-conflicting-outputs` - Clean regenerate
- `flutter clean` - Clean build artifacts

### Platform-Specific
- **Windows**: Uses CMake build system with native SMB support
- **Android**: Gradle build system with Kotlin DSL
- **Web**: Standard Flutter web build

## Architecture Overview

### Core Structure
```
lib/
├── main.dart                    # Application entry point
├── bloc/                       # State management (BLoC pattern)
│   ├── network_browsing/       # Network service state
│   └── selection/              # File selection state
├── services/                   # Business logic services
│   ├── network_browsing/       # Network protocols (FTP, SMB, WebDAV)
│   └── network_credentials_service.dart
├── models/                     # Data models
│   ├── database/               # Database models
│   └── objectbox/              # ObjectBox entities
├── helpers/                    # Utility functions
├── utils/                      # Core utilities
│   └── app_logger.dart         # Centralized logging framework
├── ui/                         # User interface
│   ├── screens/                # Application screens
│   ├── components/             # Reusable UI components
│   └── widgets/                # Custom widgets
└── config/                     # Configuration and themes
```

### Key Components

**State Management**: BLoC pattern with separate blocs for network browsing, selection, and folder management.

**Network Services**: Service registry pattern with pluggable network protocols:
- `NetworkServiceRegistry` - Central service manager
- `NetworkServiceBase` - Base interface for all network services
- Individual service implementations for FTP, SMB, WebDAV

**Database**: ObjectBox for local storage with entities for tags, preferences, and credentials.

**Tab Management**: Multi-tab interface supporting both local and network paths with format `#network/TYPE/HOST/`.

## Network Browsing System

### Service Architecture
Services implement `NetworkServiceBase` and register with `NetworkServiceRegistry`. Network paths use format:
- `#network/FTP/hostname/path`
- `#network/SMB/hostname/share/path`
- `#network/WEBDAV/hostname/path`

### Adding New Network Services
1. Implement `NetworkServiceBase` interface
2. Register in `NetworkServiceRegistry` constructor
3. Add UI components in `ui/screens/network_browsing/`
4. Update `NetworkBrowsingBloc` if needed

## Database Schema

### ObjectBox Entities
- `FileTag` - File tagging system
- `UserPreference` - Application preferences
- `NetworkCredentials` - Stored network credentials

### Database Operations
- `DatabaseManager` - Singleton database manager
- `NetworkCredentialsService` - Network credential management
- `TagManager` - Tag operations

## Key Dependencies

### Core Flutter
- `flutter_bloc` - State management
- `path_provider` - File system paths
- `permission_handler` - System permissions
- `logger` - Structured logging framework

### Media & Video
- `media_kit` - Cross-platform media playback
- `video_thumbnail` - Video thumbnail generation
- `chewie` - Video player UI

### Network & Storage
- `smb_connect` - SMB/CIFS protocol support
- `objectbox` - Local database
- `flutter_cache_manager` - File caching

### Platform Integration
- `window_manager` - Desktop window management
- `win32` - Windows platform APIs
- `ffi` - Foreign function interface

## Development Patterns

### Logging Framework
The application uses a centralized logging framework (`utils/app_logger.dart`) based on the `logger` package.

**Never use `print()` statements in production code.** Always use the logging framework:

```dart
import 'package:cb_file_manager/utils/app_logger.dart';

// Different log levels
AppLogger.debug('Detailed debug information');
AppLogger.info('General informational messages');
AppLogger.warning('Warning messages');
AppLogger.error('Error occurred', error: exception, stackTrace: stackTrace);
AppLogger.fatal('Fatal errors');
```

**Benefits:**
- Structured logging with timestamps and colors
- Log levels for filtering (debug, info, warning, error, fatal)
- Automatic method call traces for debugging
- Stack traces for errors
- Production-ready with proper error context

**Configuration:**
- Log level can be adjusted via `AppLogger.setLevel(Level.info)`
- Pretty printing with emojis and colors enabled by default
- Logs include file name, line number, and method context

### Error Handling
- Use `try-catch` blocks for async operations
- Return `ConnectionResult` objects for network operations
- Emit error states in BLoC for UI feedback
- Always log errors using `AppLogger.error()` with error object and stack trace

### Performance Optimization
- `FrameTimingOptimizer` for rendering performance
- Image cache management with size limits
- Lazy loading for large directories
- Thumbnail caching system

### File Operations
- Use `path` package for cross-platform path handling
- Implement proper platform-specific file operations
- Handle both local and network file systems

## Testing

### Running Tests
- `flutter test` - All tests
- `flutter test test/ftp_entry_type_test.dart` - Specific test
- `flutter test --coverage` - With coverage

### Test Structure
- Limited test coverage currently exists
- Focus on FTP parsing logic testing
- Add tests for new network services

## Windows Native Integration

### SMB Support
- `windows/smb_native/` - Native SMB implementation
- `lib/services/network_browsing/smb_native_bindings.dart` - Dart bindings
- Uses Win32 APIs for SMB operations

### FFmpeg Integration
- `windows/ffmpeg/` - FFmpeg libraries
- Video thumbnail generation
- Cross-platform media support

## Configuration Files

### Analysis Options
- `analysis_options.yaml` - Uses `package:flutter_lints/flutter.yaml`
- Standard Flutter linting rules enabled

### Build Configuration
- `pubspec.yaml` - Dependencies and assets
- `windows/CMakeLists.txt` - Windows build configuration
- `android/build.gradle.kts` - Android build configuration

## Common Development Tasks

### Adding New Features
1. Create appropriate models in `models/`
2. Add service logic in `services/`
3. Create BLoC for state management
4. Implement UI in `ui/screens/`
5. Add navigation and routing

### Debugging Network Issues
1. Enable verbose logging in network services
2. Check `NetworkServiceRegistry` connection management
3. Verify path format for network operations
4. Test service availability with `isAvailable()`

### Performance Issues
1. Check `FrameTimingOptimizer` usage
2. Verify image cache settings
3. Profile with `flutter run --profile`
4. Monitor memory usage during scrolling

## Known Limitations

- Limited test coverage across the codebase
- Network service error handling could be more robust
- Some Windows-specific features may not work on other platforms
- Large directory browsing may have performance issues