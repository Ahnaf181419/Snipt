// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'capture_event.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$CaptureEvent {

 String get content; CaptureSource get source; String? get sourceApp;
/// Create a copy of CaptureEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CaptureEventCopyWith<CaptureEvent> get copyWith => _$CaptureEventCopyWithImpl<CaptureEvent>(this as CaptureEvent, _$identity);

  /// Serializes this CaptureEvent to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CaptureEvent&&(identical(other.content, content) || other.content == content)&&(identical(other.source, source) || other.source == source)&&(identical(other.sourceApp, sourceApp) || other.sourceApp == sourceApp));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,content,source,sourceApp);

@override
String toString() {
  return 'CaptureEvent(content: $content, source: $source, sourceApp: $sourceApp)';
}


}

/// @nodoc
abstract mixin class $CaptureEventCopyWith<$Res>  {
  factory $CaptureEventCopyWith(CaptureEvent value, $Res Function(CaptureEvent) _then) = _$CaptureEventCopyWithImpl;
@useResult
$Res call({
 String content, CaptureSource source, String? sourceApp
});




}
/// @nodoc
class _$CaptureEventCopyWithImpl<$Res>
    implements $CaptureEventCopyWith<$Res> {
  _$CaptureEventCopyWithImpl(this._self, this._then);

  final CaptureEvent _self;
  final $Res Function(CaptureEvent) _then;

/// Create a copy of CaptureEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? content = null,Object? source = null,Object? sourceApp = freezed,}) {
  return _then(_self.copyWith(
content: null == content ? _self.content : content // ignore: cast_nullable_to_non_nullable
as String,source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as CaptureSource,sourceApp: freezed == sourceApp ? _self.sourceApp : sourceApp // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [CaptureEvent].
extension CaptureEventPatterns on CaptureEvent {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CaptureEvent value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CaptureEvent() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CaptureEvent value)  $default,){
final _that = this;
switch (_that) {
case _CaptureEvent():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CaptureEvent value)?  $default,){
final _that = this;
switch (_that) {
case _CaptureEvent() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String content,  CaptureSource source,  String? sourceApp)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CaptureEvent() when $default != null:
return $default(_that.content,_that.source,_that.sourceApp);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String content,  CaptureSource source,  String? sourceApp)  $default,) {final _that = this;
switch (_that) {
case _CaptureEvent():
return $default(_that.content,_that.source,_that.sourceApp);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String content,  CaptureSource source,  String? sourceApp)?  $default,) {final _that = this;
switch (_that) {
case _CaptureEvent() when $default != null:
return $default(_that.content,_that.source,_that.sourceApp);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CaptureEvent implements CaptureEvent {
  const _CaptureEvent({required this.content, this.source = CaptureSource.unknown, this.sourceApp});
  factory _CaptureEvent.fromJson(Map<String, dynamic> json) => _$CaptureEventFromJson(json);

@override final  String content;
@override@JsonKey() final  CaptureSource source;
@override final  String? sourceApp;

/// Create a copy of CaptureEvent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CaptureEventCopyWith<_CaptureEvent> get copyWith => __$CaptureEventCopyWithImpl<_CaptureEvent>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CaptureEventToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CaptureEvent&&(identical(other.content, content) || other.content == content)&&(identical(other.source, source) || other.source == source)&&(identical(other.sourceApp, sourceApp) || other.sourceApp == sourceApp));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,content,source,sourceApp);

@override
String toString() {
  return 'CaptureEvent(content: $content, source: $source, sourceApp: $sourceApp)';
}


}

/// @nodoc
abstract mixin class _$CaptureEventCopyWith<$Res> implements $CaptureEventCopyWith<$Res> {
  factory _$CaptureEventCopyWith(_CaptureEvent value, $Res Function(_CaptureEvent) _then) = __$CaptureEventCopyWithImpl;
@override @useResult
$Res call({
 String content, CaptureSource source, String? sourceApp
});




}
/// @nodoc
class __$CaptureEventCopyWithImpl<$Res>
    implements _$CaptureEventCopyWith<$Res> {
  __$CaptureEventCopyWithImpl(this._self, this._then);

  final _CaptureEvent _self;
  final $Res Function(_CaptureEvent) _then;

/// Create a copy of CaptureEvent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? content = null,Object? source = null,Object? sourceApp = freezed,}) {
  return _then(_CaptureEvent(
content: null == content ? _self.content : content // ignore: cast_nullable_to_non_nullable
as String,source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as CaptureSource,sourceApp: freezed == sourceApp ? _self.sourceApp : sourceApp // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
