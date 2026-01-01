## Filesystem & Media Access

- **Filesystem API** `helpers/core/filesystem_utils.dart` centralizes directory listing, search, and recursive scanning; includes mobile-specific fallbacks for empty gallery paths.
- **Album Pipeline** `services/album_*` family uses isolates and background scanners to build smart/featured albums.
- **Streaming** `services/streaming_service_manager.dart` coordinates `StreamingService` implementations (media_kit-backed) and ensures `MediaKitAudioHelper` is configured for Windows.
- **PiP Windows** `ui/components/video/pip_window/desktop_pip_window.dart` and `services/pip_window_service.dart` support desktop picture-in-picture playback.

_Last reviewed: 2025-10-25_
