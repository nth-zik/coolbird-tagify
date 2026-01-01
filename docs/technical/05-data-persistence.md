## Data & Persistence

- **Database** ObjectBox (`objectbox.dart`, `objectbox.g.dart`) stores tags, metadata, user preferences.
- **Preferences** `helpers/core/user_preferences.dart` exposes async singleton used during app boot to provide theme, grid size, language defaults.
- **Credential Vault** `services/network_credentials_service.dart` initializes with ObjectBox store to manage SMB/FTP auth.
- **Caching** `helpers/media/video_thumbnail_helper.dart` and `helpers/media/folder_thumbnail_service.dart` handle disk + memory caches for previews.

_Last reviewed: 2025-10-25_
