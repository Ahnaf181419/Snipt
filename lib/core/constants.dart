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
}
