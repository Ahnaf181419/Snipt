import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/data/platform/capture_api.g.dart',
    kotlinOut:
        'android/app/src/main/kotlin/com/example/snipt/capture/CaptureApi.g.kt',
    kotlinOptions: KotlinOptions(package: 'com.example.snipt.capture'),
    dartPackageName: 'snipt',
  ),
)

/// Mirrors Dart's CaptureSource; kept separate so the generated channel code
/// has no dependency on the domain layer.
enum CaptureSourceDto { share, processText, tile, bubble, manual, unknown }

class CapturePayload {
  CapturePayload(this.content, this.source, this.sourceApp);
  String content;
  CaptureSourceDto source;
  String? sourceApp;
}

/// Dart -> Native: controls and synchronous clipboard access (only meaningful
/// while the app holds focus, per Android 10+ restrictions).
@HostApi()
abstract class CaptureHostApi {
  /// Signals that the Dart [CaptureFlutterApi] handler is registered. Native
  /// queues captures that arrive before this (e.g. a cold-start share) and
  /// flushes them once called, so no capture is dropped during startup.
  void flutterReady();

  bool isServiceRunning();
  void startService();
  void stopService();
  bool hasOverlayPermission();
  void requestOverlayPermission();

  /// Reads the current system clipboard. Returns null if empty or unreadable.
  CapturePayload? readClipboardNow();

  /// Writes [text] back to the system clipboard (used by tap-to-copy).
  void copyToClipboard(String text);
}

/// Native -> Dart: delivers a captured payload for persistence.
@FlutterApi()
abstract class CaptureFlutterApi {
  void onClipCaptured(CapturePayload payload);
}
