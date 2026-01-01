## Execution Flow

### Initialization Order

- Ensures platform bindings, media kit, window manager, and optimization helpers load before UI rendering.

### Service Bootstrapping

- Sequentially initializes `FrameTimingOptimizer`, `MediaKit`, `StreamingServiceManager`, `UserPreferences`, `DatabaseManager`, `NetworkCredentialsService`, `BatchTagManager`, `TagManager`, `FolderThumbnailService`, `VideoThumbnailHelper`, and `LanguageController`.

### Platform Branches

- Desktop paths configure `window_manager`; mobile paths reset system UI overlays.

### Navigator & Error Handling

- Global `navigatorKey` exposes routing hooks for PiP and dev tooling.
- `runZonedGuarded` wraps startup to log but not crash on recoverable faults.

_Last reviewed: 2025-10-25_
