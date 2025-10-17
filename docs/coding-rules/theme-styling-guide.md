# Theme & Styling Guide

## Overview
CoolBird FM Flutter app follows strict theming rules to ensure consistent UI across the application. All UI components must use the theme system - **no hardcoded colors, sizes, or styles**.

## Core Principles

### 1. Use Theme Colors
**NEVER** hardcode colors. Always use `theme.colorScheme.*`

### 2. Use Semantic Spacing
Use consistent spacing values, not arbitrary numbers.

### 3. Use Remix Icons
Prefer Remix Icons with `_line` suffix for consistency.

### 4. Follow Material Design 3
Leverage Material 3 color system and components.

### 5. Flat Design - No Borders, No Shadows
**Use flat design.** Avoid borders and shadows. Use backgrounds, gradients, and spacing for visual separation. Keep the design clean and minimal.

## Color System

### ❌ WRONG - Hardcoded Colors
```dart
// DON'T DO THIS
Container(
  color: Colors.blue,
  child: Text(
    'Hello',
    style: TextStyle(color: Colors.white),
  ),
)

Icon(Icons.close, color: Colors.red)
border: Border.all(color: Color(0xFF123456))
```

### ✅ CORRECT - Using Theme Colors
```dart
// DO THIS
final theme = Theme.of(context);

Container(
  color: theme.colorScheme.primary,
  child: Text(
    'Hello',
    style: TextStyle(color: theme.colorScheme.onPrimary),
  ),
)

Icon(Icons.close, color: theme.colorScheme.error)
border: Border.all(color: theme.dividerColor)
```

### Common Theme Colors

```dart
final theme = Theme.of(context);

// Primary colors
theme.colorScheme.primary          // Main brand color
theme.colorScheme.onPrimary        // Text on primary
theme.colorScheme.primaryContainer // Lighter primary variant
theme.colorScheme.onPrimaryContainer

// Surface colors
theme.colorScheme.surface          // Card/surface background
theme.colorScheme.onSurface        // Text on surface
theme.colorScheme.surfaceVariant   // Subtle surface variant
theme.colorScheme.onSurfaceVariant // Text on surface variant

// Background
theme.scaffoldBackgroundColor      // Screen background
theme.cardColor                    // Card background

// Semantic colors
theme.colorScheme.error            // Error/danger
theme.colorScheme.onError          // Text on error
theme.dividerColor                 // Dividers and borders
theme.shadowColor                  // Shadows

// Icon colors
theme.iconTheme.color              // Default icon color
```

### Opacity Usage
```dart
// Use standard opacity values
theme.colorScheme.onSurface.withOpacity(0.3)  // Very subtle
theme.colorScheme.onSurface.withOpacity(0.5)  // Subtle
theme.colorScheme.onSurface.withOpacity(0.7)  // Medium
```

## Spacing System

### Standard Spacing Values
Use these consistent spacing values:

```dart
// Spacing constants
const spacing4 = 4.0;
const spacing8 = 8.0;
const spacing12 = 12.0;
const spacing16 = 16.0;
const spacing20 = 20.0;
const spacing24 = 24.0;

// Usage
SizedBox(height: 16)
padding: EdgeInsets.all(16.0)
EdgeInsets.symmetric(horizontal: 16, vertical: 12)
```

### ❌ WRONG - Arbitrary Spacing
```dart
// DON'T DO THIS
SizedBox(height: 15)
padding: EdgeInsets.all(13.0)
margin: EdgeInsets.only(left: 7, top: 23)
```

### ✅ CORRECT - Semantic Spacing
```dart
// DO THIS
SizedBox(height: 16)
padding: EdgeInsets.all(16.0)
margin: EdgeInsets.only(left: 8, top: 24)

// For grids/lists
crossAxisSpacing: 16
mainAxisSpacing: 16
```

## Border Radius

### Standard Radius Values
```dart
// Border radius constants
const radius12 = 12.0;
const radius16 = 16.0;
const radius20 = 20.0;
const radius24 = 24.0;

// Usage
BorderRadius.circular(16)
borderRadius: BorderRadius.circular(12)
```

### ❌ WRONG
```dart
BorderRadius.circular(13)
BorderRadius.circular(27)
```

### ✅ CORRECT
```dart
BorderRadius.circular(12)
BorderRadius.circular(16)
BorderRadius.circular(20)
```

## Flat Design Philosophy

### No Borders, No Shadows
**Philosophy:** Use flat design with backgrounds, gradients, and spacing for visual separation. Avoid borders and shadows as they add visual noise and make the UI feel cluttered.

### ❌ WRONG - Excessive Borders
```dart
// DON'T DO THIS - Too many borders
Container(
  decoration: BoxDecoration(
    color: theme.cardColor,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(
      color: theme.dividerColor,
      width: 1.0,
    ),
  ),
  child: Container(
    decoration: BoxDecoration(
      color: theme.surfaceVariant,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: theme.dividerColor,
        width: 1.0,
      ),
    ),
  ),
)
```

### ✅ CORRECT - Flat Design with Backgrounds
```dart
// DO THIS - Clean, flat design
Container(
  decoration: BoxDecoration(
    color: theme.cardColor,
    borderRadius: BorderRadius.circular(16),
  ),
  child: Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [
          theme.colorScheme.surfaceVariant.withOpacity(0.3),
          theme.colorScheme.surfaceVariant.withOpacity(0.15),
        ],
      ),
      borderRadius: BorderRadius.circular(12),
    ),
  ),
)
```

### Visual Separation Techniques
Use these instead of borders and shadows:
1. **Background colors**: Different colors for grouping
2. **Gradients**: For visual interest and depth
3. **Spacing**: Adequate padding and margins
4. **Opacity**: Subtle background opacity differences
5. **Color contrast**: Use theme colors effectively

### Exceptions (Use Sparingly)
Only use borders/shadows when absolutely necessary:
1. **Input fields** - To clearly indicate editable areas
2. **Focus states** - To show keyboard focus
3. **Dividers** - Use `Divider` widget for separation

## Icon System

### Use Remix Icons with `_line` Suffix
```dart
import 'package:remixicon/remixicon.dart' as remix;

// ✅ CORRECT - Use _line icons
Icon(remix.Remix.close_line)
Icon(remix.Remix.add_line)
Icon(remix.Remix.folder_3_line)
Icon(remix.Remix.file_list_2_line)

// ❌ WRONG - Don't use _fill unless specifically needed
Icon(remix.Remix.close_fill)
Icon(remix.Remix.folder_3_fill)
```

### Icon Sizes
```dart
// Standard icon sizes
const iconSmall = 18.0;
const iconMedium = 22.0;
const iconLarge = 24.0;
const iconXLarge = 48.0;

// Usage
Icon(remix.Remix.close_line, size: 20)
Icon(remix.Remix.folder_3_line, size: 22)
Icon(remix.Remix.file_list_2_line, size: 48)
```

## Typography

### Using Theme Text Styles
```dart
final theme = Theme.of(context);

// Headlines
Text(
  'Title',
  style: TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: theme.colorScheme.onSurface,
  ),
)

// Body text
Text(
  'Description',
  style: TextStyle(
    fontSize: 14,
    color: theme.colorScheme.onSurfaceVariant,
  ),
)

// Subtle text
Text(
  'Path',
  style: TextStyle(
    fontSize: 13,
    color: theme.colorScheme.onSurfaceVariant,
    height: 1.3,
  ),
)
```

### Font Weights
```dart
FontWeight.w400  // Regular (normal)
FontWeight.w500  // Medium
FontWeight.w600  // Semi-bold
FontWeight.w700  // Bold
```

## Common UI Patterns

### Card Design (Flat)
```dart
// Clean, flat card design
Container(
  decoration: BoxDecoration(
    color: theme.cardColor,
    borderRadius: BorderRadius.circular(16),
  ),
  padding: const EdgeInsets.all(16.0),
  child: // ... content
)
```

### Active/Selected State (Flat)
```dart
final isActive = true;

Container(
  decoration: BoxDecoration(
    gradient: isActive
        ? LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.colorScheme.primaryContainer.withOpacity(0.4),
              theme.colorScheme.primaryContainer.withOpacity(0.2),
            ],
          )
        : null,
    color: isActive ? null : theme.cardColor,
    borderRadius: BorderRadius.circular(16),
  ),
)
```

### Button Styles

#### Icon Button
```dart
IconButton(
  icon: Icon(
    remix.Remix.close_line,
    color: theme.colorScheme.onSurface,
  ),
  tooltip: localizations.close,
  onPressed: () {},
)
```

#### Text Button
```dart
TextButton.icon(
  icon: Icon(
    remix.Remix.close_circle_line,
    color: theme.colorScheme.error,
    size: 20,
  ),
  label: Text(
    localizations.closeAllTabs,
    style: TextStyle(
      color: theme.colorScheme.error,
      fontWeight: FontWeight.w600,
    ),
  ),
  onPressed: () {},
)
```

#### Floating Action Button
```dart
FloatingActionButton.extended(
  onPressed: () {},
  icon: const Icon(remix.Remix.add_line),
  label: Text(localizations.addNewTab),
  backgroundColor: theme.colorScheme.primary,
)
```

### Touch Targets
Ensure buttons and interactive elements have adequate touch targets (minimum 48x48 dp):

```dart
// ✅ CORRECT - Larger touch target
Material(
  color: theme.colorScheme.error.withOpacity(0.1),
  borderRadius: BorderRadius.circular(20),
  child: InkWell(
    borderRadius: BorderRadius.circular(20),
    onTap: () {},
    child: Padding(
      padding: const EdgeInsets.all(8.0),  // Makes it easier to tap
      child: Icon(
        remix.Remix.close_line,
        size: 20,
        color: theme.colorScheme.error,
      ),
    ),
  ),
)
```

## AppBar Styling

```dart
AppBar(
  elevation: 0,
  backgroundColor: theme.scaffoldBackgroundColor,
  leading: IconButton(
    icon: Icon(
      remix.Remix.close_line,
      color: theme.colorScheme.onSurface,
    ),
    tooltip: localizations.close,
    onPressed: () {},
  ),
  title: Text(
    localizations.tabManager,
    style: TextStyle(
      color: theme.colorScheme.onSurface,
      fontSize: 20,
      fontWeight: FontWeight.w600,
    ),
  ),
)
```

## Grid Layouts

```dart
GridView.builder(
  padding: const EdgeInsets.all(16.0),
  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: 2,
    crossAxisSpacing: 16,
    mainAxisSpacing: 16,
    childAspectRatio: 0.85,
  ),
  itemBuilder: (context, index) {
    // ... item builder
  },
)
```

## Responsive Design

```dart
LayoutBuilder(
  builder: (context, constraints) {
    final width = constraints.maxWidth;
    int crossAxisCount = 2;
    if (width >= 600) crossAxisCount = 3;
    if (width >= 900) crossAxisCount = 4;
    
    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        // ...
      ),
    );
  },
)
```

## Dark Mode Support

All theme colors automatically support dark mode:

```dart
// This works in both light and dark mode
Container(
  color: theme.scaffoldBackgroundColor,
  child: Text(
    'Hello',
    style: TextStyle(color: theme.colorScheme.onSurface),
  ),
)
```

## Testing Checklist

Before submitting code:

- [ ] No hardcoded colors (no `Colors.blue`, `Color(0xFF...)`)
- [ ] No arbitrary spacing values (use 4, 8, 12, 16, 20, 24)
- [ ] No arbitrary border radius (use 12, 16, 20, 24)
- [ ] Using Remix Icons with `_line` suffix
- [ ] All text uses theme colors
- [ ] Touch targets are at least 48x48 dp
- [ ] UI works in both light and dark mode
- [ ] Consistent spacing throughout

## Reference Examples

Good examples of theme usage:
- `lib/ui/tab_manager/mobile/mobile_tab_view.dart`
- `lib/ui/screens/gallery_hub/gallery_hub_screen.dart`
- `lib/ui/screens/video_hub/video_hub_screen.dart`

## Common Mistakes to Avoid

1. **Hardcoding colors**
   ```dart
   // ❌ WRONG
   color: Colors.blue
   
   // ✅ CORRECT
   color: theme.colorScheme.primary
   ```

2. **Inconsistent spacing**
   ```dart
   // ❌ WRONG
   padding: EdgeInsets.all(13.0)
   
   // ✅ CORRECT
   padding: EdgeInsets.all(16.0)
   ```

3. **Using fill icons**
   ```dart
   // ❌ WRONG
   Icon(remix.Remix.close_fill)
   
   // ✅ CORRECT
   Icon(remix.Remix.close_line)
   ```

4. **Small touch targets**
   ```dart
   // ❌ WRONG
   IconButton(
     padding: EdgeInsets.zero,
     constraints: BoxConstraints(),
     icon: Icon(Icons.close, size: 12),
   )
   
   // ✅ CORRECT
   IconButton(
     icon: Icon(remix.Remix.close_line, size: 20),
     padding: EdgeInsets.all(8.0),
   )
   ```

## Best Practices

1. **Always get theme at the start of build method**
   ```dart
   @override
   Widget build(BuildContext context) {
     final theme = Theme.of(context);
     // ... use theme throughout
   }
   ```

2. **Use semantic color names**
   - `primary` for main actions
   - `error` for destructive actions
   - `onSurface` for primary text
   - `onSurfaceVariant` for secondary text

3. **Maintain visual hierarchy**
   - Use font size and weight to establish hierarchy
   - Use opacity for less important elements
   - Use color to highlight important actions

4. **Be consistent**
   - Same spacing for similar elements
   - Same border radius for cards
   - Same icon sizes for similar contexts
