## Data & Persistence

- **Database** ObjectBox (`objectbox.dart`, `objectbox.g.dart`) stores tags, metadata, user preferences.
- **Preferences** `helpers/core/user_preferences.dart` exposes async singleton used during app boot to provide theme, grid size, language defaults, and navigation workspace settings.
- **Preview Pane** Grid preview mode persists `preview_pane_visible` and `preview_pane_width` preferences for desktop layout.
- **Sidebar Pins** `sidebar_pinned_paths` stores ordered pinned filesystem paths used by the drawer `Pinned` section.
- **Tab Workspace Restore** `remember_tab_workspace`, `last_opened_tab_path`, and `drawer_section_states_by_tab` control last-tab restore and per-tab drawer expansion state persistence.
- **Credential Vault** `services/network_credentials_service.dart` initializes with ObjectBox store to manage SMB/FTP auth.
- **Caching** `helpers/media/video_thumbnail_helper.dart` and `helpers/media/folder_thumbnail_service.dart` handle disk + memory caches for previews.

_Last reviewed: 2026-02-15_
