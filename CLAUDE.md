# snipt — Android clipboard manager (Flutter)

A local-first, privacy-focused clipboard history manager. Captures copied text,
lets you search / pin / reuse it, stored only on-device.

## The defining constraint (read this first)

Android 10+ (API 29) **blocks background clipboard reads** — `getPrimaryClip()`
only returns data while the app is the focused foreground app or the active IME.
So fully-automatic silent capture is impossible without being a keyboard or
using ADB-granted `READ_LOGS` (not Play-Store shippable).

snipt uses the **"B-first, A-ready"** strategy:
- **B (shipped):** foreground service + Quick-Settings tile + share-sheet target
  + in-app button = capture-on-interaction, Play-Store compliant.
- **A (future, premium):** custom keyboard / IME for near-automatic capture.
- **C (advanced, sideload only):** `READ_LOGS` via ADB — never the Play default.

When touching capture, do not claim or imply automatic background capture.

## Architecture

Feature-first layers. Capture is native Kotlin; Flutter is the UI + store.

```
lib/
  app/         MaterialApp, theme (M3 + dynamic color), go_router
  core/        constants, formatting helpers
  data/
    db/        Drift database (Clips table + FTS5), generated code
    platform/  Pigeon-generated channel + CaptureBridge
    clip_repository.dart   capture/dedup/search/pin/prune (SQL lives here only)
    settings.dart          encrypted prefs + AsyncNotifier
    providers.dart         Riverpod wiring + ClipActions
  domain/models/   ClipType (+classifier), CaptureEvent (freezed)
  features/    history/ · detail/ · settings/ · onboarding/ · root_gate
android/app/src/main/kotlin/com/example/snipt/
  MainActivity.kt              implements the Pigeon host API + intent handling
  capture/CaptureService.kt    specialUse foreground service
  capture/CaptureTileService.kt Quick-Settings tile
  capture/CaptureApi.g.kt      generated Pigeon Kotlin
pigeons/capture_api.dart        Pigeon contract (source of truth for the channel)
```

### Data model (sync-ready, not yet synced)
`Clips`: UUID `id`, `contentHash` UNIQUE (O(1) dedup), `updatedAt`
(last-write-wins), `deletedAt` soft-delete tombstone, `isPinned`, `usageCount`.
Image clips add `mediaPath` (absolute path to filesDir/media/) and `mimeType`.
Search via a standalone FTS5 table maintained transactionally by the repository
(no triggers). Image clips have no FTS entry. A future `RemoteSyncRepository`
can wrap `ClipRepository`.

## Stack
Flutter 3.44 / Dart 3.12 · Riverpod 3 (manual providers; core API, not the
prerelease generator) · Drift 2.33 + sqlite3 · freezed 3 · go_router 17 ·
dynamic_color · local_auth 3 · flutter_secure_storage 10 · Pigeon 26.

## Commands
- `flutter pub get`
- `dart run build_runner build` — regen Drift + freezed (commit the outputs)
- `dart run pigeon --input pigeons/capture_api.dart` — regen the channel
  (Dart + Kotlin) after editing the contract
- `flutter analyze lib test`
- `flutter test`
- `flutter build apk --debug` — the only way to validate the Kotlin here

## Conventions / gotchas
- Riverpod 3: `AsyncValue.value` is the nullable accessor (no `valueOrNull`);
  `StateProvider` lives in `package:flutter_riverpod/legacy.dart`.
- local_auth 3: `authenticate()` takes named params directly
  (`persistAcrossBackgrounding`), not an `AuthenticationOptions` object.
- All SQL stays in `ClipRepository`; widgets use `ClipActions` / providers.
- Generated files (`*.g.dart`, `*.freezed.dart`, `*.g.kt`) are committed.
- minSdk floored to 24.

## Known follow-ups
- POST_NOTIFICATIONS runtime request (Android 13+) is not yet wired — the FGS
  notification needs the user to allow notifications.
- History/search are capped at the newest 50 rows; pagination / load-more is not
  implemented yet (`watchHistory`/`watchSearch` take a `limit`).
- At-rest DB encryption (SQLCipher) is designed-for but not enabled; app lock is
  not yet built at all (no PIN/biometric gate exists — the Pro-benefits copy
  in settings is intentionally no longer promising it).
- Image clips: EXIF orientation is not handled on insert; thumbnails are
  decoded on-demand (no pre-generated cache on disk); SEND_MULTIPLE (batch
  share) is not supported.
- Sync and the IME keyboard are out of the current scope.
