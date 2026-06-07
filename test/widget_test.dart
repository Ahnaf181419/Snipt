import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snipt/app/app.dart';
import 'package:snipt/data/settings.dart';

/// In-memory settings so the widget test never touches secure storage.
class _FakeSettingsStore extends SettingsStore {
  _FakeSettingsStore(this._state);
  AppSettings _state;

  @override
  Future<AppSettings> read() async => _state;

  @override
  Future<void> write(AppSettings s) async => _state = s;
}

void main() {
  testWidgets('first run boots into onboarding', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsStoreProvider.overrideWithValue(
            _FakeSettingsStore(const AppSettings()),
          ),
        ],
        child: const SniptApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Welcome to snipt'), findsOneWidget);
    expect(find.text('Enable capture service'), findsOneWidget);
  });
}
