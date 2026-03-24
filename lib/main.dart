import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app.dart';
import 'core/logger/app_logger.dart';
import 'services/clipboard_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  initTalker();

  FlutterError.onError = (details) {
    talker.handle(details.exception, details.stack, 'FlutterError');
  };

  runZonedGuarded(
    () async {
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
      );

      try {
        await ClipboardService.initializeService();
      } catch (e, st) {
        talker.handle(e, st, 'ClipboardService.initializeService');
      }

      runApp(const SniptApp());
    },
    (error, stack) {
      talker.handle(error, stack, 'Uncaught');
    },
  );
}
