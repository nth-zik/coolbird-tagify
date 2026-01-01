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

_Last reviewed: 2025-10-25_
