# Contributing to Snipt

Thank you for your interest in contributing to Snipt!

## Development Setup

1. Fork the repository
2. Clone your fork:
   ```bash
   git clone https://github.com/your-username/snipt.git
   ```
3. Navigate to the project directory:
   ```bash
   cd snipt
   ```
4. Install dependencies:
   ```bash
   flutter pub get
   ```
5. Create a branch for your changes:
   ```bash
   git checkout -b feature/your-feature-name
   ```

## Development Workflow

### Running the App

```bash
flutter run
```

### Running Tests

```bash
# All tests
flutter test

# Unit tests
flutter test test/

# Widget tests
flutter test test/presentation/widgets/

# Integration tests
flutter test integration_test/
```

### Code Analysis

```bash
flutter analyze
```

## Code Style

- Follow Flutter/Dart conventions
- Use meaningful variable and function names
- Add comments for complex logic
- Keep functions small and focused

## Pull Request Process

1. Ensure all tests pass before submitting a PR
2. Update documentation if needed
3. Follow the PR template
4. Request review from maintainers

## Reporting Issues

When reporting issues, please include:

- Flutter version
- Android version
- Steps to reproduce
- Expected vs actual behavior
- Error logs if applicable

## Commit Messages

Use clear, descriptive commit messages:
- `fix: resolve null pointer in clipboard service`
- `feat: add search debouncing`
- `test: add widget tests for clipboard item card`

## Questions?

Feel free to open an issue for any questions or discussions.
