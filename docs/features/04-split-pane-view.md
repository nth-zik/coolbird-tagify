# Split Pane View for Tab — Implementation Plan (Desktop only)

## TL;DR ✅

Add a split-pane mode to a tab so a single tab can show two independent folder panes (left | right). Each pane keeps its own navigation state and address bar; focus is shown with a highlighted border. Add a "Open in Split View" item to folder context menus and a keyboard shortcut (Ctrl+\) to toggle split.

---

## Goals

- Desktop-only feature (Windows / Linux / macOS).
- Split a tab into two independent folder panes (left / right).
- Address bar and action bar operate per-pane; the pane with keyboard/mouse focus is visually highlighted.
- Right-click on a folder → "Open in Split View" opens it in the right-hand pane.
- Keyboard: Ctrl+\\ toggles split/unsplit for active tab.

## High-level approach

- Store split state on the Tab model (new field on `TabData`).
- Add TabManager BLoC events to open/close a split pane.
- Create a new `SplitPaneView` widget that composes two `TabbedFolderListScreen` instances side-by-side.
- Integrate `SplitPaneView` inside `_createTabContent` in `tab_screen.dart` when a tab has split data.
- Add context menu action and `EntityOpenActions.openInSplitView` helper.

---

## Files to change / add (exact paths)

- Update: `lib/ui/tab_manager/core/tab_data.dart` (add split state)
- Update: `lib/ui/tab_manager/core/tab_manager.dart` (events/handlers)
- Update: `lib/ui/tab_manager/core/tab_screen.dart` (use SplitPaneView when tab.splitPanePath != null; add shortcut)
- Add: `lib/ui/tab_manager/core/split_pane_view.dart` (new widget)
- Update: `lib/ui/components/common/shared_file_context_menu.dart` and `lib/ui/tab_manager/components/folder_context_menu.dart` (add "Open in Split View")
- Update: `lib/ui/utils/entity_open_actions.dart` (add openInSplitView)
- Update: localization: `lib/config/languages/app_localizations.dart`, English & Vietnamese files (add `openInSplitView`)

---

## Implementation steps (detailed)

1. Model: TabData

- Add `final String? splitPanePath;` to `TabData` (null = single pane).
- Update constructor, `copyWith()` and history-related helpers.
- Keep persisted behavior unchanged (split state is in-memory initially — optional later persist).

2. BLoC: TabManager

- Add events: `OpenSplitPane(tabId, path)` and `CloseSplitPane(tabId)`.
- Implement handlers to update `TabData.splitPanePath` (via `copyWith`).
- Emit state so `TabScreen` rebuilds and shows `SplitPaneView`.

3. New widget: `SplitPaneView`

- File: `lib/ui/tab_manager/core/split_pane_view.dart`.
- API: `SplitPaneView({required String tabId, required String leftPath, required String rightPath})`.
- Layout: `Row` with two `Expanded` children separated by a draggable divider.
- Each child is a `TabbedFolderListScreen` (pass `tabId` to each so controllers use tab-scoped keys where needed).
- Manage focus via a `ValueNotifier` or internal state; onTap on a pane sets focused pane.
- Visual: focused pane shows `Border.all(color: theme.colorScheme.primary, width: 2)`.
- Preview pane width is adjustable and saved to `previewPaneWidth` setting when user drags divider.
- Keyboard focus, selection, and navigation are local to each `TabbedFolderListScreen`.

4. Integration in Tab system

- In `_createTabContent(TabData tab)` (in `tab_screen.dart`), if `tab.splitPanePath != null` return `SplitPaneView(...)` instead of `TabbedFolderListScreen`.
- Ensure `_tabContentCache` strategy continues to work (keyed by tab.id).

5. Shortcut & AppBar toggle

- Add `ToggleSplitViewIntent` mapping to Ctrl+\\ in `TabScreen` shortcuts.
- Action toggles: if current tab has split → dispatch `CloseSplitPane`; else → `OpenSplitPane` (set right path to same as left or to user's selection).
- Optional: add a toolbar button in tab actions to toggle split.

6. Context menu: "Open in Split View"

- Add menu item to folder and file context menus (desktop only).
- Hook it to `EntityOpenActions.openInSplitView(context, sourcePath: folder.path)`.
- Implementation: dispatch `OpenSplitPane(tabId: activeTab.id, path: sourcePath)` to `TabManagerBloc`.

7. Localization

- Add `openInSplitView` to `app_localizations.dart` and translations in English & Vietnamese.

8. UX / edge cases

- If tab already split: `Open in Split View` replaces right pane's path.
- If right pane path equals left path, that’s allowed (user can view same folder both sides).
- When closing a split, right pane state is discarded.
- Ensure selection/clipboard/file-ops remain pane-local.

---

## Keyboard & Mouse UX

- Shortcut: Ctrl+\\ toggles split on active tab.
- Click inside a pane sets that pane as focused (visual border + address bar prominence).
- Draggable divider (mouse) to resize panes; committed width saved to user prefs.
- Context menu entry: `Open in Split View` (desktop only).

---

## Verification / Tests

- Manual tests: open/close split, resize divider, navigate independently in each pane, focus switching, right-click → open in split, Ctrl+\\ toggling.
- Unit / widget tests:
  - `TabManagerBloc` event handlers for Open/CloseSplitPane
  - `SplitPaneView` renders two `TabbedFolderListScreen` and handles focus change
  - Context menu triggers `EntityOpenActions.openInSplitView`

---

## Decisions / rationale

- Each pane remains a full `TabbedFolderListScreen` to reuse navigation, selection, and preview logic (minimal invasive changes).
- `TabData.splitPanePath` keeps split state local to a tab and simple to manage.
- Desktop-only first delivery to avoid complex mobile/responsive behavior.

---

## Future enhancements

- Persist split state per-tab across app restarts.
- Support vertical split (top/bottom) toggle.
- Add drag-and-drop between panes (file move/copy UI affordance).

---

## Quick reference (where to implement)

- Tab model & BLoC: `lib/ui/tab_manager/core/tab_data.dart`, `tab_manager.dart`
- Tab screen: `lib/ui/tab_manager/core/tab_screen.dart`
- New split UI: `lib/ui/tab_manager/core/split_pane_view.dart` (new)
- Context menus: `lib/ui/components/common/shared_file_context_menu.dart`, `lib/ui/tab_manager/components/folder_context_menu.dart`
- Actions helper: `lib/ui/utils/entity_open_actions.dart`
- Localization: `lib/config/languages/*`

---

If you want, I can now implement the changes (create widgets, update BLoC, add menu item and tests). Which step should I do next?
