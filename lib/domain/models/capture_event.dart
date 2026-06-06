import 'package:freezed_annotation/freezed_annotation.dart';

part 'capture_event.freezed.dart';
part 'capture_event.g.dart';

/// Where a capture originated, for analytics-free UX hints only.
enum CaptureSource { share, processText, tile, bubble, manual, unknown }

/// A raw clipboard payload handed to Dart by the native capture engine
/// (or produced in-app). The repository is responsible for hashing,
/// deduping and persisting it.
@freezed
abstract class CaptureEvent with _$CaptureEvent {
  const factory CaptureEvent({
    required String content,
    @Default(CaptureSource.unknown) CaptureSource source,
    String? sourceApp,
  }) = _CaptureEvent;

  factory CaptureEvent.fromJson(Map<String, dynamic> json) =>
      _$CaptureEventFromJson(json);
}
