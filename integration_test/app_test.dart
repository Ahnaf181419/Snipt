import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:snipt/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Snipt App Integration Tests', () {
    testWidgets('app launches and displays home screen', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      expect(find.text('Snipt'), findsOneWidget);
    });

    testWidgets('bottom navigation works', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.content_paste), findsOneWidget);
      expect(find.byIcon(Icons.bookmark_border), findsOneWidget);
      expect(find.byIcon(Icons.settings), findsOneWidget);
    });

    testWidgets('can navigate to bookmarks screen', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.bookmark_border));
      await tester.pumpAndSettle();

      expect(find.text('Bookmarks'), findsOneWidget);
    });

    testWidgets('can navigate to settings screen', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.settings));
      await tester.pumpAndSettle();

      expect(find.text('Settings'), findsOneWidget);
    });

    testWidgets('settings screen shows storage limit slider', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.settings));
      await tester.pumpAndSettle();

      expect(find.text('Storage Limit'), findsOneWidget);
      expect(find.text('50 items'), findsOneWidget);
    });

    testWidgets('settings screen shows background capture toggle', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.settings));
      await tester.pumpAndSettle();

      expect(find.text('Background Capture'), findsOneWidget);
    });

    testWidgets('settings screen shows export option', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.settings));
      await tester.pumpAndSettle();

      expect(find.text('Export Data'), findsOneWidget);
    });

    testWidgets('settings screen shows clear data option', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.settings));
      await tester.pumpAndSettle();

      expect(find.text('Clear All Data'), findsOneWidget);
    });

    testWidgets('search bar is visible on home screen', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.search), findsOneWidget);
    });

    testWidgets('can type in search bar', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'test');
      await tester.pump();

      expect(find.text('test'), findsOneWidget);
    });

    testWidgets('returns to home screen from bookmarks', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.bookmark_border));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.content_paste));
      await tester.pumpAndSettle();

      expect(find.text('Snipt'), findsOneWidget);
    });

    testWidgets('returns to home screen from settings', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.settings));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.content_paste));
      await tester.pumpAndSettle();

      expect(find.text('Snipt'), findsOneWidget);
    });
  });
}
