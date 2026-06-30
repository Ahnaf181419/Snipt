// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'capture_event.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_CaptureEvent _$CaptureEventFromJson(Map<String, dynamic> json) =>
    _CaptureEvent(
      content: json['content'] as String,
      source:
          $enumDecodeNullable(_$CaptureSourceEnumMap, json['source']) ??
          CaptureSource.unknown,
      sourceApp: json['sourceApp'] as String?,
      mediaPath: json['mediaPath'] as String?,
      mimeType: json['mimeType'] as String?,
    );

Map<String, dynamic> _$CaptureEventToJson(_CaptureEvent instance) =>
    <String, dynamic>{
      'content': instance.content,
      'source': _$CaptureSourceEnumMap[instance.source]!,
      'sourceApp': instance.sourceApp,
      'mediaPath': instance.mediaPath,
      'mimeType': instance.mimeType,
    };

const _$CaptureSourceEnumMap = {
  CaptureSource.share: 'share',
  CaptureSource.processText: 'processText',
  CaptureSource.tile: 'tile',
  CaptureSource.manual: 'manual',
  CaptureSource.unknown: 'unknown',
};
