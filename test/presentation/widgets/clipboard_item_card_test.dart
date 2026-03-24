import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snipt/core/constants/app_strings.dart';
import 'package:snipt/domain/entities/clipboard_item.dart';
import 'package:snipt/presentation/widgets/clipboard_item_card.dart';

void main() {
  group('ClipboardItemCard', () {
    late ClipboardItem testItem;

    setUp(() {
      testItem = ClipboardItem(
        id: 1,
        content: 'Test clipboard content',
        contentType: ContentType.text,
        category: Category.text,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );
    });

    Widget createWidgetUnderTest({
      required ClipboardItem item,
      VoidCallback? onTap,
      VoidCallback? onBookmark,
      VoidCallback? onDelete,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: ClipboardItemCard(
            item: item,
            onTap: onTap,
            onBookmark: onBookmark,
            onDelete: onDelete,
          ),
        ),
      );
    }

    testWidgets('displays content text', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(item: testItem));

      expect(find.text('Test clipboard content'), findsOneWidget);
    });

    testWidgets('displays category badge for URL content', (tester) async {
      final urlItem = ClipboardItem(
        id: 2,
        content: 'https://example.com',
        contentType: ContentType.text,
        category: Category.url,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );

      await tester.pumpWidget(createWidgetUnderTest(item: urlItem));

      expect(find.text('URL'), findsOneWidget);
    });

    testWidgets('displays category badge for Phone content', (tester) async {
      final phoneItem = ClipboardItem(
        id: 3,
        content: '+1234567890',
        contentType: ContentType.text,
        category: Category.phone,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );

      await tester.pumpWidget(createWidgetUnderTest(item: phoneItem));

      expect(find.text('Phone'), findsOneWidget);
    });

    testWidgets('displays bookmark icon when item is bookmarked', (tester) async {
      final bookmarkedItem = ClipboardItem(
        id: 4,
        content: 'Bookmarked content',
        contentType: ContentType.text,
        isBookmarked: true,
        category: Category.text,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );

      await tester.pumpWidget(createWidgetUnderTest(item: bookmarkedItem));

      expect(find.byIcon(Icons.bookmark), findsOneWidget);
    });

    testWidgets('does not display bookmark icon when item is not bookmarked', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(item: testItem));

      expect(find.byIcon(Icons.bookmark), findsNothing);
    });

    testWidgets('calls onTap when card is tapped', (tester) async {
      bool wasTapped = false;

      await tester.pumpWidget(createWidgetUnderTest(
        item: testItem,
        onTap: () => wasTapped = true,
      ));

      await tester.tap(find.byType(InkWell));
      await tester.pump();

      expect(wasTapped, true);
    });

    testWidgets('swipe gestures are handled by Dismissible widget', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(
        item: testItem,
        onBookmark: () {},
        onDelete: () {},
      ));

      expect(find.byType(Dismissible), findsOneWidget);
    });

    testWidgets('displays category icon for text content', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(item: testItem));

      expect(find.byIcon(Icons.text_snippet), findsOneWidget);
    });

    testWidgets('displays category icon for URL content', (tester) async {
      final urlItem = ClipboardItem(
        id: 5,
        content: 'https://example.com',
        contentType: ContentType.text,
        category: Category.url,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );

      await tester.pumpWidget(createWidgetUnderTest(item: urlItem));

      expect(find.byIcon(Icons.link), findsOneWidget);
    });

    testWidgets('displays category icon for phone content', (tester) async {
      final phoneItem = ClipboardItem(
        id: 6,
        content: '+1234567890',
        contentType: ContentType.text,
        category: Category.phone,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );

      await tester.pumpWidget(createWidgetUnderTest(item: phoneItem));

      expect(find.byIcon(Icons.phone), findsOneWidget);
    });

    testWidgets('displays "Image" text for image content', (tester) async {
      final imageItem = ClipboardItem(
        id: 7,
        content: '/path/to/image.jpg',
        contentType: ContentType.text,
        isImage: true,
        category: Category.image,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );

      await tester.pumpWidget(createWidgetUnderTest(item: imageItem));

      expect(find.text(AppStrings.image), findsAtLeastNWidgets(1));
    });

    testWidgets('shows snackbar with "Copied!" when tapped', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(item: testItem));

      await tester.tap(find.byType(InkWell));
      await tester.pump();

      expect(find.text(AppStrings.copied), findsOneWidget);
    });
  });
}
