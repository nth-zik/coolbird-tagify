## CoolBird FM File Manager — AI Technical Overview

### Purpose

- **Audience** AI agents and developers needing a fast mental model of the `cb_file_manager` app.
- **Scope** Highlights runtime flow, core modules, data sources, and cross-platform constraints.
- **Dependencies** Built on Flutter; all paths referenced below live under `cb_file_manager/` unless noted.

### System Overview

- **AppType** Cross-platform file manager targeting Android, iOS, Windows, macOS, and Linux.
- **EntryPoint** `lib/main.dart` bootstraps services, theming, localization, and the tab-based UI shell.
- **PrimaryFeatures** Local storage browsing, tagging, media galleries, streaming, SMB/FTP/WebDAV access, and PiP playback windows.

```
lib/
├── bloc/                     # flutter_bloc state machines (network browsing, selection)
├── config/                   # Theme + localization controllers and resources
├── helpers/                  # Cross-cutting utilities (filesystem, media, tags, caching)
├── utils/                    # Core utilities (logging framework)
├── models/                   # ObjectBox entities and domain models
├── services/                 # Business logic (albums, streaming, networking, background workers)
├── ui/                       # Screens, components, and tab manager shell
├── widgets/                  # Standalone reusable widgets
└── main.dart                 # Initialization sequence and app root
```

_Last reviewed: 2025-10-25_
