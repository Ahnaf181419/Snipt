import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// User-controlled preferences. [retentionDays] of 0 means "keep forever".
///
/// [isPro] is the local entitlement flag. It is set to `true` by the billing
/// service after a verified purchase, and survives uninstalls via Play's
/// purchase-restoration flow. We persist it in encrypted storage so the UI
/// stays Pro-gated during the cold start that precedes the first billing
/// restore query.
class AppSettings {
  const AppSettings({
    this.onboarded = false,
    this.retentionDays = 30,
    this.captureServiceEnabled = false,
    this.isPro = false,
    this.tutorialShown = false,
  });

  final bool onboarded;
  final int retentionDays;
  final bool captureServiceEnabled;

  /// Whether the user owns the Snipt Pro one-time unlock. Cached locally so
  /// the UI can gate Pro features on the very first frame.
  final bool isPro;

  /// Whether the post-onboarding coach-mark tour has been shown at least once.
  final bool tutorialShown;

  AppSettings copyWith({
    bool? onboarded,
    int? retentionDays,
    bool? captureServiceEnabled,
    bool? isPro,
    bool? tutorialShown,
  }) {
    return AppSettings(
      onboarded: onboarded ?? this.onboarded,
      retentionDays: retentionDays ?? this.retentionDays,
      captureServiceEnabled:
          captureServiceEnabled ?? this.captureServiceEnabled,
      isPro: isPro ?? this.isPro,
      tutorialShown: tutorialShown ?? this.tutorialShown,
    );
  }
}

/// Persists [AppSettings] in encrypted platform key stores. Methods are
/// overridable so tests can supply an in-memory fake.
class SettingsStore {
  SettingsStore([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _kOnboarded = 'onboarded';
  static const _kRetention = 'retention_days';
  static const _kService = 'capture_service_enabled';
  static const _kPro = 'is_pro';
  static const _kTutorial = 'tutorial_shown';

  Future<AppSettings> read() async {
    final all = await _storage.readAll();
    return AppSettings(
      onboarded: all[_kOnboarded] == 'true',
      retentionDays: int.tryParse(all[_kRetention] ?? '') ?? 30,
      captureServiceEnabled: all[_kService] == 'true',
      isPro: all[_kPro] == 'true',
      tutorialShown: all[_kTutorial] == 'true',
    );
  }

  Future<void> write(AppSettings s) async {
    await _storage.write(key: _kOnboarded, value: '${s.onboarded}');
    await _storage.write(key: _kRetention, value: '${s.retentionDays}');
    await _storage.write(key: _kService, value: '${s.captureServiceEnabled}');
    await _storage.write(key: _kPro, value: '${s.isPro}');
    await _storage.write(key: _kTutorial, value: '${s.tutorialShown}');
  }
}

final settingsStoreProvider = Provider<SettingsStore>((ref) => SettingsStore());

/// Async because the first read hits the platform key store. The UI shows a
/// splash until this resolves, so onboarding decisions are never wrong.
class SettingsController extends AsyncNotifier<AppSettings> {
  @override
  Future<AppSettings> build() => ref.read(settingsStoreProvider).read();

  Future<void> _update(AppSettings next) async {
    // Optimistic update for instant UI response, but revert if the disk write
    // fails so in-memory state and persisted state never diverge.
    final previous = state;
    state = AsyncData(next);
    try {
      await ref.read(settingsStoreProvider).write(next);
    } catch (e, st) {
      state = previous;
      Error.throwWithStackTrace(e, st);
    }
  }

  AppSettings get _current => state.value ?? const AppSettings();

  Future<void> completeOnboarding() =>
      _update(_current.copyWith(onboarded: true));
  Future<void> setRetentionDays(int days) =>
      _update(_current.copyWith(retentionDays: days));
  Future<void> setCaptureServiceEnabled(bool value) =>
      _update(_current.copyWith(captureServiceEnabled: value));

  /// Sets the local Pro entitlement. Called by the billing service after a
  /// verified purchase or successful restore.
  Future<void> setPro(bool value) =>
      _update(_current.copyWith(isPro: value));
  Future<void> markTutorialShown() =>
      _update(_current.copyWith(tutorialShown: true));
}

final settingsControllerProvider =
    AsyncNotifierProvider<SettingsController, AppSettings>(
        SettingsController.new);
