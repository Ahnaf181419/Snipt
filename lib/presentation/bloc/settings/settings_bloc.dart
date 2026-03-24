import 'package:flutter_bloc/flutter_bloc.dart';
import 'settings_event.dart';
import 'settings_state.dart';

class SettingsBloc extends Bloc<SettingsEvent, SettingsState> {
  SettingsBloc() : super(const SettingsState()) {
    on<LoadSettings>(_onLoadSettings);
    on<ToggleBackgroundCapture>(_onToggleBackgroundCapture);
    on<UpdateStorageLimitSetting>(_onUpdateStorageLimitSetting);
  }

  Future<void> _onLoadSettings(
    LoadSettings event,
    Emitter<SettingsState> emit,
  ) async {
    emit(const SettingsState(
      backgroundCaptureEnabled: true,
      storageLimit: 50,
    ));
  }

  Future<void> _onToggleBackgroundCapture(
    ToggleBackgroundCapture event,
    Emitter<SettingsState> emit,
  ) async {
    emit(state.copyWith(backgroundCaptureEnabled: event.enabled));
  }

  Future<void> _onUpdateStorageLimitSetting(
    UpdateStorageLimitSetting event,
    Emitter<SettingsState> emit,
  ) async {
    emit(state.copyWith(storageLimit: event.limit));
  }
}
