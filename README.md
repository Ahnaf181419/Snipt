# Snipt - Clipboard Manager for Android

A production-ready Android clipboard manager app built with Flutter, featuring background clipboard monitoring, bookmarking, search, and automatic category detection.

## Features

- **Clipboard Monitoring**: Automatically captures clipboard content when the app is running or in background
- **Category Detection**: Automatically categorizes clipboard content (Text, URL, Phone, Image)
- **Bookmarking**: Save important clipboard items for quick access
- **Search**: Full-text search across all clipboard history with debouncing
- **Background Service**: Continues capturing clipboard even when app is closed
- **Data Export**: Export clipboard history as JSON
- **Storage Management**: Configurable storage limit for clipboard items
- **Dark Theme**: Modern dark UI with Material Design 3

## Architecture

```
lib/
├── core/                    # Core utilities and constants
│   ├── constants/          # App strings and colors
│   └── theme/              # App theme configuration
├── data/                   # Data layer
│   ├── datasources/        # Local SQLite database
│   ├── models/             # Data models
│   └── repositories/       # Repository implementations
├── domain/                 # Domain layer
│   ├── entities/           # Business entities
│   ├── repositories/       # Repository interfaces
│   └── use_cases/          # Business logic use cases
├── presentation/           # Presentation layer
│   ├── bloc/               # BLoC state management
│   ├── screens/            # App screens
│   └── widgets/            # Reusable widgets
├── services/               # Background services
├── app.dart               # App configuration
└── main.dart              # Entry point
```

## Tech Stack

- **Framework**: Flutter 3.27.4
- **State Management**: BLoC (Business Logic Component)
- **Database**: SQLite via sqflite
- **Background Processing**: flutter_background_service
- **Error Tracking**: Sentry
- **Testing**: bloc_test, mocktail, integration_test

## Getting Started

### Prerequisites

- Flutter SDK 3.27.4+
- Android SDK
- Java 17+

### Installation

1. Clone the repository
2. Install dependencies:
   ```bash
   flutter pub get
   ```
3. Run the app:
   ```bash
   flutter run
   ```

### Building

**Debug APK:**
```bash
flutter build apk --debug
```

**Release APK:**
```bash
flutter build apk --release
```

## Configuration

### Environment Variables

Create a `.env` file based on `.env.example`:

```env
SENTRY_DSN=your_sentry_dsn_here
ENVIRONMENT=production
```

### Release Signing

Configure your keystore in `android/key.properties`:

```properties
storePassword=your_store_password
keyPassword=your_key_password
keyAlias=your_key_alias
storeFile=your_keystore_path
```

## Testing

```bash
# Unit and widget tests
flutter test

# Integration tests
flutter test integration_test
```

## CI/CD

The project includes GitHub Actions workflows for:

- Flutter analyze
- Unit and widget tests
- Integration tests
- Debug and release APK builds

Configure the following secrets in your GitHub repository:
- `SENTRY_DSN`: Your Sentry DSN for error tracking
- `KEY_STORE_PASSWORD`: Keystore password
- `KEY_PASSWORD`: Key password
- `KEY_ALIAS`: Key alias
- `KEY_STORE_FILE`: Base64 encoded keystore file

## Screenshots

The app features three main screens:

1. **Recent**: Browse and search clipboard history
2. **Bookmarks**: Access saved clipboard items
3. **Settings**: Configure storage limit, export data, manage background capture

## Documentation

Detailed documentation is available in the `docs/` directory:

- [`docs/roadmap_production.md`](docs/roadmap_production.md) - Production roadmap with all completed phases and lessons learned
- [`docs/architecture.md`](docs/architecture.md) - Architecture patterns, database schema, and implementation details
- [`docs/setup.md`](docs/setup.md) - Setup guide, CI/CD configuration, and troubleshooting

## License

This project is licensed under the MIT License.
