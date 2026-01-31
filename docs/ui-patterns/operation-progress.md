# Operation Progress (Status Bar)

Use this pattern for long-running operations (e.g. delete, move-to-trash, copy, move) so the UI shows immediate feedback and the user can keep working.

## UX behavior

- When an operation starts, a progress pill appears at the bottom of the screen.
- While running, it shows a title, a progress bar, and a counter (`completed/total`) or an indeterminate bar.
- When finished:
  - Success auto-dismisses after a short delay.
  - Errors stay visible until dismissed.

## Architecture

- `OperationProgressController` is a global singleton (registered in the GetIt service locator).
- `OperationProgressOverlay` is inserted once into the app's root `Overlay` (from `TabMainScreen`) and renders the bottom status bar based on controller state.
- Any feature can report progress without needing a `BuildContext`.

Implementation:

- `cb_file_manager/lib/ui/controllers/operation_progress_controller.dart`
- `cb_file_manager/lib/ui/components/common/operation_progress_overlay.dart`
- `cb_file_manager/lib/ui/tab_manager/core/tab_main_screen.dart`

## Usage

1. Start an operation:

```dart
final controller = locator<OperationProgressController>();
final id = controller.begin(title: 'Deleting items', total: 12);
```

2. Update progress as work completes:

```dart
controller.update(id, completed: 3, detail: 'file.mp4');
```

3. Finish:

```dart
controller.succeed(id, detail: 'Done');
// or
controller.fail(id, detail: 'Failed to delete 2 items');
```

## Notes / limitations

- The controller currently tracks a single active operation. Starting a new one replaces the previous entry.
- Keep `title` short and localized; use `detail` for the current item name or context.
