import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'app.dart';
import 'services/clipboard_service.dart';

const _sentryDsn = String.fromEnvironment('SENTRY_DSN', defaultValue: '');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SentryFlutter.init(
    (options) {
      options.dsn = _sentryDsn;
      options.sendDefaultPii = false;
      options.environment = const String.fromEnvironment('ENVIRONMENT', defaultValue: 'production');
    },
    appRunner: () async {
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
      );

      await ClipboardService.initializeService();

      runApp(const SniptApp());
    },
  );
}
