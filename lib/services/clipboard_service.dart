import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:permission_handler/permission_handler.dart';
import '../core/constants/app_strings.dart';
import '../core/logger/app_logger.dart';

class ClipboardService {
  static final FlutterBackgroundService _service = FlutterBackgroundService();
  static bool _isForegroundMode = true;
  static bool _isInitialized = false;
  static Timer? _clipboardTimer;

  static Future<void> initializeService() async {
    if (_isInitialized) return;

    try {
      await _service.configure(
        androidConfiguration: AndroidConfiguration(
          onStart: onStart,
          autoStart: false,
          isForegroundMode: _isForegroundMode,
          notificationChannelId: 'snipt_clipboard',
          initialNotificationTitle: _isForegroundMode ? AppStrings.appName : '',
          initialNotificationContent: _isForegroundMode
              ? AppStrings.serviceNotificationDesc
              : '',
          foregroundServiceNotificationId: 888,
          foregroundServiceTypes: [AndroidForegroundType.specialUse],
        ),
        iosConfiguration: IosConfiguration(
          autoStart: false,
          onForeground: onStart,
          onBackground: onIosBackground,
        ),
      );
      _isInitialized = true;
    } catch (e, st) {
      talker.handle(e, st, 'ClipboardService.initializeService');
      _isInitialized = false;
    }
  }

  static Future<void> setForegroundMode(bool enabled) async {
    _isForegroundMode = enabled;
    try {
      final isRunning = await _service.isRunning();
      if (isRunning) {
        if (enabled) {
          _service.invoke('setAsForeground');
        } else {
          _service.invoke('setAsBackground');
        }
      }
    } catch (e, st) {
      talker.handle(e, st, 'ClipboardService.setForegroundMode');
    }
  }

  static bool get isForegroundMode => _isForegroundMode;

  static bool get isServiceInitialized => _isInitialized;

  @pragma('vm:entry-point')
  static Future<void> onStart(ServiceInstance service) async {
    try {
      if (service is AndroidServiceInstance) {
        service.on('setAsForeground').listen((event) {
          service.setAsForegroundService();
        });

        service.on('setAsBackground').listen((event) {
          service.setAsBackgroundService();
        });
      }

      service.on('stopService').listen((event) {
        _clipboardTimer?.cancel();
        _clipboardTimer = null;
        service.stopSelf();
      });

      _clipboardTimer?.cancel();
      _clipboardTimer = Timer.periodic(const Duration(seconds: 5), (
        timer,
      ) async {
        if (service is AndroidServiceInstance) {
          if (await service.isForegroundService()) {
            try {
              final clipboardData = await Clipboard.getData(
                Clipboard.kTextPlain,
              );
              if (clipboardData?.text != null &&
                  clipboardData!.text!.isNotEmpty) {
                service.invoke('clipboard_update', {
                  'content': clipboardData.text,
                  'isImage': false,
                });
              }
            } catch (e) {
              // Silently ignore clipboard errors in background service
            }
          }
        }
      });
    } catch (e, st) {
      talker.handle(e, st, 'ClipboardService.onStart');
    }
  }

  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(ServiceInstance service) async {
    return true;
  }

  static Future<bool> startService() async {
    if (!_isInitialized) {
      return false;
    }

    try {
      final isAlreadyRunning = await _service.isRunning();
      if (isAlreadyRunning) return true;

      final hasPermission = await _requestPermissions();
      if (!hasPermission) return false;

      return await _service.startService();
    } catch (e, st) {
      talker.handle(e, st, 'ClipboardService.startService');
      return false;
    }
  }

  static Future<bool> stopService() async {
    if (!_isInitialized) {
      return false;
    }

    try {
      final isRunning = await _service.isRunning();
      if (isRunning) {
        _service.invoke('stopService');
      }
      return true;
    } catch (e, st) {
      talker.handle(e, st, 'ClipboardService.stopService');
      return false;
    }
  }

  static Future<bool> isRunning() async {
    if (!_isInitialized) {
      return false;
    }

    try {
      return await _service.isRunning();
    } catch (e, st) {
      talker.handle(e, st, 'ClipboardService.isRunning');
      return false;
    }
  }

  static Future<bool> _requestPermissions() async {
    try {
      final notificationStatus = await Permission.notification.status;
      if (notificationStatus.isDenied) {
        await Permission.notification.request();
      }
      return true;
    } catch (e, st) {
      talker.handle(e, st, 'ClipboardService.requestPermissions');
      return false;
    }
  }

  static Stream<Map<String, dynamic>?> get onClipboardUpdate {
    if (!_isInitialized) {
      return const Stream.empty();
    }
    return _service.on('clipboard_update');
  }
}
