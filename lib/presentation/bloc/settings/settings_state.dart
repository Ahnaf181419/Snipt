import 'package:equatable/equatable.dart';

class SettingsState extends Equatable {
  final bool backgroundCaptureEnabled;
  final int storageLimit;

  const SettingsState({
    this.backgroundCaptureEnabled = true,
    this.storageLimit = 50,
  });

  SettingsState copyWith({
    bool? backgroundCaptureEnabled,
    int? storageLimit,
  }) {
    return SettingsState(
      backgroundCaptureEnabled: backgroundCaptureEnabled ?? this.backgroundCaptureEnabled,
      storageLimit: storageLimit ?? this.storageLimit,
    );
  }

  @override
  List<Object?> get props => [backgroundCaptureEnabled, storageLimit];
}
