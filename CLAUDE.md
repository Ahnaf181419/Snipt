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
  app/         ShadApp (shadcn/ui), theme (zinc neutrals), go_router
  core/        constants, formatting helpers, haptics
  data/
    db/        Drift database (Clips table + FTS5), generated code, key mgr
    platform/  Pigeon-generated channel + CaptureBridge
    billing/   BillingService interface + IapBillingService + providers
    clip_repository.dart   capture/dedup/search/pin/prune (SQL lives here only)
    settings.dart          encrypted prefs + AsyncNotifier
    providers.dart         Riverpod wiring + ClipActions
  domain/models/   ClipType (+classifier), CaptureEvent (freezed)
  features/    history/ · detail/ · settings/ · onboarding/ · root_gate
  widgets/     shared EmptyState, ProGate
android/app/src/main/kotlin/dev/frostflux/snipt/
  MainActivity.kt              implements the Pigeon host API + intent handling
  capture/CaptureService.kt    specialUse foreground service
  capture/CaptureTileService.kt Quick-Settings tile
  capture/CaptureApi.g.kt      generated Pigeon Kotlin
pigeons/capture_api.dart        Pigeon contract (source of truth for the channel)
```

## Data layer

- Drift + SQLCipher: encrypted at rest. Key generated on first launch via
  `Random.secure()` (32 bytes), stored in Android Keystore by
  `flutter_secure_storage`. PRAGMA key applied in the `setup:` callback of
  `NativeDatabase.createInBackground`.
- `Clips` table: UUID `id`, `contentHash` UNIQUE (O(1) dedup), `updatedAt`
  (last-write-wins), `deletedAt` soft-delete tombstone, `isPinned`,
  `usageCount`. Image clips add `mediaPath` (absolute path to filesDir/media/)
  and `mimeType`.
- Standalone FTS5 index maintained transactionally by the repository
  (no triggers). Image clips have no FTS entry.
- Free-tier cap (200 clips, 200 MB media) is bypassed for Pro users and
  always spares pinned rows.

## Capture engine (native, Kotlin)

- `CaptureService` — specialUse foreground service. Persistent notification
  with a "Capture clip" action that opens `MainActivity` with
  `ACTION_CAPTURE_NOW`. Required because Android 10+ blocks background
  clipboard reads; Play Console Data Safety form must justify the
  specialUse subtype (data stays on-device).
- `CaptureTileService` — Quick-Settings tile that does the same.
- `MainActivity` — reads the clipboard on `onWindowFocusChanged` (only legal
  window), and on `ACTION_SEND` (text+image), `ACTION_PROCESS_TEXT`, and
  the service/tile intent. Has a `lastFocusDispatchedContent` guard so a
  focus-gain after a copy-from-within-snipt isn't double-counted.
- POST_NOTIFICATIONS is requested at runtime on Android 13+ before starting
  the service. Service starts from `onRequestPermissionsResult`.

## Stack
Flutter 3.44 / Dart 3.12 · Riverpod 3 (manual providers; core API, not the
prerelease generator) · Drift 2.33 + sqlite3 · freezed 3 · go_router 17 ·
shadcn_ui 0.55 (shadcn/ui port, replaces Material) · lucide_icons_flutter ·
flutter_secure_storage 10 · Pigeon 26.

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
- shadcn_ui: theme access via `ShadTheme.of(context)`. `ShadApp.router` builds
  `WidgetsApp.router` (not MaterialApp) so `ScaffoldMessenger` is bridged via
  the `builder:` wrapper in `app.dart`. Scaffold/AppBar still work because
  ShadApp provides a `ThemeData` via `AnimatedTheme`.
- All SQL stays in `ClipRepository`; widgets use `ClipActions` / providers.
- Generated files (`*.g.dart`, `*.freezed.dart`, `*.g.kt`) are committed.
- minSdk floored to 24.

## Known follow-ups
- History/search are capped at the newest 50 rows; pagination / load-more is not
  implemented yet (`watchHistory`/`watchSearch` take a `limit`).
- Image clip dedup hashes on the file path. Because both import paths
  (share-sheet + gallery picker) generate a fresh UUID filename every time,
  re-sharing the same photo makes a new row. A real fix needs to hash on the
  image bytes (slow) or trust a stable source URI (risky).
- Image clips: EXIF orientation is not handled on insert; thumbnails are
  decoded on-demand (no pre-generated cache on disk); SEND_MULTIPLE (batch
  share) is not supported.
- Sync and the IME keyboard are out of the current scope.
