# Image Copy & Save Implementation Plan

> **For Hermes:** Use subagent-driven-development skill to implement this plan task-by-task. TDD where it makes sense (Pigeon + repository unit tests); no widget tests in this phase (UI rendering will be visually validated at the end).

**Goal:** Extend snipt so users can capture, store, list, preview, copy-to-system-clipboard, and save-to-gallery image clips alongside text clips, without breaking the existing text pipeline or the Android 10+ capture constraint.

**Architecture:** Extend the same lane-B capture surface (share-sheet target + in-app picker) that text already uses; persist images as files in `filesDir/media/<uuid>.<ext>` referenced by a new `media_path` column; gate UI through a single new `ImageActions` API; route "copy image" and "save to gallery" through new native methods on the Pigeon channel (because Flutter's `Clipboard` doesn't carry images and MediaStore writes must be native). Keep text path completely untouched; new columns are nullable so the v1 schema still works.

**Tech Stack:** Flutter 3.44 / Dart 3.12 · Drift 2.33 + sqlite3 · Pigeon 26 · freezed 3 · Riverpod 3 · existing `share_plus` for outbound share · `image` package (optional, only for EXIF orientation on insert) · `path_provider` (already present) · `crypto` (already present) · Kotlin stdlib for ContentResolver + MediaStore.

---

## Constraint reminder (do not violate)

Android 10+ (API 29) blocks background clipboard reads of **any** MIME type — image capture cannot be silent/automatic. Lane B only: share-sheet target (image/* added) + in-app picker + tile. The doc updates and any UI copy must not promise automatic image capture.

---

## Files likely to change

Create:
- `lib/features/detail/widgets/image_preview.dart` — full-bleed preview + copy/save/share actions.
- `lib/features/history/widgets/image_clip_tile.dart` — thumbnail list tile.
- `test/data/image_clip_repository_test.dart` — captureImage / dedup / delete-unlink / size-cap unit tests.
- `test/data/capture_payload_test.dart` — Pigeon contract round-trip sanity (existing test layout extended, not strictly required, optional).

Modify:
- `pigeons/capture_api.dart` — add `MediaPayload` class + extend `CapturePayload` with optional media fields + add `copyImageToClipboard(path)` and `saveImageToGallery(path, mimeType)` host methods.
- `lib/data/platform/capture_api.g.dart` — regenerated.
- `android/app/src/main/kotlin/com/example/snipt/capture/CaptureApi.g.kt` — regenerated.
- `android/app/src/main/kotlin/com/example/snipt/MainActivity.kt` — handle `ACTION_SEND` image branch (stream URI to filesDir/media/), implement `copyImageToClipboard` + `saveImageToGallery`, request `WRITE_EXTERNAL_STORAGE` only when API <= 28.
- `android/app/src/main/AndroidManifest.xml` — add `image/*` intent-filter; add `READ_MEDIA_IMAGES` (API 33+) / `WRITE_EXTERNAL_STORAGE` (API <= 28) permissions; declare `FileProvider` so we can share back the saved file (optional, see Task 12).
- `lib/data/db/database.dart` — bump schemaVersion to 2, add `mediaPath` + `mimeType` columns, add onUpgrade migration, regen.
- `lib/data/db/database.g.dart` — regenerated.
- `lib/domain/models/clip_type.dart` — append `image` enum value.
- `lib/domain/models/capture_event.dart` — add optional `mediaPath` + `mimeType` fields (freezed).
- `lib/data/clip_repository.dart` — add `captureImage(...)`, unlink-on-delete in softDelete/prune, size-based cap for media (separate budget from text cap), image-aware dedup keyed on `(mediaPath)`.
- `lib/data/providers.dart` — wire `ClipActions` image methods + image picker hookup.
- `lib/features/detail/detail_screen.dart` — branch on `clip.type == ClipType.image`, render `ImagePreview` instead of text.
- `lib/features/history/history_screen.dart` — branch on `clip.type == ClipType.image`, render `ImageClipTile`.
- `lib/features/settings/settings_screen.dart` — show media-storage usage + a "Clear media cache" action.
- `pubspec.yaml` — add `image_picker: ^1.1.2` (in-app capture path) — already considered, included.

---

## Step-by-step plan

### Phase A — Domain & storage model

#### Task 1: Extend `ClipType` enum

**Files:**
- Modify: `lib/domain/models/clip_type.dart:3`

**Step 1.** Append `image` to the enum. The `classify(String)` helper stays text-only; image rows bypass it.

```dart
enum ClipType {
  text,
  url,
  richText,
  image;
  // ...existing classify stays unchanged...
}
```

**Step 2.** Run `flutter analyze lib`. Expected: passes (no callers iterate over the enum exhaustively with an `if/switch` that would emit "missing case" warnings — verify by grepping `case ClipType.`).

**Step 3.** Commit: `git add lib/domain/models/clip_type.dart && git commit -m "feat(image): add ClipType.image enum value"`.

---

#### Task 2: Extend `CaptureEvent` (freezed)

**Files:**
- Modify: `lib/domain/models/capture_event.dart` (add two optional fields + ctor param).

**Step 1.** Add `String? mediaPath` and `String? mimeType` to the freezed class. Default to `null`. Mark `content` default to `''` when only `mediaPath` is supplied.

```dart
@freezed
class CaptureEvent with _$CaptureEvent {
  const factory CaptureEvent({
    @Default('') String content,
    String? sourceApp,
    String? mediaPath,
    String? mimeType,
  }) = _CaptureEvent;
}
```

**Step 2.** Run `dart run build_runner build --delete-conflicting-outputs`. Expected: freezed regenerates `capture_event.freezed.dart` with new fields; no errors.

**Step 3.** Commit: `git add lib/domain/models/capture_event.dart lib/domain/models/capture_event.freezed.dart && git commit -m "feat(image): extend CaptureEvent with mediaPath + mimeType"`.

---

#### Task 3: Drift schema — add `mediaPath` + `mimeType`, bump to v2

**Files:**
- Modify: `lib/data/db/database.dart:18` (`Clips` table) and `:46` (migration).

**Step 1.** Add two nullable columns to `Clips`:

```dart
TextColumn get mediaPath => text().nullable()();
TextColumn get mimeType => text().nullable()();
```

**Step 2.** Bump schemaVersion to `2` and add an `onUpgrade` that runs `m.addColumn(clips, clips.mediaPath)` then `m.addColumn(clips, clips.mimeType)` for users on v1. Wrap with `if (from < 2)`.

```dart
@override
int get schemaVersion => 2;

@override
MigrationStrategy get migration => MigrationStrategy(
      onCreate: (m) async { /* unchanged */ },
      onUpgrade: (m, from, to) async {
        if (from < 2) {
          await m.addColumn(clips, clips.mediaPath);
          await m.addColumn(clips, clips.mimeType);
        }
      },
    );
```

**Step 3.** Run `dart run build_runner build --delete-conflicting-outputs`. Expected: `database.g.dart` regenerates with the two new columns on the `Clip` row class.

**Step 4.** Commit: `git add lib/data/db/database.dart lib/data/db/database.g.dart && git commit -m "feat(db): add mediaPath + mimeType columns, schema v2"`.

---

### Phase B — Pigeon contract + native channels

#### Task 4: Extend Pigeon contract

**Files:**
- Modify: `pigeons/capture_api.dart:17` (CapturePayload) and `:26` (CaptureHostApi).

**Step 1.** Add optional media fields to `CapturePayload`:

```dart
class CapturePayload {
  CapturePayload(
    this.content,
    this.source,
    this.sourceApp, {
    this.mediaPath,
    this.mimeType,
  });
  String content;
  CaptureSourceDto source;
  String? sourceApp;
  String? mediaPath;
  String? mimeType;
}
```

**Step 2.** Add two new host methods:

```dart
/// Streams the file at [mediaPath] into the system clipboard as an image.
/// Returns false if the file is missing or the OS rejects it.
bool copyImageToClipboard(String mediaPath);

/// Saves the image at [mediaPath] to the user's gallery via MediaStore
/// (scoped storage on API 29+). Returns the public URI on success, null on
/// failure (e.g. permission denied).
String? saveImageToGallery(String mediaPath, String mimeType);
```

**Step 3.** Run `dart run pigeon --input pigeons/capture_api.dart`. Expected: `capture_api.g.dart` and `CaptureApi.g.kt` regenerate. Verify both files exist and contain the new method signatures.

**Step 4.** Commit: `git add pigeons/capture_api.dart lib/data/platform/capture_api.g.dart android/app/src/main/kotlin/com/example/snipt/capture/CaptureApi.g.kt && git commit -m "feat(pigeon): add media fields + copy/save host methods"`.

---

#### Task 5: Native — manifest updates (intent-filter + permissions)

**Files:**
- Modify: `android/app/src/main/AndroidManifest.xml:34` (SEND filter) and `:3` (permissions).

**Step 1.** Add a second SEND intent-filter for images, alongside the existing text one (Android only lets one filter declare a given action on a single activity if you scope by mimeType — keep them as two `<intent-filter>` blocks):

```xml
<!-- "Share to snipt" image capture path. -->
<intent-filter>
    <action android:name="android.intent.action.SEND"/>
    <category android:name="android.intent.category.DEFAULT"/>
    <data android:mimeType="image/*"/>
</intent-filter>
```

**Step 2.** Add the save-to-gallery permissions:

```xml
<!-- API 33+ scoped media read/write. -->
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />
<!-- Pre-Q legacy storage write. -->
<uses-permission
    android:name="android.permission.WRITE_EXTERNAL_STORAGE"
    android:maxSdkVersion="28" />
```

(Scoped storage on Q+ means we don't need WRITE_EXTERNAL_STORAGE; MediaStore writes through ContentResolver on the app's own behalf don't require it. The pre-Q permission is only needed if we support API <= 28 — confirm against `android/app/build.gradle.kts` `minSdk`; per CLAUDE.md it's floored to 24, so include it.)

**Step 3.** Commit: `git add android/app/src/main/AndroidManifest.xml && git commit -m "feat(android): accept image shares; add gallery-write perms"`.

---

#### Task 6: Native — MainActivity image-share handler

**Files:**
- Modify: `android/app/src/main/kotlin/com/example/snipt/MainActivity.kt:84` (`handleIntent`).

**Step 1.** Branch the `ACTION_SEND` handler on `intent.type`. If the type starts with `image/`, stream the URI into `filesDir/media/<uuid>.<ext>` and dispatch a `CapturePayload` with `mediaPath` set; otherwise fall through to the existing text path.

```kotlin
Intent.ACTION_SEND -> {
    val type = intent.type
    when {
        type != null && type.startsWith("image/") -> {
            val uri = intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM) ?: return
            val savedPath = copyImageToInternal(uri, type) ?: return
            dispatch(
                CapturePayload(
                    content = "",
                    source = CaptureSourceDto.SHARE,
                    sourceApp = null,
                    mediaPath = savedPath,
                    mimeType = type,
                )
            )
        }
        else -> {
            val text = intent.getStringExtra(Intent.EXTRA_TEXT)
            if (!text.isNullOrBlank()) {
                dispatch(CapturePayload(text, CaptureSourceDto.SHARE, null))
            }
        }
    }
}
```

**Step 2.** Add the helper that streams the URI into `filesDir/media/<uuid>.<ext>`. Use `contentResolver.openInputStream` — never Bitmap-decode a large camera-roll photo in memory. Cap the streamed size at e.g. 25 MB to prevent abuse.

```kotlin
private fun copyImageToInternal(uri: Uri, mime: String): String? {
    val ext = when (mime) {
        "image/png" -> "png"
        "image/webp" -> "webp"
        "image/gif" -> "gif"
        else -> "jpg"
    }
    val outFile = File(filesDir, "media/${UUID.randomUUID()}.$ext")
    outFile.parentFile?.mkdirs()
    return try {
        contentResolver.openInputStream(uri)?.use { input ->
            outFile.outputStream().use { output ->
                input.copyTo(output, bufferSize = 64 * 1024)
            }
        }
        outFile.absolutePath
    } catch (e: Exception) {
        null
    }
}
```

**Step 3.** Verify Kotlin compiles by building the debug APK: `flutter build apk --debug`. Expected: build succeeds; no Kotlin errors. (This is the only way to validate the Kotlin here per CLAUDE.md.)

**Step 4.** Commit: `git add android/app/src/main/kotlin/com/example/snipt/MainActivity.kt && git commit -m "feat(android): stream shared images into filesDir/media"`.

---

#### Task 7: Native — implement `copyImageToClipboard` + `saveImageToGallery`

**Files:**
- Modify: `android/app/src/main/kotlin/com/example/snipt/MainActivity.kt` (extend the `// region CaptureHostApi` block).

**Step 1.** Implement `copyImageToClipboard`. This requires a `FileProvider` URI since Android Q+ rejects `file://` URIs in ClipData; declare it in the manifest (Task 8), then build the URI here.

```kotlin
override fun copyImageToClipboard(mediaPath: String): Boolean {
    val file = File(mediaPath)
    if (!file.exists()) return false
    val authority = "$packageName.fileprovider"
    val uri: Uri = FileProvider.getUriForFile(this, authority, file)
    val clip = ClipData.newUri(contentResolver, "snipt-image", uri)
    val cm = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
    cm.setPrimaryClip(clip)
    return true
}
```

**Step 2.** Implement `saveImageToGallery`. Use `MediaStore.Images` and the `RELATIVE_PATH` column to land the image in `Pictures/snipt/`. Returns the public URI string or null.

```kotlin
override fun saveImageToGallery(mediaPath: String, mimeType: String): String? {
    val file = File(mediaPath)
    if (!file.exists()) return null
    val values = ContentValues().apply {
        put(MediaStore.Images.Media.DISPLAY_NAME, file.name)
        put(MediaStore.Images.Media.MIME_TYPE, mimeType)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            put(MediaStore.Images.Media.RELATIVE_PATH, "Pictures/snipt")
            put(MediaStore.Images.Media.IS_PENDING, 1)
        }
    }
    val resolver = contentResolver
    val collection = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
        MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
    } else {
        MediaStore.Images.Media.EXTERNAL_CONTENT_URI
    }
    val uri = resolver.insert(collection, values) ?: return null
    return try {
        resolver.openOutputStream(uri)?.use { out -> file.inputStream().use { it.copyTo(out) } }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            values.clear()
            values.put(MediaStore.Images.Media.IS_PENDING, 0)
            resolver.update(uri, values, null, null)
        }
        uri.toString()
    } catch (e: Exception) {
        resolver.delete(uri, null, null)
        null
    }
}
```

**Step 3.** Build: `flutter build apk --debug`. Expected: compile succeeds. Errors here will be Kotlin import or API-level gating issues — fix immediately.

**Step 4.** Commit: `git add android/app/src/main/kotlin/com/example/snipt/MainActivity.kt && git commit -m "feat(android): implement image copy + save-to-gallery"`.

---

#### Task 8: Android — FileProvider for `copyImageToClipboard`

**Files:**
- Modify: `android/app/src/main/AndroidManifest.xml` (add provider inside `<application>`).
- Create: `android/app/src/main/res/xml/file_paths.xml`.

**Step 1.** Declare the FileProvider:

```xml
<provider
    android:name="androidx.core.content.FileProvider"
    android:authorities="${applicationId}.fileprovider"
    android:exported="false"
    android:grantUriPermissions="true">
    <meta-data
        android:name="android.support.FILE_PROVIDER_PATHS"
        android:resource="@xml/file_paths" />
</provider>
```

**Step 2.** Create `file_paths.xml` allowing access to `filesDir/media/`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<paths>
    <files-path name="media" path="media/" />
</paths>
```

**Step 3.** Build: `flutter build apk --debug`. Expected: provider registered without conflict.

**Step 4.** Commit: `git add android/app/src/main/AndroidManifest.xml android/app/src/main/res/xml/file_paths.xml && git commit -m "feat(android): FileProvider for clipboard image URIs"`.

---

### Phase C — Repository & dedup

#### Task 9: Repository — `captureImage` + size-cap + unlink-on-delete

**Files:**
- Modify: `lib/data/clip_repository.dart` (new public methods + helpers).

**Step 1.** Add a `captureImage` method. Dedup keyed on the file path's SHA-256 (so re-sharing the same photo doesn't double up). On insert, store a hash of the absolute path. Image rows have empty `content`, so FTS isn't touched.

```dart
Future<Clip> captureImage({
  required String mediaPath,
  required String mimeType,
  String? sourceApp,
}) async {
  final hash = sha256.convert(utf8.encode('image:$mediaPath')).toString();
  final now = DateTime.now();
  final size = await File(mediaPath).length();

  return _db.transaction(() async {
    final existing = await (_db.select(_db.clips)
          ..where((t) => t.contentHash.equals(hash)))
        .getSingleOrNull();
    if (existing != null) {
      final refreshed = existing.copyWith(
        updatedAt: now,
        usageCount: existing.usageCount + 1,
        deletedAt: const Value(null),
      );
      await _db.update(_db.clips).replace(refreshed);
      return refreshed;
    }

    if (!isProSupplier()) {
      await _enforceMediaSizeCap(size);
    }

    final clip = Clip(
      id: _uuid.v4(),
      type: ClipType.image,
      content: '',
      contentHash: hash,
      byteSize: size,
      isPinned: false,
      sourceApp: sourceApp,
      usageCount: 1,
      createdAt: now,
      updatedAt: now,
      deletedAt: null,
      mediaPath: mediaPath,
      mimeType: mimeType,
    );
    await _db.into(_db.clips).insert(clip);
    return clip;
  });
}
```

**Step 2.** Add `_enforceMediaSizeCap(int incomingBytes)` — drops the oldest non-pinned, non-tombstoned image rows (and unlinks their files) until total media bytes + incoming fits inside `AppConstants.freeTierMediaBytes`. Add the constant in `lib/core/constants.dart`:

```dart
static const int freeTierMediaBytes = 200 * 1024 * 1024; // 200 MB
```

**Step 3.** Modify `softDelete` and `prune` to unlink `mediaPath` files when their row is hard-deleted. Both methods currently leave files on disk; extract a helper `_unlinkMedia(String? path)` and call it after the DB delete.

**Step 4.** Modify the `_hash` helper to keep working for both: the existing text hash stays; image rows never go through `_hash` — they hash their own way in `captureImage`.

**Step 5.** Commit: `git add lib/data/clip_repository.dart lib/core/constants.dart && git commit -m "feat(repo): image capture, dedup, size cap, file unlink"`.

---

#### Task 10: Repository — tests (TDD)

**Files:**
- Create: `test/data/image_clip_repository_test.dart`

**Step 1.** Write tests that:
- Insert an image with a real temp file → row has `mediaPath`, `mimeType`, empty `content`, `type == ClipType.image`.
- Re-capture the same path → returns the existing row with `usageCount` incremented, no second row.
- `softDelete` on an image row → file is unlinked from disk.
- Capture 3 images totalling > free-tier cap → oldest non-pinned file is unlinked; pinned files survive.
- Capture a text clip after image work still works (regression).

Use `AppDatabase.forTesting(NativeDatabase.memory())` and temp files under `Directory.systemTemp.createTempSync()`.

**Step 2.** Run: `flutter test test/data/image_clip_repository_test.dart`. Expected: all pass.

**Step 3.** Commit: `git add test/data/image_clip_repository_test.dart && git commit -m "test(repo): image capture, dedup, unlink, size cap"`.

---

### Phase D — UI

#### Task 11: Image tile + preview widgets

**Files:**
- Create: `lib/features/history/widgets/image_clip_tile.dart`
- Create: `lib/features/detail/widgets/image_preview.dart`

**Step 1.** `ImageClipTile` — `ListTile`-shaped widget: `Image.file(File(clip.mediaPath!), fit: BoxFit.cover, cacheWidth: 256)` (cacheWidth keeps memory bounded for lists), truncated filename underneath. Uses theme `colorScheme.surfaceContainerHighest` as placeholder while loading.

**Step 2.** `ImagePreview` — `InteractiveViewer` wrapping `Image.file(File(clip.mediaPath!))`. Below it, an action row with three buttons:
- "Copy" → `CaptureBridge.copyImageToClipboard(clip.mediaPath!)`
- "Save" → `CaptureBridge.saveImageToGallery(clip.mediaPath!, clip.mimeType ?? 'image/jpeg')`; on success show snackbar `Saved to Pictures/snipt/`.
- "Share" → `Share.shareXFiles([XFile(clip.mediaPath!)])` (already in deps via share_plus).

**Step 3.** Commit: `git add lib/features/history/widgets/image_clip_tile.dart lib/features/detail/widgets/image_preview.dart && git commit -m "feat(ui): image tile + preview with copy/save/share"`.

---

#### Task 12: Wire widgets into history + detail screens

**Files:**
- Modify: `lib/features/history/history_screen.dart`
- Modify: `lib/features/detail/detail_screen.dart`

**Step 1.** In the history list, branch on `clip.type`:
- `ClipType.image` → `ImageClipTile(clip: clip)`
- else → existing text tile

**Step 2.** In detail, branch on `clip.type`:
- `ClipType.image` → `ImagePreview(clip: clip)`
- else → existing text view

Both screens already render via the `ClipActions` interface — no changes to providers needed for the widget swap. New actions for image clips will be added in Task 13.

**Step 3.** Commit: `git add lib/features/history/history_screen.dart lib/features/detail/detail_screen.dart && git commit -m "feat(ui): branch history/detail on clip type"`.

---

#### Task 13: `ClipActions` — image methods

**Files:**
- Modify: `lib/data/providers.dart` (extend `ClipActions`).

**Step 1.** Add two methods:

```dart
Future<bool> copyImage(Clip clip) =>
    CaptureBridge.instance.copyImageToClipboard(clip.mediaPath!);

Future<String?> saveImage(Clip clip) =>
    CaptureBridge.instance.saveImageToGallery(
      clip.mediaPath!,
      clip.mimeType ?? 'image/jpeg',
    );
```

These mirror the existing `copyText` / `shareText` pattern.

**Step 2.** Commit: `git add lib/data/providers.dart && git commit -m "feat(actions): image copy + save methods"`.

---

### Phase E — In-app capture path

#### Task 14: Image picker (lane B inside the app)

**Files:**
- Modify: `pubspec.yaml`
- Modify: `lib/features/history/history_screen.dart` (FAB → picker when no text present)

**Step 1.** Add `image_picker: ^1.1.2` to `pubspec.yaml`. Run `flutter pub get`.

**Step 2.** Add a second FAB or replace the existing one (TBD by UX) that opens `ImagePicker().pickImage(source: ImageSource.gallery)`. On selection, copy the picked file into `filesDir/media/<uuid>.<ext>` via a new `CaptureBridge.importImageFromPath(srcPath, mime)` host method, then call `ClipRepository.captureImage`. This keeps image paths inside `filesDir/media/` so the gallery file can be deleted after import without orphaning our copy.

**Step 3.** Build: `flutter build apk --debug`. Expected: compiles.

**Step 4.** Commit: `git add pubspec.yaml pubspec.lock lib/features/history/history_screen.dart && git commit -m "feat(capture): in-app image picker (gallery source)"`.

---

### Phase F — Validation

#### Task 15: Full static + build + runtime smoke

**Step 1.** `flutter analyze lib test` → expected: no errors.

**Step 2.** `flutter test` → expected: all green, including the new image tests.

**Step 3.** `flutter build apk --debug` → expected: clean build; this is the only validation that the Kotlin compiles.

**Step 4.** Run on an emulator (per your usual workflow — runtime smoke is mandatory, not optional):
- Cold-start share an image from Chrome → check history shows thumbnail, detail opens full-bleed, "Copy" returns true, "Save" lands a file in `Pictures/snipt/`.
- Save → close app → reopen → file persists; row survives a process kill.
- Capture the same image twice → row count unchanged, `usageCount` is 2.
- Soft-delete an image row → file is unlinked from `filesDir/media/`.

**Step 5.** Commit any final fixes; tag the phase as done.

---

## Open questions to confirm before/while implementing

1. **Save-to-gallery folder name.** Plan uses `Pictures/snipt/`. If you want `Pictures/Snipt/` or `DCIM/snipt/`, say so before Task 7.
2. **In-app capture source.** Plan adds `ImageSource.gallery` only. Camera capture (PROCESS_IMAGE intent or `ImageSource.camera`) is out of scope — confirm or extend.
3. **Free-tier media cap.** 200 MB is a starting number. If you have a different target, edit `freeTierMediaBytes` in `lib/core/constants.dart` before Task 9.
4. **Multiple images (`SEND_MULTIPLE`).** Not in this plan. Most users share one image at a time; multi-select can be a follow-up phase if you want it.
5. **EXIF orientation.** The plan does NOT rotate on import. If you want camera-roll photos to display upright, add an `image` package call in Task 11 to read `ExifInterface` orientation and pass `rotate`/`flip` to `Image.file`. Tell me to include it.

---

## Risks / tradeoffs

- **Disk usage.** A 200 MB cap is a soft budget. Pinned images bypass the cap, so a Pro user could pile up arbitrarily. If you want a hard ceiling, add a separate `AppConstants.maxMediaBytes` and enforce it after insertion too.
- **O(N) free-tier prune.** The current cap enforcement scans + deletes on every non-Pro image capture. For images specifically, sort by `updatedAt` and unlink in one transaction; it stays O(small) because we only loop until the budget fits.
- **FileProvider authority collisions.** Using `${applicationId}.fileprovider` is the safe default; if you've ever declared a custom provider authority for share_plus, check for collision.
- **EXIF.** As noted, plan leaves orientation alone. Camera-roll JPEGs from modern Android phones display correctly in `Image.file`, so most users won't notice. If you see sideways screenshots, add the EXIF step.
- **No background auto-capture.** Hard constraint, restated so it doesn't get hand-waved away in implementation. Lane B only.