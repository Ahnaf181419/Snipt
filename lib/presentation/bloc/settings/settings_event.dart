import 'package:equatable/equatable.dart';

abstract class SettingsEvent extends Equatable {
  const SettingsEvent();

  @override
  List<Object?> get props => [];
}

class LoadSettings extends SettingsEvent {}

class ToggleBackgroundCapture extends SettingsEvent {
  final bool enabled;
  
  const ToggleBackgroundCapture(this.enabled);
  
  @override
  List<Object?> get props => [enabled];
}

class UpdateStorageLimitSetting extends SettingsEvent {
  final int limit;
  
  const UpdateStorageLimitSetting(this.limit);
  
  @override
  List<Object?> get props => [limit];
}
