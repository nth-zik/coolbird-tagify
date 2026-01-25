# Unified Skeleton Loading System

**Purpose**: Consistent skeleton loading UI across all platforms (mobile, desktop, web) for files, albums, videos, and thumbnails.

## Overview

The unified skeleton system provides a single, consistent loading experience that automatically adapts to mobile and desktop platforms.

## Components

### Core Components

- **Skeleton** (`lib/ui/components/common/skeleton.dart`) - Base skeleton component with platform detection
- **SkeletonHelper** (`lib/ui/components/common/skeleton_helper.dart`) - Convenience helpers for common use cases
- **ShimmerBox** - Public shimmer box component for custom skeleton layouts

### Skeleton Types

```dart
enum SkeletonType {
  single,           // Single skeleton box for thumbnails, images
  list,             // List view skeleton for files/albums
  grid,             // Grid view skeleton for files/albums
  albumGrid,        // Album grid layout
  albumList,        // Album list layout
  videoThumbnail,   // Video thumbnail skeleton
  masonry,          // Masonry grid layout (Pinterest-style)
}
```

## Quick Start

### File List Skeleton

```dart
SkeletonHelper.fileList(
  itemCount: 12,
  wrapInCardOnDesktop: true, // Desktop gets Card wrapper
)
```

### File Grid Skeleton

```dart
SkeletonHelper.fileGrid(
  crossAxisCount: 3,
  itemCount: 12,
)
```

### Responsive Skeleton (Grid/List)

```dart
SkeletonHelper.responsive(
  isGridView: _isGridView,
  isAlbum: false,
  crossAxisCount: _gridZoomLevel,
  itemCount: 12,
  wrapInCardOnDesktop: true,
)
```

### Video Thumbnail Skeleton

```dart
SkeletonHelper.videoThumbnail(
  width: 200,
  height: 150,
  borderRadius: BorderRadius.circular(8),
)
```

### Single Box Skeleton

```dart
SkeletonHelper.box(
  width: 100,
  height: 100,
  borderRadius: BorderRadius.circular(12),
)
```

### Media Gallery Skeleton

```dart
SkeletonHelper.mediaGallery(
  isGrid: _isGridView,
  crossAxisCount: 3,
  itemCount: 12,
)
```

### Masonry Skeleton (Pinterest-style)

```dart
SkeletonHelper.masonry(
  crossAxisCount: 3,
  itemCount: 12,
)
```

## Platform Behavior

### Mobile (Android/iOS)
- **List view**: Flat design, no Card wrapper
- **Grid view**: Consistent with desktop
- **Thumbnails**: Rounded corners, shimmer animation

### Desktop (Windows/macOS/Linux)
- **List view**: Wrapped in Card with elevation (when `wrapInCardOnDesktop: true`)
- **Grid view**: Same as mobile
- **Thumbnails**: Same as mobile

### Web
- Treated as desktop platform
- Card wrappers enabled by default

## Design Specifications

### List Skeleton
- **Thumbnail size**: 56x56 pixels
- **Border radius**: 16px (thumbnail), 12px (container)
- **Spacing**: 16px horizontal, 4px vertical margin
- **Animation**: Staggered delay (80ms per item, max 800ms)
- **Desktop Card**: 1px elevation, 8px horizontal margin

### Grid Skeleton
- **Aspect ratio**: 1.0 (square)
- **Border radius**: 16px (container), 12px (thumbnail)
- **Spacing**: 8px grid spacing
- **Animation**: Staggered delay (60ms per item, max 600ms)

### Shimmer Animation
- **Duration**: 1600ms
- **Curve**: Linear gradient sweep
- **Colors**:
  - Dark mode: Base (35% alpha) → Highlight (10% alpha)
  - Light mode: Base (60% alpha) → Highlight (80% alpha)
- **Delay support**: Staggered animation for list items

## Usage Guidelines

### DO ✅
- Use `SkeletonHelper` methods for consistency
- Show skeleton matching the content layout (grid for grid view, list for list view)
- Use `wrapInCardOnDesktop: true` for list views on desktop
- Set appropriate `itemCount` (12 for grids, 10 for lists)
- Use `videoThumbnail()` for video loading states

### DON'T ❌
- Create custom skeleton implementations
- Mix different skeleton styles in the same screen
- Forget to set loading state to `false` after data loads
- Show skeleton without matching content structure
- Use deprecated `LoadingSkeleton` or custom implementations

## Migration from Old Skeleton

### Before (Deprecated)
```dart
// ❌ Old way - LoadingSkeleton
LoadingSkeleton.list(itemCount: 12)
LoadingSkeleton.grid(crossAxisCount: 3, itemCount: 12)

// ❌ Old way - GallerySkeleton
GallerySkeleton(isGrid: true, thumbnailSize: 3.0)

// ❌ Old way - Custom implementation
Container(
  width: width,
  height: height,
  decoration: BoxDecoration(
    color: Colors.grey.withValues(alpha: 0.2),
    borderRadius: BorderRadius.circular(4),
  ),
)
```

### After (Unified)
```dart
// ✅ New way - SkeletonHelper
SkeletonHelper.fileList(itemCount: 12)
SkeletonHelper.fileGrid(crossAxisCount: 3, itemCount: 12)

// ✅ New way - Media gallery
SkeletonHelper.mediaGallery(isGrid: true, crossAxisCount: 3)

// ✅ New way - ShimmerBox for custom layouts
ShimmerBox(
  width: width,
  height: height,
  borderRadius: BorderRadius.circular(8),
)
```

## Advanced Usage

### Custom Skeleton Layout

If you need a custom skeleton layout not covered by `SkeletonHelper`, use the public `ShimmerBox`:

```dart
Row(
  children: [
    ShimmerBox(
      width: 60,
      height: 60,
      borderRadius: BorderRadius.circular(12),
    ),
    const SizedBox(width: 16),
    Expanded(
      child: Column(
        children: [
          ShimmerBox(
            width: double.infinity,
            height: 16,
            borderRadius: BorderRadius.circular(8),
          ),
          const SizedBox(height: 8),
          ShimmerBox(
            width: 120,
            height: 14,
            borderRadius: BorderRadius.circular(8),
          ),
        ],
      ),
    ),
  ],
)
```

### Direct Skeleton Component

For maximum control, use the `Skeleton` component directly:

```dart
Skeleton(
  type: SkeletonType.list,
  itemCount: 12,
  isAlbum: true,
  wrapInCardOnDesktop: true,
)
```

## Performance Considerations

- **Cache extent**: GridView uses `cacheExtent: 800`, ListView uses `500`
- **RepaintBoundary**: Each skeleton item is wrapped for optimal performance
- **Animation controller sharing**: List items share animation controller to reduce overhead
- **Staggered delays**: Limited to max 800-920ms to prevent excessive delays

## Testing

### Test on All Platforms
```bash
# Mobile
flutter run -d android
flutter run -d ios

# Desktop
flutter run -d windows
flutter run -d macos
flutter run -d linux

# Web
flutter run -d chrome
```

### Test Scenarios
- Grid view with different zoom levels
- List view on mobile vs desktop
- Dark mode vs light mode
- Slow network loading
- Empty state transitions
- View mode switching (grid ↔ list)

## Common Patterns

### Folder List Screen
```dart
body: _isLoading
    ? SkeletonHelper.responsive(
        isGridView: _isGridView,
        isAlbum: false,
        crossAxisCount: _gridZoomLevel,
        itemCount: 12,
      )
    : _buildContent(),
```

### Album Management Screen
```dart
body: _isLoading
    ? SkeletonHelper.responsive(
        isGridView: _isGridView,
        isAlbum: true,
        crossAxisCount: 3,
        itemCount: 12,
      )
    : _buildAlbumList(),
```

### Thumbnail Loading
```dart
FutureBuilder(
  future: loadThumbnail(),
  builder: (context, snapshot) {
    if (snapshot.connectionState != ConnectionState.done) {
      return SkeletonHelper.box(
        width: double.infinity,
        height: double.infinity,
        borderRadius: BorderRadius.circular(8),
      );
    }
    return Image.file(snapshot.data);
  },
)
```

## Troubleshooting

### Skeleton not showing on desktop
- Check if `wrapInCardOnDesktop: false` is set (should be `true` for list views)
- Verify platform detection is working (`Platform.isAndroid || Platform.isIOS`)

### Animation performance issues
- Ensure using `RepaintBoundary` around skeleton items
- Check if animation controller is properly disposed
- Reduce `itemCount` if too many items are rendering

### Inconsistent appearance
- Always use `SkeletonHelper` methods instead of custom implementations
- Check theme's `colorScheme.surfaceContainerHighest` for proper colors
- Verify `borderRadius` consistency across skeleton types

## Reference Implementations

### Network Browser
`lib/ui/screens/network_browsing/network_browser_screen.dart:662-674`

### Album Management
`lib/ui/screens/album_management/album_management_screen.dart:302-307`

### Drive View
`lib/ui/tab_manager/components/drive_view.dart:56-60`

### Tabbed Folder List
`lib/ui/tab_manager/core/tabbed_folder/tabbed_folder_list_screen.dart:865-875`

## Related Documentation

- [File and Folder Listing UI Patterns](file-folder-listing.md) - General listing patterns
- [Skeleton Component](../../cb_file_manager/lib/ui/components/common/skeleton.dart) - Core component
- [Skeleton Helper](../../cb_file_manager/lib/ui/components/common/skeleton_helper.dart) - Helper methods
