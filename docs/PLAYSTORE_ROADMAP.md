# snipt — Play Store Premium Roadmap

> Goal: Take snipt from solid prototype to a premium, standout Play Store app.
> Items marked [DONE] are completed in this session.

---

## PHASE 1: Critical Blockers (must fix before any release)

### 1a. SQLCipher database encryption [DONE]
- Clipboard contents are now encrypted at rest with SQLCipher
- Key generated via Random.secure and stored in Android Keystore via flutter_secure_storage
- Dependency swapped from sqlite3_flutter_libs to sqlcipher_flutter_libs

### 1b. POST_NOTIFICATIONS runtime permission [DONE]
- Android 13+ permission request wired in MainActivity.kt
- Pigeon API extended with hasNotificationPermission()
- Permission is requested before starting CaptureService
- Service auto-launches once permission is granted

### 1c. Application ID [DONE]
- Set to `dev.frostflux.snipt` (namespace + applicationId aligned)
- iOS bundle ID also aligned to `dev.frostflux.snipt` for cross-platform consistency
- macOS + Linux bundle IDs aligned to match

### 1d. Release signing config [DONE]
- Template added to build.gradle.kts
- Reads from android/key.properties (gitignored)
- Falls back to debug signing when no keystore is configured
- To set up: generate a keystore, create android/key.properties with:
  storePassword=***
  keyPassword=***
  keyAlias=upload
  storeFile=/path/to/upload-keystore.jks

---

## PHASE 2: Premium UX Polish [ALL DONE]

### 2a. Empty states [DONE]
- Premium EmptyState widget with icon circle, title, subtitle
- Different states for: no clips, no search results, errors

### 2b. Haptic feedback [DONE]
- Haptics helper class (light/medium/selection)
- Wired on: capture, copy, delete, pin, swipe-to-dismiss

### 2c. Skeleton loading [DONE]
- Shimmer skeleton tiles matching ClipTile layout
- SkeletonClipList renders 6 placeholders during load

### 2d. Debounced search [DONE]
- 200ms debounce via debouncedSearchProvider
- Prevents FTS5 spam on every keystroke
- clipListProvider now consumes debounced query

### 2e. App lock re-arm on resume [DONE]
- WidgetsBindingObserver in RootGate
- sessionUnlockedProvider resets to false on app resume
- Lock screen shows again if user left the app

### 2f. Global error handling [DONE]
- FlutterError.onError handler in main.dart
- runZonedGuarded wraps the entire app
- ErrorWidget.builder replaces red screen in release mode

### 2g. Theme polish [DONE]
- Transparent AppBar with proper system overlay style
- Filled input fields with focus ring
- Floating snackbars with rounded corners
- ListTile with rounded shape
- Subtle dividers
- Branded switches
- Rounded bottom sheets with drag handle
- Refined typography weight scale
- Card margins for better spacing

---

## PHASE 3: Performance and Battery Optimization [PARTIALLY DONE]

### 3a. Debounced search [DONE — see 2d]
### 3b. Battery-efficient foreground service [EXISTING — already minimal]
### 3c. Lazy pagination / load-more [PENDING]
- History/search currently capped at 50 rows
- Need ScrollController-based load-more

---

## PHASE 4: Feature Additions for "Stand Out" [NOT STARTED]

### 4a. Clipboard auto-clear timer
- Auto-delete clips after X hours/days
### 4b. Export/import clips
- JSON export for backup
### 4c. Home screen widget
- Quick capture from home screen
### 4d. Custom app icon and notification icon
### 4e. App icon variants (themed/monochrome for Android 13+)

---

## PHASE 5: Play Store Readiness [PARTIALLY DONE]

### 5a. Real README [DONE]
### 5b. Privacy policy [PENDING — required for Play Store]
### 5c. Store listing assets [PENDING]
- Screenshots (phone + tablet)
- Feature graphic (1024x500)
- App icon (512x512 PNG)
### 5d. ProGuard/R8 rules [PENDING — verify release build]
### 5e. Version bump in pubspec.yaml [PENDING]
