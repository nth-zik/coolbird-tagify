# Internationalization (i18n) Guide

## Overview
All user-facing strings in CoolBird FM Flutter app **MUST** use internationalization. No hardcoded strings are allowed in the UI code.

## Why i18n?
- **Multi-language support**: App currently supports English and Vietnamese
- **Maintainability**: Centralized string management
- **Consistency**: Ensures all UI text follows the same translation system
- **User experience**: Users can switch languages seamlessly

## Implementation Rules

### 1. Import Required Package
```dart
import 'package:cb_file_manager/config/languages/app_localizations.dart';
```

### 2. Access Localized Strings
```dart
// Get localizations instance
final localizations = AppLocalizations.of(context)!;

// Use localized strings
Text(localizations.tabManager)
tooltip: localizations.close
label: localizations.addNewTab
```

### 3. Adding New Localization Keys

When you need to add new user-facing text, follow these steps:

#### Step 1: Add Abstract Property in `app_localizations.dart`
```dart
abstract class AppLocalizations {
  // ... existing properties
  
  // Tab manager
  String get tabManager;
  String get closeAllTabs;
  String get addNewTab;
}
```

#### Step 2: Add English Implementation in `english_localizations.dart`
```dart
class EnglishLocalizations implements AppLocalizations {
  // ... existing implementations
  
  @override
  String get tabManager => 'Tab Manager';
  
  @override
  String get closeAllTabs => 'Close All Tabs';
  
  @override
  String get addNewTab => 'Add new tab';
}
```

#### Step 3: Add Vietnamese Implementation in `vietnamese_localizations.dart`
```dart
class VietnameseLocalizations implements AppLocalizations {
  // ... existing implementations
  
  @override
  String get tabManager => 'Quản lý Tab';
  
  @override
  String get closeAllTabs => 'Đóng tất cả Tab';
  
  @override
  String get addNewTab => 'Thêm tab mới';
}
```

## Examples

### ❌ WRONG - Hardcoded Strings
```dart
// DON'T DO THIS
Text('Tab Manager')
tooltip: 'Close tab'
label: 'Add new tab'
AppBar(title: Text('Settings'))
```

### ✅ CORRECT - Using i18n
```dart
// DO THIS
final localizations = AppLocalizations.of(context)!;

Text(localizations.tabManager)
tooltip: localizations.closeTab
label: localizations.addNewTab
AppBar(title: Text(localizations.settings))
```

### ✅ CORRECT - With Parameters
For strings with dynamic content, use methods with parameters:

```dart
// In app_localizations.dart
String noFilesFoundTag(Map<String, String> args);

// In english_localizations.dart
@override
String noFilesFoundTag(Map<String, String> args) =>
    'No files found with tag "${args['tag']}"';

// In vietnamese_localizations.dart
@override
String noFilesFoundTag(Map<String, String> args) =>
    'Không tìm thấy tệp nào có tag "${args['tag']}"';

// Usage
Text(localizations.noFilesFoundTag({'tag': tagName}))
```

## Common UI Elements

### Buttons
```dart
ElevatedButton(
  onPressed: () {},
  child: Text(localizations.save),
)

TextButton(
  onPressed: () {},
  child: Text(localizations.cancel),
)

IconButton(
  icon: Icon(Icons.close),
  tooltip: localizations.close,
  onPressed: () {},
)
```

### Dialogs
```dart
AlertDialog(
  title: Text(localizations.deleteTagConfirmation),
  content: Text(localizations.tagDeleteConfirmationText),
  actions: [
    TextButton(
      onPressed: () => Navigator.pop(context),
      child: Text(localizations.cancel),
    ),
    TextButton(
      onPressed: () {},
      child: Text(localizations.delete),
    ),
  ],
)
```

### AppBar
```dart
AppBar(
  title: Text(localizations.tabManager),
  actions: [
    IconButton(
      icon: Icon(Icons.search),
      tooltip: localizations.search,
      onPressed: () {},
    ),
  ],
)
```

### Empty States
```dart
Center(
  child: Column(
    children: [
      Icon(Icons.folder_open, size: 64),
      SizedBox(height: 16),
      Text(
        localizations.noTabsOpen,
        style: TextStyle(fontSize: 20),
      ),
      SizedBox(height: 8),
      Text(
        localizations.openNewTabToStart,
        style: TextStyle(fontSize: 14),
      ),
    ],
  ),
)
```

## File Locations

- **Abstract definitions**: `lib/config/languages/app_localizations.dart`
- **English translations**: `lib/config/languages/english_localizations.dart`
- **Vietnamese translations**: `lib/config/languages/vietnamese_localizations.dart`

## Testing Checklist

Before submitting code, verify:

- [ ] No hardcoded user-facing strings in UI code
- [ ] All new strings added to all three localization files
- [ ] Translations are accurate and natural
- [ ] App works correctly in both English and Vietnamese
- [ ] Tooltips, labels, and error messages are localized

## Reference Examples

Good examples of i18n implementation:
- `lib/ui/screens/gallery_hub/gallery_hub_screen.dart`
- `lib/ui/screens/video_hub/video_hub_screen.dart`
- `lib/ui/tab_manager/mobile/mobile_tab_view.dart`

## Common Mistakes to Avoid

1. **Forgetting to import AppLocalizations**
   ```dart
   // Missing import will cause compilation error
   import 'package:cb_file_manager/config/languages/app_localizations.dart';
   ```

2. **Using hardcoded strings in debug/development**
   - Even temporary strings should use i18n
   - Add them to localization files immediately

3. **Inconsistent key naming**
   - Use camelCase for keys: `tabManager`, `closeAllTabs`
   - Be descriptive: `addNewTab` not just `add`

4. **Not updating all language files**
   - Always update English AND Vietnamese
   - Missing translations will cause runtime errors

## Best Practices

1. **Group related strings** in the localization files
2. **Use descriptive key names** that indicate context
3. **Keep translations concise** for UI elements
4. **Test both languages** before committing
5. **Document complex string parameters** in comments

## Support

For questions or issues with i18n:
- Check existing localization files for patterns
- Review reference examples in the codebase
- Ensure all three files are synchronized
