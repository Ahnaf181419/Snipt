import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snipt/app/app.dart';

void main() {
  testWidgets('app boots to the home shell', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: SniptApp()));
    await tester.pumpAndSettle();

    expect(find.text('snipt'), findsWidgets);
    expect(find.text('Clipboard history'), findsOneWidget);
  });
}
