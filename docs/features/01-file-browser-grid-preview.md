## File Browser Grid + Preview Mode

### Requirements
- Desktop only: add a new view mode alongside list/grid/details.
- Preview pane on the right in grid mode; allow toggle show/hide.
- Resize the preview pane by dragging the divider.
- Preview images, videos, and PDFs; reuse existing video player and image viewer for open actions.
- Not available on mobile.

### Behavior
- Uses `ViewMode.gridPreview` for the grid + preview layout.
- Preview pane width is resizable and persisted; default width is 360px.
- Preview pane width is constrained:
  - Minimum 280px.
  - Maximum is `min(80% of window width, window width - 360px)`.
  - If the window is too narrow, the layout falls back to grid-only.
- Toggle button in the app bar hides/shows the preview pane.
- Single click selects items in grid preview; double click opens.

### Preview Support
- Video: uses the existing `VideoPlayer.file` widget.
- Image: inline `InteractiveViewer` preview; open action uses the existing image viewer.
- PDF: rendered via `pdfx` (`PdfView`).
- Network paths show a placeholder (no preview) to avoid streaming file reads.

### Storage
- Preferences are stored in `UserPreferences`:
  - `preview_pane_visible`
  - `preview_pane_width`

### Platform Notes
- Mobile maps `gridPreview` to `grid` when loading view mode preferences.

### Files
1. `cb_file_manager/lib/ui/widgets/file_preview_pane.dart`
2. `cb_file_manager/lib/ui/widgets/file_list_view_builder.dart`
3. `cb_file_manager/lib/ui/screens/folder_list/folder_list_state.dart`
4. `cb_file_manager/lib/ui/mixins/preferences_manager_mixin.dart`
5. `cb_file_manager/lib/helpers/core/user_preferences.dart`
