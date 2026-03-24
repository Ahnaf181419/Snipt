import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:permission_handler/permission_handler.dart';
import '../core/constants/app_strings.dart';

class ClipboardService {
  static final FlutterBackgroundService _service = FlutterBackgroundService();
  static bool _isForegroundMode = true;
  static Timer? _clipboardTimer;

  static Future<void> initializeService() async {
    await _service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        isForegroundMode: _isForegroundMode,
        notificationChannelId: 'snipt_clipboard',
        initialNotificationTitle: _isForegroundMode ? AppStrings.appName : '',
        initialNotificationContent: _isForegroundMode ? AppStrings.serviceNotificationDesc : '',
        foregroundServiceNotificationId: 888,
        foregroundServiceTypes: [AndroidForegroundType.specialUse],
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );
  }

  static void setForegroundMode(bool enabled) {
    _isForegroundMode = enabled;
  }

  static bool get isForegroundMode => _isForegroundMode;

  @pragma('vm:entry-point')
  static Future<void> onStart(ServiceInstance service) async {
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

    _clipboardTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (service is AndroidServiceInstance) {
        if (await service.isForegroundService()) {
          try {
            final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
            if (clipboardData?.text != null && clipboardData!.text!.isNotEmpty) {
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
  }

  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(ServiceInstance service) async {
    return true;
  }

  static Future<bool> startService() async {
    final isAlreadyRunning = await _service.isRunning();
    if (isAlreadyRunning) return true;

    final hasPermission = await _requestPermissions();
    if (!hasPermission) return false;

    return await _service.startService();
  }

  static Future<bool> stopService() async {
    final isRunning = await _service.isRunning();
    if (isRunning) {
      _service.invoke('stopService');
    }
    return true;
  }

  static Future<bool> isRunning() async {
    return await _service.isRunning();
  }

  static Future<bool> _requestPermissions() async {
    final notificationStatus = await Permission.notification.status;
    if (notificationStatus.isDenied) {
      await Permission.notification.request();
    }
    return true;
  }

  static Stream<Map<String, dynamic>?> get onClipboardUpdate {
    return _service.on('clipboard_update');
  }
}
