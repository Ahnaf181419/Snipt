# Snipt - Clipboard Manager

## 1. Project Overview

**App Name:** Snipt  
**Platform:** Android (Flutter)  
**Type:** Clipboard Manager  
**Core Functionality:** Auto-capture clipboard content (text + images), manage with bookmarks, 50-item limit with auto-cleanup

---

## 2. Feature Specification

### Core Features (Priority 1)

| # | Feature | Description |
|---|---------|-------------|
| 1 | Auto-capture | Automatically save clipboard content when copied |
| 2 | Content types | Support text and images |
| 3 | Recent list | Show last 50 copied items (configurable, default 50) |
| 4 | Auto-cleanup | Delete oldest non-bookmarked when limit reached |
| 5 | Bookmarks | Separate permanent container for starred items |
| 6 | Quick copy | Tap item to copy back to clipboard |
| 7 | Background capture | Run in background to capture clipboard |
| 8 | Toggle setting | Enable/disable background capture in settings |

### Additional Features (Priority 2)

| # | Feature | Description |
|---|---------|-------------|
| 9 | Search | Full-text search across all text items |
| 10 | Swipe actions | Swipe left=delete, swipe right=bookmark |
| 11 | Favorites tray | Horizontal scrollable tray with top 5 recent |
| 12 | Auto-categories | Auto-detect URLs, phone numbers, addresses |
| 13 | Undo delete | Soft delete with 24-hour recovery |
| 14 | Export | Backup clipboard data to JSON file |

---

## 3. Technical Stack

| Category | Choice |
|----------|--------|
| Framework | Flutter 3.x |
| Language | Dart 3.x |
| Min SDK | Android 5.0 (API 21) |
| State Management | flutter_bloc |
| Local Database | sqflite |
| File Storage | path_provider |
| Background Service | flutter_background_service |
| Permissions | permission_handler |

### Key Dependencies
```yaml
dependencies:
  flutter_bloc: ^8.1.3
  sqflite: ^2.3.0
  path_provider: ^2.1.1
  flutter_background_service: ^5.0.5
  permission_handler: ^11.1.0
  share_plus: ^7.2.1
  equatable: ^2.0.5
  intl: ^0.18.1
```

---

## 4. UI/UX Design

### Theme
- **Mode:** Dark only
- **Background:** #121212 (primary), #1E1E1E (cards)
- **Accent:** #7C4DFF (deep purple)
- **Text:** #FFFFFF (primary), #B3B3B3 (secondary)
- **Success:** #4CAF50
- **Error:** #FF5252

### Screen Structure

```
App Structure:
├── HomeScreen
│   ├── AppBar (Snipt logo + settings icon)
│   ├── SearchBar
│   ├── FavoritesTray (horizontal, top 5 items)
│   └── RecentList (swipeable cards)
├── BookmarksScreen
│   ├── AppBar
│   └── BookmarkedList
└── SettingsScreen
    ├── ListTile: Background Capture (switch)
    ├── ListTile: Storage Limit (slider 10-100)
    ├── ListTile: Export Data
    └── ListTile: Clear All Data
```

### Navigation
- Bottom Navigation Bar with 3 tabs: Home, Bookmarks, Settings

### Item Card Design
```
┌─────────────────────────────────┐
│ [Icon] Content Preview...       │
│          Timestamp    [★]      │
└─────────────────────────────────┘
```
- Text: Max 2 lines, ellipsis overflow
- Image: Thumbnail 60x60, rounded corners
- Category badge: URL, Phone, Image, Text

---

## 5. Database Schema

### Table: clipboard_items
| Column | Type | Description |
|--------|------|-------------|
| id | INTEGER PRIMARY KEY | Auto-increment ID |
| content | TEXT | Text content or image path |
| content_type | TEXT | 'text', 'image', 'url', 'phone' |
| is_image | INTEGER | 0 or 1 |
| is_bookmarked | INTEGER | 0 or 1 |
| is_deleted | INTEGER | 0 or 1 (soft delete) |
| category | TEXT | 'text', 'url', 'phone', 'image' |
| created_at | INTEGER | Unix timestamp |
| updated_at | INTEGER | Unix timestamp |

---

## 6. Architecture (Clean Architecture)

```
lib/
├── main.dart
├── app.dart
├── core/
│   ├── constants/
│   │   ├── app_colors.dart
│   │   └── app_strings.dart
│   ├── theme/
│   │   └── app_theme.dart
│   └── utils/
│       └── date_formatter.dart
├── data/
│   ├── datasources/
│   │   └── local_database.dart
│   ├── models/
│   │   └── clipboard_item_model.dart
│   └── repositories/
│       └── clipboard_repository_impl.dart
├── domain/
│   ├── entities/
│   │   └── clipboard_item.dart
│   ├── repositories/
│   │   └── clipboard_repository.dart
│   └── usecases/
│       ├── add_clipboard_item.dart
│       ├── delete_clipboard_item.dart
│       ├── get_clipboard_items.dart
│       └── toggle_bookmark.dart
├── presentation/
│   ├── bloc/
│   │   ├── clipboard/
│   │   │   ├── clipboard_bloc.dart
│   │   │   ├── clipboard_event.dart
│   │   │   └── clipboard_state.dart
│   │   └── settings/
│   │       ├── settings_bloc.dart
│   │       ├── settings_event.dart
│   │       └── settings_state.dart
│   ├── screens/
│   │   ├── home_screen.dart
│   │   ├── bookmarks_screen.dart
│   │   └── settings_screen.dart
│   └── widgets/
│       ├── clipboard_item_card.dart
│       ├── favorites_tray.dart
│       └── search_bar.dart
└── services/
    └── clipboard_service.dart
```

---

## 7. Background Service Logic

### Development Mode
- Use `flutter_background_service` with foreground notification
- Notification: "Snipt is running" (can be hidden in release)

### Release Mode
- Explore: Use WorkManager for periodic checks
- Alternative: Manual clipboard check when app opens

### Settings Integration
- Toggle in SettingsScreen enables/disables background service
- Service restarts when toggle changes

---

## 8. Non-Functional Requirements

- **Performance:** App opens in < 2 seconds
- **Storage:** Images stored in app documents directory
- **Battery:** Background service uses minimal battery
- **Compatibility:** Android 5.0+ (covers 99% devices)
