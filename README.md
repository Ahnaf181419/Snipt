# snipt

A local-first, privacy-focused clipboard history manager for Android.

Capture text you copy, search through it, pin what matters, and reuse it later. Everything stays on your device, encrypted at rest with SQLCipher.

## Features

- **Clipboard history** - Never lose something you copied. Every captured clip is searchable, pinnable, and reusable.
- **Encrypted storage** - All clips are stored in a SQLCipher-encrypted database. The key lives in the Android Keystore. No cloud, no sync, no tracking.
- **Quick capture** - Tap the Capture button, use the Quick Settings tile, or share text from any app.
- **Full-text search** - Find any clip instantly with FTS5-powered search.
- **App lock** - Optional biometric/PIN lock that re-arms when you leave the app.
- **Auto-cleanup** - Configurable retention period (default 30 days) to keep your history tidy.
- **Premium UX** - Material 3 with dynamic color, skeleton loading, haptic feedback, and smooth animations.
- **Battery efficient** - No background polling. Capture happens on your terms.

## Privacy

snipt is built privacy-first:

- **No internet permission.** The app has zero network access. Your clips never leave the device.
- **Encrypted at rest.** The database is SQLCipher-encrypted with a key stored in the Android Keystore.
- **No analytics.** No crash reporting SDKs, no tracking, no telemetry.

## Getting Started

```bash
flutter pub get
dart run build_runner build    # regenerate Drift + freezed
flutter analyze lib test
flutter test
flutter build apk --debug      # or --release with a signing key
```

## Tech Stack

Flutter 3.44 / Dart 3.12, Riverpod 3, Drift 2.33 + SQLCipher, Pigeon 26, Material 3 with dynamic color.

## Architecture

Feature-first layers. Capture is native Kotlin (foreground service + Quick Settings tile); Flutter handles the UI and storage.

See [docs/AUDIT_REVIEW.md](docs/AUDIT_REVIEW.md) for a full architecture breakdown.

## License

All rights reserved.
