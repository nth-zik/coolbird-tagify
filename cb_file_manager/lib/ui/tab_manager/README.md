# Tab Manager Module Structure

Thư mục `tab_manager` đã được tổ chức lại để dễ hiểu và bảo trì hơn.

## 📁 Cấu trúc thư mục

```
tab_manager/
├── core/                    # Core functionality
│   ├── tab_manager.dart     # Main BLoC for tab management
│   ├── tab_data.dart        # Data models for tabs
│   ├── tab_screen.dart      # Base tab screen widget
│   ├── tab_main_screen.dart # Main screen with tab interface
│   ├── tabbed_folder_list_screen.dart # Folder list with tabs
│   └── index.dart          # Core exports
├── mobile/                  # Mobile-specific components
│   ├── mobile_tab_view.dart # Chrome-style mobile tab view
│   └── index.dart          # Mobile exports
├── desktop/                 # Desktop-specific components
│   ├── tab_view.dart       # Desktop tab view
│   ├── scrollable_tab_bar.dart # Scrollable tab bar
│   └── index.dart          # Desktop exports
├── shared/                  # Shared utilities
│   ├── screen_menu_registry.dart # Dynamic menu system
│   └── index.dart          # Shared exports
├── components/              # Reusable UI components
│   ├── address_bar_menu.dart
│   ├── drive_view.dart
│   ├── error_view.dart
│   ├── folder_context_menu.dart
│   ├── navigation_bar.dart
│   ├── path_navigation_bar.dart
│   ├── search_bar.dart
│   ├── search_results.dart
│   ├── selection_app_bar.dart
│   ├── tag_dialogs.dart
│   ├── tag_search_dialog.dart
│   └── index.dart
└── index.dart              # Main exports
```

## 🎯 Mục đích từng thư mục

### `core/`

Chứa các thành phần cốt lõi của hệ thống tab:

- **tab_manager.dart**: BLoC chính quản lý state của tabs
- **tab_data.dart**: Data models cho TabData
- **tab_screen.dart**: Widget cơ sở cho tab screen
- **tab_main_screen.dart**: Màn hình chính với giao diện tab
- **tabbed_folder_list_screen.dart**: Màn hình danh sách thư mục với tabs

### `mobile/`

Chứa các thành phần dành riêng cho mobile:

- **mobile_tab_view.dart**: Giao diện tab kiểu Chrome cho mobile

### `desktop/`

Chứa các thành phần dành riêng cho desktop:

- **tab_view.dart**: Giao diện tab cho desktop
- **scrollable_tab_bar.dart**: Thanh tab có thể cuộn

### `shared/`

Chứa các utilities được chia sẻ:

- **screen_menu_registry.dart**: Hệ thống dynamic menu cho các màn hình khác nhau

### `components/`

Chứa các UI components có thể tái sử dụng:

- Các dialog, menu, bar components
- Các widget UI phụ trợ

## 📦 Cách sử dụng

### Import toàn bộ module:

```dart
import 'package:cb_file_manager/ui/tab_manager/index.dart';
```

### Import theo chức năng:

```dart
// Core functionality
import 'package:cb_file_manager/ui/tab_manager/core/index.dart';

// Mobile components
import 'package:cb_file_manager/ui/tab_manager/mobile/index.dart';

// Desktop components
import 'package:cb_file_manager/ui/tab_manager/desktop/index.dart';

// Shared utilities
import 'package:cb_file_manager/ui/tab_manager/shared/index.dart';
```

### Import component cụ thể:

```dart
import 'package:cb_file_manager/ui/tab_manager/core/tab_manager.dart';
import 'package:cb_file_manager/ui/tab_manager/mobile/mobile_tab_view.dart';
```

## 🔄 Migration Notes

Tất cả các import cũ đã được cập nhật để sử dụng cấu trúc mới:

- `tab_manager.dart` → `core/tab_manager.dart`
- `tab_data.dart` → `core/tab_data.dart`
- `mobile_tab_view.dart` → `mobile/mobile_tab_view.dart`
- `screen_menu_registry.dart` → `shared/screen_menu_registry.dart`

## 🚀 Lợi ích

1. **Tổ chức rõ ràng**: Mỗi thư mục có mục đích cụ thể
2. **Dễ bảo trì**: Code được nhóm theo chức năng
3. **Tái sử dụng**: Components được tách riêng
4. **Mở rộng**: Dễ dàng thêm tính năng mới
5. **Import rõ ràng**: Biết ngay component thuộc loại nào
