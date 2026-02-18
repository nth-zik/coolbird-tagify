# Sidebar Pinning + Workspace Restore

## Summary

This feature adds a dedicated `Pinned` section in the drawer and lets users pin any filesystem path (drive, folder, or file) from context menus. It also adds optional tab workspace restore so the app can reopen the last active tab and remember drawer section expansion per tab.

## User-Facing Behavior

- Pin and unpin actions are available from file, folder, and drive context menus.
- Action labels are state-aware:
  - `Pin to Sidebar` when the path is not pinned.
  - `Unpin from Sidebar` when the path is already pinned.
- The drawer shows pinned items in a separate `Pinned` section, not inside the drives list.
- Pinned items can be removed directly from the drawer with an unpin button.
- A toast/snackbar confirms the result:
  - `Pinned to sidebar`
  - `Removed from sidebar`

## Workspace Restore Option

- Settings path: `Settings -> Interface -> Remember tab workspace`.
- When enabled:
  - The app restores the last opened tab path on startup (for the main desktop window).
  - Drawer expansion state is stored per tab for at least:
    - `storage`
    - `pinned`
- When disabled:
  - Stored last opened tab path is cleared.
  - Stored drawer section states are cleared.
  - Future session restores are skipped until re-enabled.

## Persistence Keys

The feature uses `UserPreferences` keys:

- `sidebar_pinned_paths`: ordered list of pinned paths.
- `remember_tab_workspace`: global on/off flag for workspace restore.
- `last_opened_tab_path`: last active tab path.
- `drawer_section_states_by_tab`: per-tab expansion map for drawer sections.

## Implementation Pointers

1. `cb_file_manager/lib/ui/components/common/shared_file_context_menu.dart`
2. `cb_file_manager/lib/ui/tab_manager/components/drive_view.dart`
3. `cb_file_manager/lib/ui/widgets/drawer/pinned_section_widget.dart`
4. `cb_file_manager/lib/ui/widgets/drawer/cubit/drawer_cubit.dart`
5. `cb_file_manager/lib/ui/tab_manager/core/tab_screen.dart`
6. `cb_file_manager/lib/ui/screens/settings/settings_screen.dart`
7. `cb_file_manager/lib/helpers/core/user_preferences.dart`
8. `cb_file_manager/lib/config/languages/app_localizations.dart`

_Last updated: 2026-02-15_
