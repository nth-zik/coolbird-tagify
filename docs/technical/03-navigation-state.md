## Navigation & State Management

- **TabShell** `ui/tab_manager/core/tab_main_screen.dart` hosts the tabbed experience via `TabManagerBloc` and `NetworkBrowsingBloc`.
- **TabLifecycle** `TabMainScreen.openPath(context, path)` dispatches `AddTab` events; tabs render through `TabScreen` composables.
- **PermissionsGate** On first frame, `PermissionStateService` checks storage/network permissions and pushes `PermissionExplainerScreen` if needed.
- **Mobile Actions** `ui/tab_manager/mobile/mobile_file_actions_controller.dart` coordinates action bars shared across file list and media galleries.
- **Selection Logic** `bloc/selection/` tracks multi-select state and exposes BLoC events for UI components.

_Last reviewed: 2025-10-25_
