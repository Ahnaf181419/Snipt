# snipt — Comprehensive Code Audit Review

**Date:** June 25, 2026  
**Auditor:** Automated (Hermes Agent)  
**Commit:** `697bc3c` (Fix 14 bugs found in comprehensive audit)  
**Branch:** main  

---

## Executive Summary

| Metric | Value |
|---|---|
| Handwritten Dart (lib/ + pigeons/) | 1,617 lines across 21 files |
| Generated Dart (*.g.dart, *.freezed.dart) | 1,715 lines across 4 files |
| Kotlin (handwritten) | 294 lines across 3 files |
| Kotlin (Pigeon-generated) | 480 lines (1 file) |
| Tests | 6 tests (5 repository + 1 widget) across 2 files |
| `flutter analyze` | **0 issues** |
| `flutter test` | **6/6 passing** |

**Overall Score: 7.9 / 10 (B+)**

snipt is a well-architected, thoughtfully designed Android clipboard manager with excellent separation of concerns, honest handling of Android's clipboard restrictions, and clean idiomatic code. The primary weaknesses are in test coverage breadth (only 6 tests), missing at-rest database encryption, placeholder build configuration (com.example package, debug signing), and the default README template. The core data layer and capture engine are production-quality; the gaps are in surrounding hardening and CI maturity.

---

## Scoring Rubric

Each section is rated on a scale of 1–10:

| Score | Grade | Meaning |
|---|---|---|
| 9–10 | A / A+ | Production-ready, exemplary |
| 7–8 | B / B+ | Solid, minor gaps |
| 5–6 | C / C+ | Functional but needs work |
| 3–4 | D | Significant issues |
| 1–2 | F | Broken or missing |

---

## 1. Architecture & Design — 9/10

**Strengths:**
- Feature-first layering is textbook clean: `app/`, `core/`, `data/`, `domain/`, `features/` with clear directional dependencies.
- The "B-first, A-ready" capture strategy is pragmatic and honest — it does not pretend background capture works. The onboarding screen explicitly tells users about Android's limitation.
- Sync-ready data model designed from day one: UUID primary keys, `updatedAt` for last-write-wins, `deletedAt` tombstones, `contentHash` for dedup. A future `RemoteSyncRepository` can wrap the existing `ClipRepository` surface without schema changes.
- Single `GoRouter` table with a defensive redirect for the `/detail` route (handles missing `extra` gracefully instead of crashing).
- Root gate pattern cleanly separates onboarding / lock / history states based on async-loaded settings.

**Weaknesses:**
- No formal dependency injection container — providers are spread across `providers.dart` and `settings.dart`. Acceptable for this codebase size, but as features grow this will need consolidation.
- `riverpod_generator` is listed as a dev dependency but is never used (all providers are handwritten). Either adopt codegen consistently or remove the dependency to avoid confusion.

---

## 2. Data Layer (Database & Repository) — 9/10

**Strengths:**
- Drift schema is well-designed with appropriate column types, defaults, and constraints.
- `contentHash` UNIQUE constraint enables O(1) duplicate detection.
- Dedup logic is sophisticated: re-capturing the same content bumps `usageCount`, floats the clip to the top (via `updatedAt`), and preserves the immutable `createdAt` ("Saved" timestamp).
- Soft delete with tombstone (`deletedAt`) that is correctly excluded from history/search but preserved for future sync. Re-capturing deleted content properly undeletes it.
- FTS5 full-text search is maintained transactionally inside the repository (no trigger drift). The standalone FTS5 table is not external-content, avoiding the sync footgun.
- FTS5 query input is sanitized — all FTS5 syntax characters are stripped, preventing parse errors and injection.
- Hard byte cap (`maxClipBytes = 256KB`) prevents DB bloat.
- All SQL is isolated in `ClipRepository`; widgets interact only through `ClipActions` and providers.

**Weaknesses:**
- **No at-rest database encryption** (SQLCipher designed-for but not enabled). Clipboard contents are stored in plaintext `snipt.sqlite`. This is the biggest security gap for a privacy-focused app. Acknowledged in CLAUDE.md.
- `prune()` hard-deletes rows (not soft-delete tombstones). This is intentional for non-synced data but would need revisiting when sync is implemented.
- No batch insert optimization for bulk import scenarios.

---

## 3. Native Capture Engine (Kotlin) — 8/10

**Strengths:**
- Four capture lanes are all wired: share-sheet (`ACTION_SEND`), process-text (`ACTION_PROCESS_TEXT`), Quick-Settings tile, and in-app button via foreground service notification.
- `lastFocusDispatchedContent` guard prevents double-counting `usageCount` when the user copies from within snipt and returns, and prevents spamming captures on every dialog dismiss / permission prompt return.
- Pending capture queue with `dartReady` flag ensures cold-start shares are never dropped before Dart registers its handler.
- `CaptureService` is correctly declared as `specialUse` foreground service with the `PROPERTY_SPECIAL_USE_FGS_SUBTYPE` property, which is the Play Console-compliant approach.
- `CaptureTileService` handles both pre-14 (`startActivityAndCollapse`) and 14+ (`PendingIntent` variant) correctly.
- `copyToClipboard` records what was written so the focus-gain handler doesn't re-dispatch.
- `PendingIntent.FLAG_IMMUTABLE` used everywhere (security best practice on Android 12+).

**Weaknesses:**
- **`POST_NOTIFICATIONS` runtime permission request is not wired** (Android 13+). The foreground service notification won't be visible until the user manually grants the permission. The service starts but silently. Acknowledged in CLAUDE.md but this is a real UX break for new users.
- No error handling around `startForegroundService()` — if the service fails to start (e.g., background launch restrictions), no feedback is given to the Dart side.
- `CaptureService.startForegroundNotification()` uses `android.R.drawable.ic_menu_save` as the notification icon — a generic system icon, not a branded one.
- No `onTaskRemoved` / `onTimeout` handling for the foreground service (Android 14+ can timeout FGS after ~6 hours for certain types, though `specialUse` may be exempt).

---

## 4. Platform Bridge (Pigeon) — 9/10

**Strengths:**
- `pigeons/capture_api.dart` serves as the single source of truth for the native channel. Clean `@HostApi()` (Dart→native) and `@FlutterApi()` (native→Dart) separation.
- `CaptureSourceDto` is deliberately kept separate from the domain `CaptureSource` enum to avoid the generated channel code depending on the domain layer.
- The `CaptureBridge` class cleanly implements `CaptureFlutterApi` for inbound capture and exposes `CaptureHostApi` for outbound control.
- `register()` connects the handler and tells native Dart is ready (`flutterReady()`), with error-swallowing for test environments.
- Generated code (`CaptureApi.g.kt`, `capture_api.g.dart`) is committed.
- Provider disposes the Pigeon handler on teardown to prevent stale handler delivery.

**Weaknesses:**
- The bridge's `captureFromClipboard()` is nearly identical to `onClipCaptured`'s internal logic — minor duplication.
- No versioning or backward-compatibility strategy for the Pigeon contract as the app evolves.

---

## 5. State Management (Riverpod) — 8/10

**Strengths:**
- Clean use of Riverpod 3's core API: `Provider`, `StreamProvider.autoDispose`, `AsyncNotifierProvider`, `Notifier`.
- `SettingsController` uses optimistic updates with revert-on-failure — in-memory state and persisted state never diverge.
- `clipListProvider` reactively switches between history and search based on `searchQueryProvider` state.
- `ClipActions` centralizes mutations shared between list and detail screens.
- Database and bridge providers properly register `onDispose` callbacks.
- `sessionUnlockedProvider` resets on cold start (correct security behavior for app lock).

**Weaknesses:**
- `sessionUnlockedProvider` uses legacy `StateProvider` (imported from `package:flutter_riverpod/legacy.dart`). Works, but should migrate to `Notifier` for Riverpod 3 consistency.
- `clipListProvider` is `autoDispose` but `searchQueryProvider` is not — the search query survives screen disposal. This is intentional but could surprise.
- No error recovery state for stream failures (the history screen shows raw error text).
- `ClipActions.copy()` calls `bumpUsage` after the native `copyToClipboard` — if the native call succeeds but `bumpUsage` fails, the usage count is silently wrong. No transaction or rollback.

---

## 6. UI / Feature Screens — 8/10

**Strengths:**
- Material 3 with dynamic color support (Android 12+), seeded brand fallback, coherent light/dark themes.
- History screen: reactive list, swipe-to-delete with undo snackbar, search-as-you-type, popup menu per item (copy/pin/open/delete), setup banner when service isn't enabled.
- Detail screen: selectable text, metadata display (type, saved time, usage count, byte size, source app).
- Settings screen: capture service toggle, overlay permission shortcut, app lock with biometric verification, retention dropdown.
- Onboarding: honest explanation of Android's clipboard restriction, three capture methods explained, CTA to enable service.
- Lock screen: biometric unlock, error states, escape hatch to disable lock when no biometrics are available.
- All async gaps use `mounted` checks.

**Weaknesses:**
- **History/search capped at 50 rows** with no pagination or load-more (`watchHistory`/`watchSearch` take a `limit`). A power user with thousands of clips will only see the newest 50.
- No pull-to-refresh on the history list.
- No empty-state illustration (just plain text "No clips yet").
- `_delete()` in history uses `Dismissible.onDismissed` but the item animates out before the undo snackbar appears — if the undo is tapped, the item pops back in with a jarring re-animation.
- Detail screen pops back to history after pin/delete — the user loses their scroll position.
- No haptic feedback on swipe-to-delete or long-press.
- No dark-mode-specific testing or visual verification.

---

## 7. Security & Privacy — 7/10

**Strengths:**
- App lock with `local_auth` biometrics and device PIN fallback.
- `flutter_secure_storage` (Android Keystore-backed) for all settings.
- FTS5 query input is sanitized to prevent injection.
- No network permissions, no analytics, no telemetry — truly local-first.
- Privacy statement is prominently displayed in settings.
- `PendingIntent.FLAG_IMMUTABLE` prevents intent mutation attacks.
- Clipboard content hash uses SHA-256 (for dedup, not security — but appropriate).

**Weaknesses:**
- **Database encryption (SQLCipher) is not enabled.** All clipboard content is stored in plaintext `snipt.sqlite` in the app's documents directory. On a rooted device or via ADB backup, all clips are readable. This is the single most important security gap for a self-described "privacy-focused" app.
- **App lock only gates cold start.** It is not re-armed when the app is resumed from the background (`sessionUnlockedProvider` persists for the session). A user who briefly switches away and returns sees their history without re-authentication.
- **No PIN/password fallback.** If biometrics are unavailable, the only option is to disable app lock entirely (`_showDisableLock` → `_disableLock`). There is no alternative unlock method.
- **Fail-open root gate:** if settings read fails, the app shows history instead of locking. This is a deliberate UX decision but means a corrupted secure-storage read bypasses app lock.
- Clipboard content written to the system clipboard by snipt has no expiry (unlike some clipboard managers that auto-clear after N seconds).

---

## 8. Test Coverage — 5/10

**Strengths:**
- Repository tests are excellent: URL classification, duplicate collapsing with usageCount bump, FTS prefix search, tombstone exclusion, soft-delete + re-capture restore, pin float-to-top, prune survival.
- Widget test verifies onboarding renders correctly with fake settings store.
- Tests use in-memory Drift database (`AppDatabase.forTesting(NativeDatabase.memory())`).
- Settings store is designed with overridable methods for clean test faking.

**Weaknesses:**
- **Only 6 tests total.** For a codebase of ~1,900 handwritten lines, this is thin.
- **No widget tests** for: history screen interactions (copy, delete, undo, pin, search filtering), detail screen, settings screen, lock screen.
- **No unit tests** for: `ClipType.classify()` (URL detection edge cases), `timeAgo()` and `formatBytes()` helpers, `CaptureBridge` logic, settings persistence round-trip, `ClipActions`.
- **No integration tests** for the capture flow (native → bridge → repository → UI).
- **No golden tests** for visual regression.
- **No edge case tests**: empty clipboard, very large clip (>256KB cap), special characters in FTS, concurrent capture calls.
- Test coverage of the Kotlin layer is zero (no instrumented tests).

---

## 9. Code Quality & Documentation — 9/10

**Strengths:**
- Every file has a purpose-documenting doc comment. Every non-trivial method explains its rationale.
- `CLAUDE.md` is comprehensive: architecture overview, stack versions, commands, conventions, gotchas, known follow-ups. This is a model for how to document a project.
- Code style is consistent: single quotes, trailing commas, named parameters, const constructors.
- No dead code, no commented-out code blocks, no `print()` statements left behind.
- Inline comments explain "why", not "what" (e.g., why `createdAt` is kept immutable, why tombstones are preserved, why `lastFocusDispatchedContent` exists).
- Generated files are correctly committed and excluded from analysis.
- Error messages are user-friendly (not raw stack traces).

**Weaknesses:**
- `analysis_options.yaml` has no custom lint rules — everything is commented out. The default `flutter_lints` set is good but the project could benefit from stricter rules (e.g., `prefer_const_constructors`, `require_trailing_commas`, `avoid_dynamic_calls`).
- `README.md` is the default Flutter template ("A new Flutter project") with no project-specific content. This is the first thing a new contributor or Play Store reviewer sees.
- `pubspec.yaml` description is "A new Flutter project" — should be updated for store listing.

---

## 10. Build & Configuration — 7/10

**Strengths:**
- Kotlin DSL (`build.gradle.kts`) with Java 17 target.
- `minSdk` correctly floored to 24 (needed for local_auth, secure storage, FGS types).
- `core-ktx` dependency explicitly pinned.
- AndroidManifest is thorough: all intent-filters (SEND, PROCESS_TEXT), service declarations with correct `foregroundServiceType`, tile service with `BIND_QUICK_SETTINGS_TILE` permission, `<queries>` for PROCESS_TEXT visibility.
- `specialUse` FGS has the required `PROPERTY_SPECIAL_USE_FGS_SUBTYPE` property for Play Console compliance.
- Dependencies are version-pinned with caret ranges.

**Weaknesses:**
- **`applicationId = "com.example.snipt"`** — still the placeholder package name. Must be changed before any store release. There is a `TODO` comment but it hasn't been addressed.
- **No release signing configuration** — the release build type uses debug signing keys. Cannot ship to Play Store.
- **No CI/CD pipeline** — no GitHub Actions workflow, no automated builds or tests on push/PR.
- **No ProGuard/R8 rules** — though Flutter handles most of this, custom rules may be needed for release optimization.
- `android/local.properties` should be in `.gitignore` (verify — it may already be).
- Dependency versions are somewhat behind in some cases (e.g., `freezed: ^3.2.6-dev.1` is a dev release).

---

## 11. Error Handling & Resilience — 8/10

**Strengths:**
- Settings controller: optimistic update with automatic revert on write failure.
- Root gate: fail-open to history on settings read error (deliberate — avoids locking users out).
- Capture bridge: `flutterReady()` call is fire-and-forget with caught errors (test environments).
- Lock screen: handles `NotEnrolled` / `NotAvailable` PlatformExceptions with an escape hatch.
- Settings screen: `_syncServiceState()` reconciles stored service state with actual running state on screen entry.
- All async UI methods check `mounted` before calling `setState` or showing snackbars.
- Onboarding: service start failure is silently caught (can be re-enabled from Settings).

**Weaknesses:**
- History screen error state shows raw `Error: $e` — not user-friendly, and could leak internal details.
- No global error boundary or crash reporting (no `FlutterError.onError` handler, no `PlatformDispatcher.instance.onError` handler).
- No retry logic for failed database operations.
- `_toggleService()` in settings catches errors and shows a snackbar, but doesn't revert the switch state visually (the optimistic update in `setCaptureServiceEnabled` runs before the error is caught, and there's no revert).

---

## Prioritized Recommendations

### Critical (must fix before production release)

1. **Enable SQLCipher database encryption** — clipboard contents in plaintext contradict the "privacy-focused" positioning. Drift supports SQLCipher via `SQLCipherOpenHandler`.
2. **Change `applicationId`** from `com.example.snipt` to a real package name (e.g., `com.shonchoy.snipt` or your brand domain).
3. **Set up release signing configuration** — generate a keystore and configure the release build type.
4. **Wire `POST_NOTIFICATIONS` runtime permission request** (Android 13+) — the capture service is useless without a visible notification for new users.

### High Priority (should fix soon)

5. **Re-arm app lock on app resume** — use `WidgetsBindingObserver.didChangeAppLifecycleState` to reset `sessionUnlockedProvider` when the app returns from background.
6. **Expand test coverage** — add widget tests for history/detail/settings/lock screens, unit tests for `ClipType.classify()`, `timeAgo()`, `formatBytes()`, and `CaptureBridge`.
7. **Implement pagination / load-more** for history beyond the 50-row cap.
8. **Set up CI/CD** — GitHub Actions workflow running `flutter analyze`, `flutter test`, and `flutter build apk` on every push/PR.
9. **Replace the default README** with a real project description, screenshots, and setup instructions.

### Medium Priority (improve quality)

10. **Add global error handling** — `FlutterError.onError` + `PlatformDispatcher.onError` with user-friendly error UI.
11. **Add stricter lint rules** in `analysis_options.yaml` (prefer_const_constructors, require_trailing_commas, etc.).
12. **Add a branded notification icon** for the capture foreground service.
13. **Add haptic feedback** on swipe-to-delete and long-press interactions.
14. **Pin detail screen scroll position** when returning from pin/delete actions.
15. **Migrate `StateProvider` → `Notifier`** for `sessionUnlockedProvider` (Riverpod 3 consistency).

### Low Priority (polish)

16. **Add empty-state illustrations** for "No clips yet" and "No matches".
17. **Add clipboard auto-clear option** (clear system clipboard after N seconds).
18. **Add PIN/password fallback** for app lock when biometrics are unavailable.
19. **Remove unused `riverpod_generator`** dev dependency or adopt it consistently.
20. **Add instrumented tests** for the Kotlin capture layer.

---

## Score Summary

| # | Section | Score | Grade |
|---|---|---|---|
| 1 | Architecture & Design | 9/10 | A |
| 2 | Data Layer (Database & Repository) | 9/10 | A |
| 3 | Native Capture Engine (Kotlin) | 8/10 | B+ |
| 4 | Platform Bridge (Pigeon) | 9/10 | A |
| 5 | State Management (Riverpod) | 8/10 | B+ |
| 6 | UI / Feature Screens | 8/10 | B+ |
| 7 | Security & Privacy | 7/10 | B |
| 8 | Test Coverage | 5/10 | C |
| 9 | Code Quality & Documentation | 9/10 | A |
| 10 | Build & Configuration | 7/10 | B |
| 11 | Error Handling & Resilience | 8/10 | B+ |
| | **Overall** | **7.9/10** | **B+** |

---

*This audit was generated by scanning all 27 Dart source files, 4 Kotlin source files, 2 test files, and all configuration files. Static analysis (`flutter analyze`) and test execution (`flutter test`) were run and confirmed clean.*
