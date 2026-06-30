import 'dart:async';

import '../../domain/models/capture_event.dart';
import '../clip_repository.dart';
import 'capture_api.g.dart';

/// Glue between the native capture engine and the repository.
///
/// * Inbound (native → Dart): implements [CaptureFlutterApi] and funnels every
///   captured payload into [ClipRepository.capture].
/// * Outbound (Dart → native): exposes [CaptureHostApi] controls for the UI
///   (start/stop service, overlay permission, read/write the live clipboard).
class CaptureBridge extends CaptureFlutterApi {
  CaptureBridge(this._repo, {CaptureHostApi? host})
      : host = host ?? CaptureHostApi();

  final ClipRepository _repo;
  final CaptureHostApi host;

  /// Registers this object to receive native capture callbacks, then tells the
  /// native side Dart is ready so it can flush any captures queued during
  /// startup (e.g. a cold-start share).
  void register() {
    CaptureFlutterApi.setUp(this);
    // Best-effort: on platforms without the native engine (e.g. tests) this
    // channel has no handler, so swallow the connection error.
    unawaited(host.flutterReady().catchError((Object _) {}));
  }

  @override
  void onClipCaptured(CapturePayload payload) {
    // Image payloads: mediaPath is set, content is empty.
    if (payload.mediaPath != null) {
      unawaited(
        _repo.captureImage(
          mediaPath: payload.mediaPath!,
          mimeType: payload.mimeType ?? 'image/jpeg',
          sourceApp: payload.sourceApp,
        ),
      );
      return;
    }
    // Text payloads: content must be non-empty.
    final content = payload.content.trim();
    if (content.isEmpty) return;
    unawaited(
      _repo.capture(
        CaptureEvent(
          content: content,
          source: _mapSource(payload.source),
          sourceApp: payload.sourceApp,
        ),
      ),
    );
  }

  /// Pulls whatever is currently on the system clipboard (valid only while the
  /// app holds focus) and persists it. Returns true if something was captured.
  Future<bool> captureFromClipboard() async {
    final payload = await host.readClipboardNow();
    if (payload == null || payload.content.trim().isEmpty) return false;
    await _repo.capture(
      CaptureEvent(
        content: payload.content.trim(),
        source: _mapSource(payload.source),
        sourceApp: payload.sourceApp,
      ),
    );
    return true;
  }

  static CaptureSource _mapSource(CaptureSourceDto dto) => switch (dto) {
        CaptureSourceDto.share => CaptureSource.share,
        CaptureSourceDto.processText => CaptureSource.processText,
        CaptureSourceDto.tile => CaptureSource.tile,
        CaptureSourceDto.manual => CaptureSource.manual,
        CaptureSourceDto.unknown => CaptureSource.unknown,
      };
}
