# Snipt Architecture

## Overview

Snipt is a clipboard manager app for Android built with Flutter, following clean architecture principles with the BLoC pattern for state management.

## Architecture Layers

### 1. Presentation Layer (`lib/presentation/`)
Responsible for UI rendering and user interaction handling.

**Components:**
- `screens/` - Full-page screens (Home, Bookmarks, Settings)
- `widgets/` - Reusable UI components (ClipboardItemCard, SearchBar, FavoritesTray)
- `bloc/` - State management (ClipboardBloc, SettingsBloc)

**Key Patterns:**
- BLoC pattern for reactive state management
- Repository pattern for data access abstraction
- Event-driven UI updates

### 2. Domain Layer (`lib/domain/`)
Contains business logic and entities, independent of external frameworks.

**Components:**
- `entities/` - Business objects (ClipboardItem)
- `repositories/` - Abstract repository interfaces
- `use_cases/` - Business logic implementations (DetectCategoryUseCase)

**Key Principles:**
- Dependency inversion (abstractions in domain, implementations in data)
- Single responsibility per use case
- Testable business logic without external dependencies

### 3. Data Layer (`lib/data/`)
Implements domain interfaces and handles data persistence.

**Components:**
- `datasources/` - Local SQLite database via sqflite
- `models/` - Data transfer objects with serialization
- `repositories/` - Concrete repository implementations

**Key Responsibilities:**
- SQLite database operations
- Data model serialization/deserialization
- Conflict resolution (duplicate detection via content hash)

### 4. Core Layer (`lib/core/`)
Shared utilities and constants.

**Components:**
- `constants/` - App-wide constants (colors, strings)
- `theme/` - Material Design theme configuration
- `utils/` - Helper utilities (date formatting)

### 5. Services Layer (`lib/services/`)
Background services running independent of the UI.

**Components:**
- `clipboard_service.dart` - Background clipboard monitoring using flutter_background_service

**Responsibilities:**
- Periodic clipboard checking (every 5 seconds)
- Cross-process communication with UI
- Android foreground service management

---

## State Management (BLoC Pattern)

### ClipboardBloc
Manages clipboard items state and operations.

**States:**
- `ClipboardState` - Immutable state with items, loading status, search state

**Events:**
- `LoadRecentItems` - Fetch recent clipboard items
- `LoadBookmarkedItems` - Fetch bookmarked items
- `AddClipboardItem` - Add new clipboard content
- `ToggleBookmark` - Toggle bookmark status
- `DeleteClipboardItem` - Delete an item
- `SoftDeleteClipboardItem` - Soft delete (swipe to delete)
- `RestoreClipboardItem` - Restore a deleted item
- `SearchItems` - Search with 300ms debounce
- `ClearSearch` - Clear search results
- `ClearAllItems` - Delete all items
- `UpdateStorageLimit` - Update max storage limit

**Error Handling:**
- All events set `status: error` in catch blocks
- Error message stored in state for UI display

### SettingsBloc
Manages app settings state.

**States:**
- `SettingsState` - Storage limit configuration

**Events:**
- `UpdateStorageLimitSetting` - Update storage limit preference

---

## Database Schema

### Table: `clipboard_items`

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | INTEGER | PRIMARY KEY AUTOINCREMENT | Unique identifier |
| `content` | TEXT | NOT NULL | Clipboard content |
| `content_type` | TEXT | NOT NULL | Content type (text/image) |
| `is_image` | INTEGER | DEFAULT 0 | Image flag (0/1) |
| `is_bookmarked` | INTEGER | DEFAULT 0 | Bookmark flag (0/1) |
| `is_deleted` | INTEGER | DEFAULT 0 | Soft delete flag (0/1) |
| `category` | TEXT | NOT NULL | Category (text/url/phone/image) |
| `content_hash` | TEXT | UNIQUE | SHA-256 hash for deduplication |
| `created_at` | INTEGER | NOT NULL | Unix timestamp |
| `updated_at` | INTEGER | NOT NULL | Unix timestamp |

**Indexes:**
- `idx_bookmarked_deleted` on (`is_bookmarked`, `is_deleted`)
- `idx_created_at` on (`created_at` DESC)
- `idx_content_hash` on (`content_hash`)

---

## Key Features Implementation

### Clipboard Monitoring
1. `ClipboardService` runs as Android foreground service
2. Timer checks clipboard every 5 seconds
3. On new content, invokes `clipboard_update` event
4. UI listens via `ClipboardService.onClipboardUpdate` stream
5. `ClipboardBloc` processes new content via `AddClipboardItem`

### Deduplication
1. Content hashed via SHA-256 before storage
2. UNIQUE constraint on `content_hash` prevents duplicates
3. `ConflictAlgorithm.replace` updates existing item on duplicate
4. `updated_at` timestamp updated for sorting purposes

### Search with Debouncing
1. User types in search bar
2. 300ms Timer delays search event
3. Previous timer cancelled on new input
4. SQL LIKE query with escaped wildcards (`%`, `_`, `\`)
5. Results update UI via BLoC state

### Storage Management
1. Configurable limit (10-100 items)
2. On `UpdateStorageLimit`, calculates excess
3. `deleteOldestNonBookmarked` removes oldest non-bookmarked items
4. Respects bookmarked items regardless of limit

### Bookmark Toggle (Atomic)
```sql
UPDATE clipboard_items 
SET is_bookmarked = NOT is_bookmarked, updated_at = ? 
WHERE id = ?
```
Single atomic operation prevents race conditions.

---

## Testing Strategy

### Unit Tests
- **BLoC Tests** (18 tests) - Event handling, state transitions, error cases
- **Repository Tests** (14 tests) - SQL generation, data mapping, edge cases

### Widget Tests
- **ClipboardItemCard Tests** (9 tests) - UI rendering, interactions
- **SearchBar Tests** (8 tests) - Input handling, clear functionality

### Integration Tests
- **App Tests** (12 tests) - Full user flows, navigation

**Total: 57 tests passing**

---

## Security Considerations

### Production Signing
- RSA-4096 keystore for release builds
- Keystore credentials stored as GitHub secrets
- R8 minification enabled for code obfuscation

### Data Protection
- Content stored locally only (no cloud sync)
- No PII sent to Sentry (`sendDefaultPii: false`)
- Export requires user action (Share sheet)

---

## Error Tracking (Sentry)

### Configuration
- DSN passed via `SENTRY_DSN` environment variable
- Environment set via `ENVIRONMENT` environment variable
- Stack traces attached (`attachStackTrace: true`)
- Default PII disabled for privacy

### Coverage
- All uncaught exceptions in main isolate
- Background service errors
- BLoC error states (when `status: error`)

---

## Build Outputs

| Build Type | Size | Location |
|------------|------|----------|
| Debug APK | ~142MB | `build/app/outputs/flutter-apk/app-debug.apk` |
| Release APK | ~53MB | `build/app/outputs/flutter-apk/app-release.apk` |

**Release APK includes:**
- R8 code minification (99.8% tree-shaking on Material Icons)
- Native library optimization
- Resource optimization
