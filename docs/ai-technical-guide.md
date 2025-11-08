# CoolBird FM File Manager – Technical Guide for AI Agents

## Purpose
- **Audience** AI agents and developers needing a fast mental model of the `cb_file_manager` app.
- **Scope** Highlights runtime flow, core modules, data sources, and cross-platform constraints.
- **Dependencies** Built on Flutter; all paths referenced below live under `cb_file_manager/` unless noted.

## System Overview
- **AppType** Cross-platform file manager targeting Android, iOS, Windows, macOS, and Linux.
- **EntryPoint** `lib/main.dart` bootstraps services, theming, localization, and the tab-based UI shell.
- **PrimaryFeatures** Local storage browsing, tagging, media galleries, streaming, SMB/FTP/WebDAV access, and PiP playback windows.

```text
lib/
├── bloc/                     # flutter_bloc state machines (network browsing, selection)
├── config/                   # Theme + localization controllers and resources
├── helpers/                  # Cross-cutting utilities (filesystem, media, tags, caching)
├── models/                   # ObjectBox entities and domain models
├── services/                 # Business logic (albums, streaming, networking, background workers)
├── ui/                       # Screens, components, and tab manager shell
├── widgets/                  # Standalone reusable widgets
└── main.dart                 # Initialization sequence and app root
```

## Execution Flow (`lib/main.dart`)
- **InitializationOrder** Ensures platform bindings, media kit, window manager, and optimization helpers load before UI rendering.
- **ServiceBootstrapping** Sequentially initializes `FrameTimingOptimizer`, `MediaKit`, `StreamingServiceManager`, `UserPreferences`, `DatabaseManager`, `NetworkCredentialsService`, `BatchTagManager`, `TagManager`, `FolderThumbnailService`, `VideoThumbnailHelper`, and `LanguageController`.
- **PlatformBranches** Desktop paths configure `window_manager`; mobile paths reset system UI overlays.
- **NavigatorKey** Global `navigatorKey` exposes routing hooks for PiP and dev tooling.
- **ErrorHandling** `runZonedGuarded` wraps startup to log but not crash on recoverable faults.

## Navigation & State Management
- **TabShell** `ui/tab_manager/core/tab_main_screen.dart` hosts the tabbed experience via `TabManagerBloc` and `NetworkBrowsingBloc`.
- **TabLifecycle** `TabMainScreen.openPath(context, path)` dispatches `AddTab` events; tabs render through `TabScreen` composables.
- **PermissionsGate** On first frame, `PermissionStateService` checks storage/network permissions and pushes `PermissionExplainerScreen` if needed.
- **Mobile Actions** `ui/tab_manager/mobile/mobile_file_actions_controller.dart` coordinates action bars shared across file list and media galleries.
- **Selection Logic** `bloc/selection/` tracks multi-select state and exposes BLoC events for UI components.

## Layer Catalogue
| Layer | Representative Paths | Highlights |
| --- | --- | --- |
| Configuration | `config/theme_config.dart`, `config/app_theme.dart`, `config/languages/` | Minimal theme tokens, color scheme, localization delegates, runtime language switching. |
| Helpers | `helpers/core/filesystem_utils.dart`, `helpers/media/`, `helpers/tags/` | Filesystem traversal, media caches, tag batch operations, platform-specific utilities. |
| Services | `services/album_*`, `services/network_browsing/`, `services/streaming/` | Long-running tasks, isolates, network adapters (FTP/SMB/WebDAV), streaming session orchestration. |
| UI Screens | `ui/screens/media_gallery/`, `ui/screens/permissions/`, `ui/screens/settings/` | Feature-specific views with responsive layouts and shared action patterns. |
| UI Components | `ui/components/` | Reusable cards, buttons, bottom sheets, PiP controls, gallery tiles. |
| Widgets | `widgets/` | Leaf widgets consumed across multiple screens (e.g., progress indicators). |
| Data Models | `models/` + `objectbox-model.json` | ObjectBox entities for files, tags, preferences, plus DAO helpers. |

## Data & Persistence
- **Database** ObjectBox (`objectbox.dart`, `objectbox.g.dart`) stores tags, metadata, user preferences.
- **Preferences** `helpers/core/user_preferences.dart` exposes async singleton used during app boot to provide theme, grid size, language defaults.
- **Credential Vault** `services/network_credentials_service.dart` initializes with ObjectBox store to manage SMB/FTP auth.
- **Caching** `helpers/media/video_thumbnail_helper.dart` and `helpers/media/folder_thumbnail_service.dart` handle disk + memory caches for previews.

## Filesystem & Media Access
- **Filesystem API** `helpers/core/filesystem_utils.dart` centralizes directory listing, search, and recursive scanning; includes mobile-specific fallbacks for empty gallery paths.
- **Album Pipeline** `services/album_*` family uses isolates and background scanners to build smart/featured albums.
- **Streaming** `services/streaming_service_manager.dart` coordinates `StreamingService` implementations (media_kit-backed) and ensures `MediaKitAudioHelper` is configured for Windows.
- **PiP Windows** `ui/components/video/pip_window/desktop_pip_window.dart` and `services/pip_window_service.dart` support desktop picture-in-picture playback.

## UI Standards & Theming
- **Minimal Theme** Import `config/app_theme.dart` / `MinimalTheme` helpers; never hardcode colors or spacing.
- **Design Rules** See `docs/coding-rules/theme-styling-guide.md` for spacing (`spacing(4/8/12/16/20/24)`), radii (`radius(16/20/24/28)`), icon sizes (`icons(18/22/24)`), and flat design philosophy (avoid borders, prefer subtle shadows and opacity).
- **Builders** Use shared factories like `buildIconButton()` and `buildCloseButton()`; line icons only (`*_line`).
- **Mobile Galleries** `ui/screens/media_gallery/` follow flat cards (no elevation) and reuse `MobileFileActionsController` for top action bars.

## Localization (Mandatory)
- **Rule** All user-facing strings must go through i18n keys.
- **Implementation** Import `config/languages/app_localizations.dart` or call `context.tr.keyName`.
- **Adding Keys** Update `config/languages/app_localizations.dart`, `config/languages/english_localizations.dart`, and `config/languages/vietnamese_localizations.dart` in tandem.
- **Reference** `docs/coding-rules/i18n-internationalization-guide.md` documents the workflow.

## Testing & Tooling
- **Test Harness** See `test/` and scripts documented in `docs/testing-strategy.md`; infra includes `run_tests.dart`, `stable_tests.dart`, and CI-ready runners.
- **Coverage Focus** Navigation flows and core widgets presently covered; expand for new galleries or services when modified.
- **Diagnostics** Use verbose logging toggled in `VideoThumbnailHelper` during `kDebugMode` to trace cache behavior.

## Platform Notes
- **Desktop** `window_manager` ensures minimum window size, hidden title bar, and maximized start on Windows.
- **Mobile** Startup configures full system UI overlays and leverages platform storage permissions via `PermissionStateService`.
- **PiP Mode** Environment variable `CB_PIP_MODE=1` triggers lightweight PiP-only window bootstrap.

## Key Gotchas & Workarounds
- **Initialization Order** Always await `_loadPreferences()` before registering controllers that rely on `_thumbnailSize` (see `ui/screens/media_gallery/video_gallery_screen.dart`).
- **Tag Systems** Invoke `BatchTagManager.initialize()` and `TagManager.initialize()` during startup; failing to do so breaks gallery tagging.
- **Gallery Scans** Empty gallery paths trigger recursive scans of common media directories (DCIM, Movies, Download, Pictures, Screenshots) inside `getAllVideos()` / `getAllImages()`.
- **Network Modules** Legacy SMB helpers under `services/network_browsing/` may need refactors for modern authentication; consult `smb_refactor_plan.md` before changes.

## Extending the App Safely
- **Feature Checklist** When adding screens, wire actions through `MobileFileActionsController`, hook BLoC events, and provide i18n keys.
- **Theming Checklist** Use theme tokens (`theme.colorScheme.*`, `MinimalTheme.spacing()`), avoid literal numbers unless defined constants exist.
- **Testing Checklist** Add or update tests and runners documented in `docs/testing-strategy.md`; verify manual regressions on target platforms.
- **Documentation** Update both this guide and feature-specific docs under `docs/features/` for substantial changes.

---
_Last reviewed: 2025-10-25_
