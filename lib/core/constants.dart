/// App-wide constants shared across layers.
class AppConstants {
  const AppConstants._();

  static const String appName = 'snipt';

  /// Platform-channel namespace bridging the native capture engine and Dart.
  /// Native code posts captured clips here; Dart invokes service controls.
  static const String captureChannel = 'snipt/capture';

  /// Default retention: non-pinned clips older than this are eligible for
  /// pruning. Pinned clips are never auto-pruned.
  static const Duration defaultRetention = Duration(days: 30);

  /// Page size for history pagination.
  static const int historyPageSize = 50;

  /// Hard cap on a single captured payload to keep the DB lean.
  static const int maxClipBytes = 256 * 1024;

  /// Free-tier soft cap on the number of stored (non-pinned) clips. Above
  /// this, new captures trigger pruning of the oldest non-pinned rows.
  /// Pro users bypass this cap.
  static const int freeTierClipCap = 200;

  /// Play Store product id for the Snipt Pro one-time unlock. Must match
  /// the in-app product configured in Play Console.
  static const String proProductId = 'snipt_pro_unlock';

  /// Free-tier soft cap on total media storage (non-pinned image clips).
  /// Above this, the oldest non-pinned images are pruned. Pro users bypass.
  static const int freeTierMediaBytes = 200 * 1024 * 1024; // 200 MB
}
