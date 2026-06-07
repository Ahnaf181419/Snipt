import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// User-controlled preferences. [retentionDays] of 0 means "keep forever".
class AppSettings {
  const AppSettings({
    this.onboarded = false,
    this.lockEnabled = false,
    this.retentionDays = 30,
    this.captureServiceEnabled = false,
  });

  final bool onboarded;
  final bool lockEnabled;
  final int retentionDays;
  final bool captureServiceEnabled;

  AppSettings copyWith({
    bool? onboarded,
    bool? lockEnabled,
    int? retentionDays,
    bool? captureServiceEnabled,
  }) {
    return AppSettings(
      onboarded: onboarded ?? this.onboarded,
      lockEnabled: lockEnabled ?? this.lockEnabled,
      retentionDays: retentionDays ?? this.retentionDays,
      captureServiceEnabled:
          captureServiceEnabled ?? this.captureServiceEnabled,
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
  static const _kLock = 'lock_enabled';
  static const _kRetention = 'retention_days';
  static const _kService = 'capture_service_enabled';

  Future<AppSettings> read() async {
    final all = await _storage.readAll();
    return AppSettings(
      onboarded: all[_kOnboarded] == 'true',
      lockEnabled: all[_kLock] == 'true',
      retentionDays: int.tryParse(all[_kRetention] ?? '') ?? 30,
      captureServiceEnabled: all[_kService] == 'true',
    );
  }

  Future<void> write(AppSettings s) async {
    await _storage.write(key: _kOnboarded, value: '${s.onboarded}');
    await _storage.write(key: _kLock, value: '${s.lockEnabled}');
    await _storage.write(key: _kRetention, value: '${s.retentionDays}');
    await _storage.write(key: _kService, value: '${s.captureServiceEnabled}');
  }
}

final settingsStoreProvider = Provider<SettingsStore>((ref) => SettingsStore());

/// Async because the first read hits the platform key store. The UI shows a
/// splash until this resolves, so onboarding/lock decisions are never wrong.
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
  Future<void> setLockEnabled(bool value) =>
      _update(_current.copyWith(lockEnabled: value));
  Future<void> setRetentionDays(int days) =>
      _update(_current.copyWith(retentionDays: days));
  Future<void> setCaptureServiceEnabled(bool value) =>
      _update(_current.copyWith(captureServiceEnabled: value));
}

final settingsControllerProvider =
    AsyncNotifierProvider<SettingsController, AppSettings>(
        SettingsController.new);

/// Whether the user has unlocked the app this session (reset on cold start).
final sessionUnlockedProvider = StateProvider<bool>((ref) => false);
