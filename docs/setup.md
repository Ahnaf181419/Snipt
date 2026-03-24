# Snipt Setup Guide

## Prerequisites

- **Flutter SDK**: 3.27.4 (stable channel)
- **Dart SDK**: ^3.10.7
- **Java**: 17+ (for Android builds)
- **Android SDK**: Latest stable version
- **Android Gradle Plugin**: Compatible version (auto-resolved)

## Environment Setup

### 1. Clone the Repository

```bash
git clone https://github.com/your-org/snipt.git
cd snipt
```

### 2. Install Dependencies

```bash
flutter pub get
```

### 3. Environment Variables

Create a `.env` file based on `.env.example`:

```env
# Sentry DSN (optional for local development)
# Get your DSN from: https://sentry.io/settings/<org>/projects/<project>/keys/
SENTRY_DSN=

# Environment: production, staging, development
ENVIRONMENT=development
```

**Note**: For local development without Sentry, leave `SENTRY_DSN` empty. The app will still function normally.

### 4. Android Keystore (For Release Builds)

For release builds, you need a keystore file. If building locally:

**Option A: Use the existing keystore**
Place `snipt-release.jks` in `android/app/` and create `android/key.properties`:

```properties
storePassword=your_store_password
keyPassword=your_key_password
keyAlias=snipt
storeFile=snipt-release.jks
```

**Option B: Generate a new keystore**
```bash
keytool -genkey -v -keystore android/app/snipt-release.jks -alias snipt -keyalg RSA -keysize 4096 -validity 10000
```

## Development

### Running the App

```bash
# Debug build (no Sentry)
flutter run

# Debug build with Sentry
flutter run --dart-define=SENTRY_DSN=your_dsn_here

# Release build (requires keystore)
flutter build apk --release
```

### Running Tests

```bash
# All tests
flutter test

# Unit and widget tests only
flutter test test/

# Integration tests
flutter test integration_test/

# With coverage (requires coverage package)
flutter test --coverage
```

### Code Analysis

```bash
# Static analysis
flutter analyze

# Fix auto-fixable issues
flutter analyze --fix
```

## Building

### Debug APK
```bash
flutter build apk --debug
```

Output: `build/app/outputs/flutter-apk/app-debug.apk`

### Release APK
```bash
flutter build apk --release
```

Output: `build/app/outputs/flutter-apk/app-release.apk`

### Build with Custom Environment
```bash
flutter build apk --release \
  --dart-define=SENTRY_DSN=your_dsn \
  --dart-define=ENVIRONMENT=production
```

## CI/CD Setup

### GitHub Actions

The project includes a CI workflow at `.github/workflows/ci.yml` that runs:

1. **Flutter Analyze** - Static code analysis
2. **Unit & Widget Tests** - 57 tests
3. **Integration Tests** - E2E testing
4. **Debug APK Build** - Artifact for PRs
5. **Release APK Build** - Artifact for main branch

### Required Secrets

Configure these in GitHub repository settings → Secrets:

| Secret | Description |
|--------|-------------|
| `SENTRY_DSN` | Sentry error tracking DSN |
| `KEY_STORE_PASSWORD` | Keystore password |
| `KEY_PASSWORD` | Key password |
| `KEY_ALIAS` | Key alias (snipt) |
| `KEY_STORE_FILE` | Base64-encoded keystore file |

### Base64 Encoding Keystore

```bash
# Linux/macOS
base64 -i android/app/snipt-release.jks | tr -d '\n'

# Windows (PowerShell)
[Convert]::ToBase64String([IO.File]::ReadAllBytes("android\app\snipt-release.jks")) -replace '\s+'
```

## Project Structure

```
snipt/
├── android/              # Android native configuration
├── lib/                  # Flutter app code
│   ├── core/            # Constants, theme, utilities
│   ├── data/            # Database, models, repository impl
│   ├── domain/          # Entities, repository interfaces, use cases
│   ├── presentation/    # UI, BLoC, screens, widgets
│   └── services/        # Background services
├── test/                # Unit and widget tests
├── integration_test/     # Integration tests
├── docs/               # Documentation
├── .env.example        # Environment template
├── pubspec.yaml        # Dependencies
└── README.md           # Project overview
```

## Common Issues

### 1. Flutter Analyze Fails

**Issue**: `flutter analyze` reports errors.

**Solution**: 
```bash
flutter pub get
flutter analyze
```

### 2. Tests Fail

**Issue**: Mocktail or bloc_test errors.

**Solution**: Ensure all test dependencies are installed:
```bash
flutter pub get
flutter test
```

### 3. Release Build Fails

**Issue**: Missing keystore or wrong credentials.

**Solution**: Verify `android/key.properties` exists and has correct values.

### 4. Sentry DSN Not Found

**Issue**: Warning about missing DSN.

**Solution**: This is expected if SENTRY_DSN is empty. The app functions normally without Sentry.

## Feature Flags

| Feature | Status | Notes |
|---------|--------|-------|
| Clipboard Monitoring | ✅ | Works in foreground and background |
| Category Detection | ✅ | Auto-detects URL, phone, text, image |
| Bookmarking | ✅ | Swipe actions and tap to copy |
| Search | ✅ | 300ms debounced search |
| Background Service | ✅ | 5-second polling interval |
| Data Export | ✅ | JSON format via Share sheet |
| Sentry Integration | ✅ | Configured via environment |

## License

MIT License - See LICENSE file for details.
