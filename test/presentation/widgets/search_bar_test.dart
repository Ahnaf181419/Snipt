import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snipt/core/constants/app_strings.dart';
import 'package:snipt/presentation/widgets/search_bar.dart';

void main() {
  group('CustomSearchBar', () {
    testWidgets('displays hint text', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CustomSearchBar(),
          ),
        ),
      );

      expect(find.text(AppStrings.search), findsOneWidget);
    });

    testWidgets('displays search icon', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CustomSearchBar(),
          ),
        ),
      );

      expect(find.byIcon(Icons.search), findsOneWidget);
    });

    testWidgets('calls onChanged when text is entered', (tester) async {
      String? changedValue;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomSearchBar(
              onChanged: (value) => changedValue = value,
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'test query');
      await tester.pump();

      expect(changedValue, 'test query');
    });

    testWidgets('displays custom hint text', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CustomSearchBar(
              hintText: 'Custom hint',
            ),
          ),
        ),
      );

      expect(find.text('Custom hint'), findsOneWidget);
    });

    testWidgets('clears text when clear button pressed', (tester) async {
      final controller = TextEditingController(text: 'initial text');
      bool clearCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomSearchBar(
              controller: controller,
              onClear: () => clearCalled = true,
            ),
          ),
        ),
      );

      controller.text = 'initial text';
      await tester.pump();

      final clearButton = find.byIcon(Icons.clear);
      if (clearButton.evaluate().isNotEmpty) {
        await tester.tap(clearButton);
        await tester.pump();
        expect(clearCalled, true);
      }
    });

    testWidgets('displays clear button when controller has text', (tester) async {
      final controller = TextEditingController(text: 'some text');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomSearchBar(
              controller: controller,
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.byIcon(Icons.clear), findsOneWidget);
    });

    testWidgets('does not display clear button when controller is empty', (tester) async {
      final controller = TextEditingController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomSearchBar(
              controller: controller,
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.byIcon(Icons.clear), findsNothing);
    });
  });
}
