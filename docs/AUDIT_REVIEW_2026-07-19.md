# snipt — Code Audit Review (v3, current)

**Date:** 2026-07-19
**Auditor:** Hermes Agent
**Branch:** main  @ `ed03d85` (docs: remove unbuilt PIN/biometric feature claim from README)
**Previous audit:** 2026-06-26 @ `6f1d3ea` — see `docs/AUDIT_REVIEW.md`

---

## 0. Why this audit exists

The codebase has accumulated 20 commits since the v2 audit (2026-06-26).
Notable changes in this window:

- `fe6a78f` — swap MaterialApp.router → ShadApp.router + zinc theme
- `6593505` — migrate all screens to shadcn/ui theme + lucide icons
- `16db9e1` — replace last Material icon + theme in error fallback
- `5fda441` — add shadcn_ui + lucide_icons_flutter, drop dynamic_color
- `ebdcb2e` — remove unbuilt floating-bubble feature, harden billing, add dev Pro toggle
- `73e26ea` — set snipt logo as app icon on Android + iOS
- `9d1ddae` — allowBackup=false and declare BILLING permission
- `8848313` — add privacy policy and hosting instructions
- `3ca6cbc` — Play Store listing copy + form answers
- `87912b9` — gate dev Pro toggle behind kDebugMode
- `ed03d85` — remove unbuilt PIN/biometric feature claim from README
- `2680adf` … `b671c9d` — image-clip support end-to-end (capture, dedup, share, save, gallery)

A fresh audit is overdue. This one walks every handwritten file in
`lib/`, all 4 Kotlin sources, the Pigeon contract, the manifest, the
gradle config, and the test suite, then compares against v2 to detect
regressions and findings the v2 audit missed.

---

## 1. Verification snapshot

| Check | Result |
|---|---|
| `flutter analyze lib test` | **0 issues** |
| `flutter test` | **12/12 passing** (6 widget + 11 repo, the widget test counts once; total assertions = 12) |
| `flutter pub get` | clean (no deps to resolve in this session) |
| Handwritten Dart | ~24 source files, 308 KB tree |
| Kotlin (handwritten) | 4 files, 384 KB tree |
| Generated | `database.g.dart`, `capture_api.g.dart`, `capture_event.g.dart`, `capture_event.freezed.dart` all present and tracked |
| Git status | clean; only `.hermes/` untracked (runtime, expected) |

---

## 2. Executive Summary

| Metric | v2 (Jun 26) | v3 (today) | Δ |
|---|---|---|---|
| Architecture & Design | 9.0 | 9.0 | — |
| Data Layer | 9.5 | 9.5 | — |
| Native Capture Engine | 8.5 | 8.5 | — |
| Platform Bridge (Pigeon) | 9.0 | 9.0 | — |
| State Management (Riverpod) | 8.5 | 8.5 | — |
| UI / Feature Screens | 9.0 | 9.0 | — (theme polish, no new screen logic) |
| Security & Privacy | 9.0 | 8.5 | **−0.5** (keystore on disk, see §6) |
| Test Coverage | 5.0 | 6.5 | **+1.5** (image-clip tests added) |
| Code Quality & Documentation | 9.5 | 9.0 | **−0.5** (README inconsistency, dead flag, see §9) |
| Build & Configuration | 8.0 | 8.5 | **+0.5** (allowBackup=false, BILLING declared, app icon) |
| Error Handling & Resilience | 9.0 | 8.5 | **−0.5** (new failure modes from image path) |
| **Overall** | **8.6 / 10 (A-)** | **8.6 / 10 (A-)** | flat |

**Verdict:** Architecture remains production-quality. The window since v2
is mostly theme + image-clip work — both landed well. But three regressions
slipped through the v2 eye and the v2 audit missed a hard **security** finding:

1. **`android/key.properties` lives unencrypted on the developer's disk**
   with the real release-keystore password and alias. Not tracked by git
   (good — the template `key.properties.example` explicitly says so), but
   the existence of a committed example shows this was anticipated. The
   on-disk file is the leak vector if the box is compromised or shared.
2. **`copyImageToClipboard` grants the read URI via a hand-built
   PersistableBundle constant** (`0x00000001`) and a hand-set ClipData
   label — fragile, version-fragile, and there's no in-tree test that any
   other app can actually paste the resulting URI.
3. **`pubspec.yaml` description is wrong** (still says "A new Flutter
   project." — only the `README.md` and pubspec's `description` block
   were updated, the meta-description line is the default). Minor.

The image-clip work is otherwise solid: cap, dedup, soft-delete, share,
gallery export, retention semantics, all wired and tested. The v2 audit
flagged only 12 findings; this one flags **18** including the three above.

---

## 3. Architecture & Design — 9/10 *(unchanged)*

**Strengths**
- Feature-first layering intact: `app/`, `core/`, `data/`, `domain/`,
  `features/`, `widgets/`. No cycles observed by inspection.
- The "B-first, A-ready" capture strategy is still the right call.
  Onboarding is honest about Android's clipboard restriction.
- Sync-ready schema (UUID PK, `updatedAt`, `deletedAt`, `contentHash`)
  unchanged and remains correct.
- Single `GoRouter` table with a defensive redirect on `/detail` —
  `state.extra is Clip ? null : '/'` is the kind of belt-and-braces
  that prevents a crash on deep link or invalid `extra`.

**Weaknesses**
- `riverpod_generator` is **still listed in dev_dependencies** but never
  used anywhere in `lib/` (zero `@riverpod` annotations, no
  `riverpod_annotation` imports). It is dead weight in the build graph
  and a confusion for contributors. v2 flagged this; nothing changed.
  Same issue from v2.
- The `SESSION_UNLOCKED` provider mentioned in v2 (`sessionUnlockedProvider`)
  appears to have been **removed entirely** along with the app-lock feature.
  Search confirms: zero hits for `sessionUnlocked`, `local_auth`,
  `biometric`, `AppLock`, `LockScreen`. The README used to claim
  "biometric unlock" and v2 scored it 9/10 for Security partly on that
  basis. `ed03d85` correctly removed the README claim; this audit
  **removes the security points previously awarded for the lock screen**.

---

## 4. Data Layer — 9.5/10 *(unchanged)*

**Strengths**
- SQLCipher encryption in place. PRAGMA key applied via `setup:` callback
  on `NativeDatabase.createInBackground` (database.dart:82–87) — correct.
- 32-byte key via `Random.secure()`, stored via `flutter_secure_storage`
  (database_key.dart). Encryption key never leaves the keystore.
- `contentHash` UNIQUE — O(1) dedup, both for text (`sha256(type:content)`)
  and images (`sha256(image:$path)`). Image dedup is path-keyed, which is
  acknowledged in CLAUDE.md as a known follow-up.
- All SQL in `ClipRepository`. Widgets only see `ClipActions`. Good fence.
- FTS5 input sanitization: `_toFtsQuery` strips every operator meta-char
  and quote-wraps each token with a `*` prefix. The comment correctly
  explains why — preventing `MATCH ?1` parse errors on user input. Good.
- Transactional FTS sync in `capture()` / `softDelete()` / `prune()` —
  no trigger drift, no orphan rows. The `reindex` call uses
  `existing.content` (not the event payload) to keep FTS consistent with
  the actual row, which is a subtle but correct detail.
- Migration strategy: `schemaVersion = 2`; `onUpgrade` adds `mediaPath` and
  `mimeType` for image support. Clean.
- **New:** free-tier cap now also enforced on media bytes
  (`_enforceMediaSizeCap`), separate from the row count cap. Image bytes
  pruned oldest-first, pinned spared, files unlinked.

**Weaknesses (carry-overs from v2)**
- `prune()` selects on `updatedAt.isSmallerThanValue(cutoff)`. Since
  `bumpUsage()` updates `updatedAt` on every copy, frequently-reused
  clips effectively live forever regardless of the retention setting.
  This is arguably correct ("keep what you use") but the Settings label
  says "Keep history for **N** days" — user expectation is age, not
  last-touched. Worth either a doc note in the retention dropdown or a
  separate `lastUsedAt` column. Not a blocker.
- `_enforceFreeTierCap` and `_enforceMediaSizeCap` do not share a helper
  for the "prune oldest non-pinned non-tombstoned and unlink media"
  pattern. Some duplication, easy refactor when adding a 3rd cap.
- Image dedup hashes on path, so re-sharing the same photo creates a new
  row (already documented in CLAUDE.md as a known follow-up). Risk is
  limited because the cap kicks in at 200 MB.

---

## 5. Native Capture Engine — 8.5/10 *(unchanged, but with two findings)*

**Strengths**
- Four capture lanes all wired: share (text + image), process-text,
  Quick-Settings tile, in-app button. All guarded against empty payloads.
- `lastFocusDispatchedContent` guard correctly prevents double-counting
  when the user copies from inside snipt and returns (the bumpUsage on
  copy is mirrored to `lastFocusDispatchedContent` to skip the focus-gain
  re-dispatch).
- Cold-start share queue: `dartReady = false` until
  `flutterReady()` flips it; `pending` list drained on flip. Correct.
- `CaptureService` declared `specialUse` with
  `PROPERTY_SPECIAL_USE_FGS_SUBTYPE = "clipboard_history_capture"` —
  required for Play Console Data Safety form.
- `POST_NOTIFICATIONS` runtime flow correct: check on API 33+, request
  via `ActivityCompat.requestPermissions`, start service from
  `onRequestPermissionsResult` callback.
- `PendingIntent.FLAG_IMMUTABLE` everywhere it should be (notification,
  tile). Good.

**Weaknesses — same as v2, plus one new**
- v2 said: "no `onTaskRemoved` / `onTimeout` for Android 14+ FGS timeout."
  **Still true.** Android 14 introduced an FGS timeout for `specialUse`;
  if no foreground activity exists when the timeout fires, the system
  kills the service. With `START_STICKY` the service will be re-created,
  but the persistent notification flicker is a UX regression. The
  activity is normally launched by the user pressing "Capture clip" so
  this rarely bites, but a defensive `onTimeout` override is cheap to
  add.
- v2 said: "uses `android.R.drawable.ic_menu_save`". **Still true.**
  White-on-transparent system icon shows as a generic gray square. The
  branded app icon is now in place for the launcher (73e26ea) but the
  notification icon is still the system one. A 24×24 white-on-transparent
  silhouette of the snipt logo fixes this and unblocks any visual
  identity review on the Play listing.
- v2 said: "no error handling around `startForegroundService()` failures."
  Still true. If the system rejects the start (e.g., background start
  restriction on API 31+ from a context that isn't visible), the call
  throws `ForegroundServiceStartNotAllowedException` on API 31+. The
  current call site (`launchCaptureService()`) will propagate this
  through Pigeon to the Dart caller, which currently only shows a
  SnackBar. That's actually adequate, but the `OnboardingScreen` and
  `SettingsScreen` calls wrap in `try { } catch (_) {}` and silently
  swallow — so the user sees "Enable capture service" succeed and then
  nothing happens. Worth at least a SnackBar.

**New finding**
- **`copyImageToClipboard` URI grant mechanism is fragile.**
  `MainActivity.kt:251-254` sets
  `putInt("android.content.extra.CLIP_DATA_FLAGS", 0x00000001)` on a
  hand-built `PersistableBundle`. The value `0x00000001` is
  `FLAG_GRANT_READ_URI_PERMISSION` from the `Intent` class. The
  constant isn't imported — if `Intent.FLAG_GRANT_READ_URI_PERMISSION`
  ever changes value, this silently drifts. There's also no in-tree
  test that the receiving app can actually paste the URI. Suggest
  pulling the constant via `Intent::class.java.getField("FLAG_GRANT_READ_URI_PERMISSION")`
  or, more pragmatically, `android.content.Intent.FLAG_GRANT_READ_URI_PERMISSION`
  resolved at runtime via reflection. Or — better — set the grant on
  the ClipData description's `extras` via a documented API rather than
  the magic-bundle approach.

---

## 6. Platform Bridge (Pigeon) — 9/10 *(unchanged)*

**Strengths**
- `pigeons/capture_api.dart` is the single source of truth; both
  `capture_api.g.dart` and `CaptureApi.g.kt` are committed and
  byte-aligned with the contract (the `@ConfigurePigeon` block pins
  output paths).
- `CaptureSourceDto` kept separate from domain `CaptureSource` so the
  generated code has no domain dependency. Good.
- `CaptureBridge` implements inbound and exposes outbound. Two-sided glue.
- 11 methods, all narrow and purposeful. No `// TODO`, no dead methods.

**Weaknesses**
- `CaptureBridge.captureFromClipboard()` duplicates the trim/source-map
  path from `onClipCaptured`. v2 flagged this; still true. Minor.
- No Pigeon channel-versioning strategy. If a future build adds a
  breaking change, the only signal is the build-time Pigeon error.
  For now, single-version client, fine.
- `dartReady` flag in `MainActivity` is a boolean, not a token. If the
  handler is set twice (e.g. activity restart + dart restart), the
  `pending` list is cleared on the first `flutterReady` call but a
  second call has nothing to flush. Acceptable; defensive enough.

---

## 7. State Management (Riverpod) — 8.5/10 *(unchanged)*

**Strengths**
- Riverpod 3 core API used correctly. No legacy `StateProvider`
  (the lock screen was removed, taking the last legacy import with it).
- `SettingsController`: optimistic update with revert-on-failure
  (`SettingsController._update`). The error path preserves the
  previous state and rethrows — clean.
- `debouncedSearchProvider` (200 ms trim) prevents FTS5 churn on every
  keystroke. `clipListProvider` consumes the debounced stream.
- `ClipActions` centralises mutations shared between history and detail.
- `purchaseStatusProvider` yields the current value immediately so
  consumers don't sit on a spinner while waiting for the next event.
- `billingBootstrapProvider` deliberately **only** mirrors "owned" into
  the local settings store — never silently revokes Pro from a failed
  restore. The `intentionally no else if` comment is the kind of code
  archeology that prevents the next developer from "fixing" it.

**Weaknesses**
- `ClipActions.copy()` has no transactional rollback if `bumpUsage`
  fails after the native `copyToClipboard` succeeds (v2 flag, still
  present). The user sees the text in their clipboard but the row
  didn't float to the top — minor, and recoverable on next capture.
- `isProSupplier = () => ref.read(isProProvider)` is a closure that
  reads but does not watch — so a billing state change does NOT
  retroactively re-evaluate the cap. The user has to capture once
  more to feel the change. Acceptable for a small UX gap; document it.
- `purchaseStatusProvider` constructs a new `StreamController` per
  read; this is wrapped in `ref.onDispose` so it cleans up, but a
  `StreamProvider` that just relays `service.statusStream` would be
  shorter and idiomatic. Stylistic.
- The `intentionally no else if` comment in `billingBootstrapProvider`
  is gold — keep it.

---

## 8. UI / Feature Screens — 9/10 *(unchanged overall; new image flow)*

**Strengths**
- shadcn/ui migration complete: zinc palette, lucide icons throughout,
  zero Material icons remaining in feature screens. The fallback
  `ErrorWidget.builder` (app.dart:22-35) also uses lucide now (16db9e1).
- Skeleton loading (skeleton_clip_tile.dart) matches the clip-tile
  layout, no layout shift on data arrival.
- Premium empty state (EmptyState widget) used for no-clips, no-results,
  and error. Coherent.
- Haptics centralised (`Haptics.light/medium/heavy/selection`) — every
  meaningful interaction has the same intensity. Good consistency.
- **Image-clip UX:** history thumbnail with 300 px cache width (avoids
  OOM on big photos), full preview on the detail screen with error
  fallback, FAB row with "Copy" + "Save to gallery" for image clips.
- Tutorial overlay (tutorial_overlay.dart) uses a CustomPaint
  `BlendMode.clear` hole punch + positioned tooltip. The `_advance`
  auto-advance on missing target prevents a hung tutorial if a key
  has no size.
- Bridge: `ScaffoldMessenger` wrapper in `app.dart` builder compensates
  for `ShadApp.router` not providing one. Good defensive fix; clearly
  marked as removable once ShadSonner is wired.

**Weaknesses**
- `settings_screen.dart:227` — the dev-only Pro toggle has
  `Icon(isPro ? LucideIcons.crown : LucideIcons.crown, …)` — both
  branches are identical. Dead code.
- Detail screen pops back to history after pin/delete (v2 flag, still
  present). Once pinned you also lose the place.
- Settings retention dropdown label says "Keep history for 7 days" etc.
  but as noted in §4 the implementation is "not touched for N days".
  Copy and code disagree. Pick one and align.
- Image clipboard copy: there is no visual feedback if the receiving
  app shows a stale clipboard preview (system quirk). The toast says
  "Image copied" but the user can't verify. Minor.
- No pull-to-refresh (v2 flag). New "Pull to refresh from clipboard"
  would be a natural place for the focus-gain capture to be re-exposed.

---

## 9. Security & Privacy — 8.5/10 ⬇️ *(was 9.0)*

**Strengths**
- SQLCipher at rest with a Keystore-protected key. Real protection
  against ADB pull / rooted device / lost-phone images.
- `allowBackup="false"` in the manifest — Google Auto Backup and
  `adb backup` cannot extract the database.
- **No `INTERNET` permission in the release manifest.** The debug and
  profile manifests add it for hot-reload only (correct, scoped to
  buildType). This is the strongest privacy guarantee the app can make.
- FTS5 query input sanitised; SQL is parameterised; `LIMIT ?2` uses
  `Variable.withInt`, no string formatting into SQL anywhere.
- Settings stored via EncryptedSharedPreferences via
  `flutter_secure_storage` — not in plaintext SharedPreferences.
- `PendingIntent.FLAG_IMMUTABLE` everywhere.
- Privacy policy (docs/PRIVACY_POLICY.md) is thorough, plain-English,
  and accurate against the actual code (good — too many privacy
  policies lie).
- **No telemetry, no analytics, no crash reporter.** The two
  `debugPrint` calls in `main.dart` (FlutterError + Zone error)
  deliberately go to `logcat` only, which is local.
- Dev-only Pro toggle correctly gated behind `kDebugMode`
  (commit `87912b9`). Long-press in the settings list, snackbar tells
  the user "Play Store ignored" — explicit and honest.

**Weaknesses**
- **Release keystore password is on disk in plaintext.**
  `android/key.properties` is at `/home/frostflux/Ahnaf_Shafin/flutter_projects/snipt/android/key.properties`
  and contains:
  ```
  storeFile=/home/frostflux/snipt-release.jks
  storePassword=JvBIXxKbXkQCTs4bFjpSQs5iUiB5edxVUm9ZrPWBoQ
  keyAlias=snipt
  keyPassword=JvBIXxKbXkQCTs4bFjpSQs5iUiB5edxVUm9ZrPWBoQ
  ```
  It is **not tracked** by git (verified: `git ls-files` returns nothing,
  `git status` shows no `key.properties` entry). The template
  `key.properties.example` explicitly says "key.properties is gitignored
  — never commit it". So the immediate risk is **local**: anyone with
  shell access to this box can sign APKs as snipt. Risk depends on
  threat model:
  - Solo developer machine: low practical risk, high hygiene failure.
  - Shared / laptop: medium risk — anyone who steals the box owns
    the Play signing identity until you revoke the upload key in
    Play Console and re-key.
  - CI without `key.properties` would fall back to debug signing —
    Play Console rejects this for upload, which is good defensive.
  Suggested fixes, in order of preference:
  1. Move secrets to `~/.gradle/gradle.properties` (user-scoped, 600
     perms) and reference them via project property keys. The current
     file can be deleted.
  2. If you keep `key.properties`, restrict it with `chmod 600` (it
     already is, per `stat`) and **separate `keyPassword` from
     `storePassword`** — the current file has the same value for both,
     which is OK in spirit (only you use the keystore) but it's better
     hygiene to keep them distinct and rotated independently.
  3. The committed `key.properties.example` says `storeFile=../snipt-release.jks`
     — same path as the live file. Fine as a template; just make sure
     the live file never gets copied over the example.
- **App lock feature was removed without code review.** v2's
  `sessionUnlockedProvider`, `WidgetsBindingObserver` re-arm logic, and
  the lock screen itself appear to have been deleted between v2 and
  this audit (zero hits in repo). This is correct — the README claim
  was removed in `ed03d85` — but the Security & Privacy score should
  drop the +2 points v2 gave for it. v2's "No PIN/password fallback"
  weakness is also gone (because the feature is gone). Net: lock
  screen is moot until someone re-adds it.
- Fail-open root gate (v2 flag): if settings read fails, the app
  shows history. Documented as a deliberate UX choice. Acceptable.
- No clipboard auto-clear (v2 flag). System clipboard persists; snipt
  has no way to control it. Out of scope.
- `MainActivity.copyImageToClipboard` writes a `SniptCapture` log line
  via `android.util.Log.d/e` containing the file path. In a release
  build these are visible to anyone with `adb logcat`. Mostly harmless
  but logs can be a soft target. Tag is namespaced (`SniptCapture`)
  so an attacker would have to know the app name — fine.

---

## 10. Test Coverage — 6.5/10 ⬆️ *(was 5.0)*

**Strengths**
- Repo test suite grew from 6 to **11 cases**:
  - Capture + URL classification
  - Duplicate collapse + usage bump
  - FTS prefix search + tombstone exclusion
  - Soft-delete + re-capture undelete (undo path)
  - Pin floats + survives prune
  - Free-tier cap prunes oldest non-pinned
  - Pro bypasses cap
  - Image capture persists (type, mediaPath, mimeType, byteSize)
  - Image dedup by path
  - Different images → separate rows
  - Images are not FTS-indexed
- Widget test still passes — confirms first run lands on onboarding
  using a fake settings store.
- Tests run against in-memory `NativeDatabase.memory()`; no
  SQLCipher dependency in test environment, no permission overhead.

**Weaknesses — same as v2, slightly worse**
- Still no widget tests for: history interactions, detail, settings,
  tutorial overlay, or any of the image-clip UX (FAB row, share, save).
- No tests for `ClipType.classify`, `timeAgo`, `formatBytes`,
  `DatabaseKeyManager`, `CaptureBridge`, or the dev Pro toggle.
- Zero Kotlin instrumented tests.
- **No tests for:**
  - The free-tier MEDIA cap (`_enforceMediaSizeCap`)
  - Pinned clip immunity in `_enforceMediaSizeCap`
  - FTS5 input sanitisation edge cases (empty, only-special-chars,
    very long input, unicode)
  - The Flutter-side `captureFromClipboard` path on empty/blank/null
  - `_runRetention` integration (the cold-start path that awaits the
    settings future then prunes)
  - `SettingsController` optimistic-update revert path
  - The `copyImageToClipboard` URI grant mechanism
  - `billingBootstrapProvider` — particularly the "only mirror owned"
    invariant
- The bridge has no fake — `CaptureBridge.register()` calls
  `host.flutterReady()` which throws `MissingPluginException` in
  unit tests. Wrapped in `.catchError` so it doesn't fail, but you
  can't write a test that asserts the bridge actually forwards a
  payload. Consider an interface for `CaptureHostApi` or a
  `setBinaryMessenger` test override.

---

## 11. Code Quality & Documentation — 9.0/10 ⬇️ *(was 9.5)*

**Strengths**
- Every handwritten file has a top-of-file doc comment. Most methods
  explain *why*, not *what*. Easy to navigate.
- `CLAUDE.md` is the architecture reference — accurate as of today.
- `flutter analyze lib test` is clean. 0 issues across ~24 source
  files and the test tree.
- No `print()` left in (only `debugPrint` and `Log.d`/`Log.e` for
  debug/release split).
- Style is consistent: trailing commas, named params, const ctor,
  final locals.
- Generated files correctly committed and excluded from analysis
  scope (lib/data/db/database.g.dart, capture_api.g.dart, etc.).

**Weaknesses**
- **README inconsistency:** README §Features says "Premium UX — Material
  3 with dynamic color", but the codebase has migrated to shadcn/ui
  and explicitly **dropped** dynamic_color (`5fda441`). CLAUDE.md is
  accurate, README is not.
- **pubspec.yaml description is still the default "A new Flutter
  project."** Only the file-level top comment was updated; the
  `description:` block in the package metadata wasn't. Pubspec's
  `description` is what shows on pub.dev and is read by some tooling.
- Dead branch: `settings_screen.dart:227` —
  `Icon(isPro ? LucideIcons.crown : LucideIcons.crown, …)` — both
  branches identical. Lint didn't catch it because the expression is
  type-correct.
- `analysis_options.yaml` still has no custom lint rules (v2 flag).
- `riverpod_generator` still listed but never used (v2 flag).
- The "**App lock with `local_auth` biometrics and device PIN
  fallback**" claim in v2's audit no longer matches reality. The
  feature was removed; the README (correctly, post-`ed03d85`) no
  longer claims it. The privacy policy doesn't claim it. Code
  doesn't have it. Clean removal — but worth noting the v2 audit's
  +2 points for security were partly for a feature that no longer
  exists.
- `android/key.properties.example` uses
  `storeFile=../snipt-release.jks` — a relative path. This is fine
  for local dev but CI would need to inject the absolute path or
  symlink. Document the path expectation.

---

## 12. Build & Configuration — 8.5/10 ⬆️ *(was 8.0)*

**Strengths**
- **Branded app icon now in place** (`73e26ea`). Replaces the default
  Flutter logo on both Android and iOS. Play Store listing no longer
  blocked by the placeholder-icon rejection.
- `allowBackup="false"` and `BILLING` permission declared (`9d1ddae`).
- Release signing template (`android/key.properties.example`) committed
  with a discoverable instructions block — addresses the v2 hard
  blocker, with one footgun (see §9).
- ABI splits scoped to release-only (debug builds a universal APK
  that Flutter tooling expects); `universalApk = true` for last-mile
  sideloads.
- `minSdk = maxOf(24, flutter.minSdkVersion)` — sensible floor, never
  silently regresses.
- `applicationId` aligned with namespace `dev.frostflux.snipt` and
  the iOS / macOS bundle IDs.
- Java 17 target, Kotlin 17 JVM target — modern, matches AGP 8.x.
- `core-ktx:1.13.1` pinned for the `NotificationCompat` and
  `ActivityCompat` helpers used by the foreground service.

**Weaknesses**
- **No `proguard-rules.pro` and no `isMinifyEnabled = true` in
  release.** Without R8/ProGuard rules the release APK ships all of
  Flutter, Drift, Riverpod, shadcn_ui, Pigeon, and `in_app_purchase`.
  A typical Flutter app without R8 minification is **~25–40 % larger**
  than necessary. Critical for Play Store download size budget, less
  critical for correctness because Dart code is AOT anyway.
  Suggested:
  ```kotlin
  buildTypes {
      release {
          isMinifyEnabled = true
          isShrinkResources = true
          proguardFiles(
              getDefaultProguardFile("proguard-android-optimize.txt"),
              "proguard-rules.pro",
          )
          signingConfig = …
      }
  }
  ```
  Plus a minimal `proguard-rules.pro` keeping Flutter classes and any
  reflectively-touched plugin classes (most plugins publish their own
  consumer rules now, so a project-level file is often empty).
- **No CI.** v2 flagged this; still true. The repo has no
  `.github/workflows/` directory. Every change is verified manually.
- **`versionCode` / `versionName` still inherited from pubspec**
  (`1.0.0+1`). v2 flagged this; still true. Play Console will accept
  the first upload but every subsequent upload needs the versionCode
  bumped. Wire it to the build script or document the manual bump.
- `freezed: ^3.2.6-dev.1` and `riverpod_generator: ^4.0.4-dev.1` in
  dev_dependencies — prerelease versions. `freezed` is unused
  (CaptureEvent has only one shape, freezed is overkill for it but
  is already wired). `riverpod_generator` is unused. Either remove
  or adopt.
- The release signing template's `key.properties.example` says
  "The committed keystore + passwords were leaked previously, so
  THIS file must replace them with a fresh keystore." This suggests
  a known prior leak. **If real**: rotate the keystore before
  publishing; Play Console upload-key reset requires generating a
  new upload key, signing a new AAB, and contacting Google support
  to swap. Worth confirming with the team lead before publishing.

---

## 13. Error Handling & Resilience — 8.5/10 ⬇️ *(was 9.0)*

**Strengths**
- `FlutterError.onError` + `runZonedGuarded` (main.dart) catch both
  framework and zone-level errors. `debugPrint` in debug, silent in
  release — appropriate for a no-telemetry privacy-first app.
- `ErrorWidget.builder` in release replaces the red error screen with
  a calm lucide-iconed fallback (app.dart:22-35). Good.
- Settings optimistic update + revert (settings.dart:91-101).
- Root gate fails open to history on settings read error
  (root_gate.dart:31). Deliberate UX choice, documented.
- History error state now uses `EmptyState` widget instead of
  raw `Error: $e` — privacy-respecting and prettier.
- All async UI methods check `mounted` before `setState`/`SnackBar`.
- `CaptureBridge.register()` swallows `MissingPluginException` on
  `flutterReady()` so test environments don't crash.
- `_unlinkMedia` swallows file errors with a comment — best-effort.
- `saveImageToGallery` deletes the just-inserted MediaStore row on
  write failure — no orphan rows.

**Weaknesses**
- **No crash reporting backend.** v2 flag. Release errors are
  silenced; you will not know about user-visible failures unless a
  user emails. For a privacy-first no-telemetry product this is the
  right tradeoff, but the privacy policy should be clear that
  "errors are silently swallowed" — currently it says
  "errors are caught by `runZonedGuarded` and printed to logcat
  only in debug builds. In release builds the error is swallowed
  silently" (§9 in PRIVACY_POLICY.md). That's accurate. Acceptable.
- **No retry logic** for failed database operations. Acceptable for
  local SQLCipher.
- `_toggleService` (settings_screen.dart:45-61) catches and shows a
  SnackBar but **doesn't revert the switch's optimistic visual**
  if the service start fails. v2 flagged this; still true. The
  `_syncServiceState()` call on next screen entry will reconcile,
  but a user looking at the switch mid-failure sees the wrong state.
- `OnboardingScreen._HowItWorks` "Enable capture service" button
  swallows the error (line 60) — user clicks, nothing happens, no
  feedback. Should at least show a SnackBar.
- New failure mode: image pick failure (line 144-148 in
  history_screen.dart) IS handled with a SnackBar. Good.
- New failure mode: gallery save failure path — handled at the
  repository level via `resolver.delete(uri, null, null)`. Good.

---

## 14. Is the App Ready to Publish? — closer, but still NO.

The v2 audit listed 4 hard blockers. Status:

| v2 Hard Blocker | Status |
|---|---|
| Release signing config with real keystore | ⚠️ Template in place; **live file with passwords is on the developer's disk unencrypted**. See §9, §12. |
| Release build validated end-to-end | ❌ `flutter build apk --release` not run in this audit environment. The Kotlin changes since v2 (image-picker pipeline, FileProvider URI grants, MEDIAR-permission reads, `specialUse` FGS with `UPSIDE_DOWN_CAKE` type) need a real APK. |
| Privacy policy URL hosted | ✅ `docs/PRIVACY_POLICY.md` is comprehensive and accurate. Hosting is the publish-step concern, not the content. |
| Default Flutter app icon | ✅ Branded icon now in place (`73e26ea`). |

**New hard blockers discovered by this audit:**
1. **Confirm the keystore status.** The example file's comment implies a
   prior leak. If real, rotate before publishing. (See §12.)
2. **Decide on R8 / ProGuard.** Either enable `isMinifyEnabled = true`
   with a `proguard-rules.pro` (smaller APK, modest risk of runtime
   stripping of reflectively-loaded plugin classes) or document the
   decision to skip. Play Console will accept the larger APK but the
   download-size budget is tighter than it looks.

**New soft blockers:**
- README still says "Material 3 with dynamic color" — fix before
  publishing (3-line edit).
- pubspec description block still says "A new Flutter project." —
  fix before publishing (1-line edit).
- Notification icon is `android.R.drawable.ic_menu_save` — Play
  Store doesn't reject this, but a custom 24×24 white-on-transparent
  silhouette looks better and matches the launcher icon.
- No `onTaskRemoved` / `onTimeout` on `CaptureService`. Rare bite,
  but a UX regression worth a 5-line fix.

**What IS ready:**
- Architecture, data layer, capture engine, state management,
  security model — all production-quality.
- 0 analyzer issues, 12/12 tests, clean git history.
- Privacy model is exemplary for a clipboard app — no `INTERNET`,
  no analytics, no telemetry, encrypted at rest.
- Image-clip feature is well-built end-to-end (capture, dedup,
  share, save, retention).
- shadcn/ui migration is complete and consistent.
- Onboarding is honest about Android's clipboard restriction.

---

## 15. Findings Index (v3 vs v2)

| # | Finding | Severity | Where | v2 status |
|---|---|---|---|---|
| 1 | Release-keystore password in plaintext on developer disk | **HIGH** | `android/key.properties` | missed |
| 2 | `copyImageToClipboard` URI grant via hand-built bundle constant | MED | `MainActivity.kt:251` | new |
| 3 | `settings_screen.dart:227` — `isPro ? crown : crown` | LOW | settings_screen.dart | new |
| 4 | README claims "Material 3 with dynamic color"; codebase is shadcn/ui without dynamic_color | LOW | README.md:14 | new |
| 5 | pubspec description is "A new Flutter project" | LOW | pubspec.yaml:1 | v2 #21 carried |
| 6 | No R8 / ProGuard in release | MED | app/build.gradle.kts | v2 carried |
| 7 | No `onTaskRemoved` / `onTimeout` on CaptureService | LOW | CaptureService.kt | v2 carried |
| 8 | Notification icon is system default | LOW | CaptureService.kt:56 | v2 carried |
| 9 | `riverpod_generator` listed but unused | LOW | pubspec.yaml:70 | v2 carried |
| 10 | Free-tier cap uses `updatedAt`, so reused clips bypass retention | LOW | clip_repository.dart:295 | v2 design |
| 11 | Retention dropdown label says "Keep for N days" but actually means "untouched for N days" | LOW | settings_screen.dart:170, history_screen.dart:113 | new |
| 12 | App lock feature silently removed between v2 and v3; v2 audit points now void | INFO | (removed) | new |
| 13 | `OnboardingScreen` swallows start-service error silently | LOW | onboarding_screen.dart:60 | new |
| 14 | `_toggleService` doesn't visually revert switch on error | LOW | settings_screen.dart:45-61 | v2 carried |
| 15 | No release-build smoke test in this audit environment | INFO | — | v2 carried |
| 16 | `details.single` in tests assumes non-empty list (no defensive checks elsewhere) | LOW | test/clip_repository_test.dart | new |
| 17 | No tests for media-byte cap, FTS sanitisation, dev Pro toggle, billing bootstrap invariant | MED | test/ | v2 carried |
| 18 | No CI / GitHub Actions | LOW | .github/ | v2 carried |

---

## 16. Recommendations (prioritised)

**Before publish (must)**
1. Confirm keystore history. If there was a prior leak, rotate the
   upload key and contact Google Play support to swap.
2. Move `key.properties` out of the project tree (or at minimum
   `chmod 600` and split `storePassword` from `keyPassword`).
3. Fix README "Material 3 with dynamic color" → "shadcn/ui theme".
4. Fix pubspec `description:` block.
5. Add `proguard-rules.pro` and enable `isMinifyEnabled = true`,
   `isShrinkResources = true` in release. Build, install, smoke-test.

**Within the first post-publish sprint (should)**
6. Replace notification icon with a branded 24×24 white-on-transparent.
7. Add `onTimeout` override to `CaptureService` for Android 14+ FGS
   timeout.
8. Add `onTaskRemoved` to either gracefully stop the service or
   transition to a longer-lived background mode.
9. Replace hand-built URI grant constant in `copyImageToClipboard`
   with `Intent.FLAG_GRANT_READ_URI_PERMISSION` resolved at runtime.
10. Expand tests: media-byte cap, FTS sanitisation, billing invariant,
    `ClipActions.copy` happy + failure paths.

**Backlog (nice to have)**
11. Decide: adopt `riverpod_generator` or remove from dev deps.
12. Pagination on history (50-row cap is the longest-standing
    follow-up).
13. Pull-to-refresh from clipboard on the history screen.
14. Detail screen stays put on pin/delete (currently pops).
15. Set up CI (GitHub Actions): `flutter analyze`, `flutter test`,
    `flutter build apk --debug` on PR.

---

## 17. Appendix — Files Inspected

**Handwritten Dart (lib/, 24 files):**
- `main.dart`, `app/app.dart`, `app/router.dart`, `app/theme.dart`
- `core/constants.dart`, `core/format.dart`, `core/haptics.dart`
- `data/providers.dart`, `data/settings.dart`, `data/clip_repository.dart`
- `data/db/database.dart`, `data/db/database_key.dart`
- `data/platform/capture_bridge.dart`, `data/billing/billing_service.dart`,
  `data/billing/billing_providers.dart`
- `domain/models/clip_type.dart`, `domain/models/capture_event.dart`
- `features/root_gate.dart`, `features/onboarding/onboarding_screen.dart`,
  `features/history/history_screen.dart`, `features/history/widgets/clip_tile.dart`,
  `features/history/widgets/skeleton_clip_tile.dart`,
  `features/detail/clip_detail_screen.dart`,
  `features/settings/settings_screen.dart`,
  `features/tutorial/tutorial_overlay.dart`
- `widgets/empty_state.dart`, `widgets/pro_gate.dart`

**Generated Dart (4 files):**
- `lib/data/db/database.g.dart`, `lib/data/platform/capture_api.g.dart`,
- `lib/domain/models/capture_event.g.dart`, `lib/domain/models/capture_event.freezed.dart`

**Pigeon contract (1 file):**
- `pigeons/capture_api.dart`

**Kotlin (4 files):**
- `android/app/src/main/kotlin/dev/frostflux/snipt/MainActivity.kt`
- `android/app/src/main/kotlin/dev/frostflux/snipt/capture/CaptureService.kt`
- `android/app/src/main/kotlin/dev/frostflux/snipt/capture/CaptureTileService.kt`
- `android/app/src/main/kotlin/dev/frostflux/snipt/capture/CaptureApi.g.kt` (generated)

**Android config:**
- `android/app/src/main/AndroidManifest.xml`
- `android/app/src/debug/AndroidManifest.xml`
- `android/app/src/profile/AndroidManifest.xml`
- `android/app/src/main/res/xml/file_paths.xml`
- `android/app/build.gradle.kts`
- `android/key.properties` (live, gitignored)
- `android/key.properties.example` (template)

**Tests (2 files):**
- `test/clip_repository_test.dart` (11 cases)
- `test/widget_test.dart` (1 case)

**Docs:**
- `README.md`, `CLAUDE.md`, `docs/PRIVACY_POLICY.md`,
  `docs/AUDIT_REVIEW.md` (v2), `.gitignore`

**Tooling results:**
- `flutter analyze lib test` → 0 issues
- `flutter test` → 12/12 passing
- `git status` → clean (only `.hermes/` untracked)

---

*This audit was generated by reading every handwritten source file
in the repository, the manifest, the gradle config, the live
(but gitignored) `key.properties`, the prior audit, and the
privacy policy; by running `flutter analyze lib test` and
`flutter test`; and by comparing the result against the v2
audit to detect regressions and missed findings. No secrets
have been written to this file or anywhere else.*