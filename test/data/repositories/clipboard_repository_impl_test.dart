import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:snipt/data/datasources/local_database.dart';
import 'package:snipt/data/repositories/clipboard_repository_impl.dart';
import 'package:snipt/domain/entities/clipboard_item.dart';

class MockLocalDatabase extends Mock implements LocalDatabase {}

void main() {
  late MockLocalDatabase mockDatabase;
  late ClipboardRepositoryImpl repository;

  setUp(() {
    mockDatabase = MockLocalDatabase();
    repository = ClipboardRepositoryImpl(mockDatabase);
  });

  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
  });

  group('ClipboardRepositoryImpl', () {
    group('getRecentItems', () {
      test('returns list of ClipboardItems when query succeeds', () async {
        final testMaps = [
          {
            'id': 1,
            'content': 'Test content 1',
            'content_type': 'text',
            'is_image': 0,
            'is_bookmarked': 0,
            'is_deleted': 0,
            'category': 'text',
            'content_hash': 'hash1',
            'created_at': 1000,
            'updated_at': 1000,
          },
          {
            'id': 2,
            'content': 'Test content 2',
            'content_type': 'text',
            'is_image': 0,
            'is_bookmarked': 1,
            'is_deleted': 0,
            'category': 'text',
            'content_hash': 'hash2',
            'created_at': 2000,
            'updated_at': 2000,
          },
        ];

        when(() => mockDatabase.query(
              'clipboard_items',
              where: any(named: 'where'),
              whereArgs: any(named: 'whereArgs'),
              orderBy: any(named: 'orderBy'),
              limit: any(named: 'limit'),
            )).thenAnswer((_) async => testMaps);

        final result = await repository.getRecentItems(limit: 50);

        expect(result.length, 2);
        expect(result[0].id, 1);
        expect(result[0].content, 'Test content 1');
        expect(result[1].id, 2);
        expect(result[1].isBookmarked, true);
        verify(() => mockDatabase.query(
              'clipboard_items',
              where: 'is_deleted = ?',
              whereArgs: [0],
              orderBy: 'created_at DESC',
              limit: 50,
            )).called(1);
      });

      test('returns empty list when no items exist', () async {
        when(() => mockDatabase.query(
              any(),
              where: any(named: 'where'),
              whereArgs: any(named: 'whereArgs'),
              orderBy: any(named: 'orderBy'),
              limit: any(named: 'limit'),
            )).thenAnswer((_) async => []);

        final result = await repository.getRecentItems();

        expect(result, isEmpty);
      });
    });

    group('getBookmarkedItems', () {
      test('returns only bookmarked items', () async {
        final testMaps = [
          {
            'id': 1,
            'content': 'Bookmarked content',
            'content_type': 'text',
            'is_image': 0,
            'is_bookmarked': 1,
            'is_deleted': 0,
            'category': 'text',
            'content_hash': 'hash1',
            'created_at': 1000,
            'updated_at': 1000,
          },
        ];

        when(() => mockDatabase.query(
              'clipboard_items',
              where: any(named: 'where'),
              whereArgs: any(named: 'whereArgs'),
              orderBy: any(named: 'orderBy'),
            )).thenAnswer((_) async => testMaps);

        final result = await repository.getBookmarkedItems();

        expect(result.length, 1);
        expect(result[0].isBookmarked, true);
        verify(() => mockDatabase.query(
              'clipboard_items',
              where: 'is_bookmarked = ? AND is_deleted = ?',
              whereArgs: [1, 0],
              orderBy: 'updated_at DESC',
            )).called(1);
      });
    });

    group('searchItems', () {
      test('escapes LIKE wildcards in query', () async {
        when(() => mockDatabase.query(
              'clipboard_items',
              where: any(named: 'where'),
              whereArgs: any(named: 'whereArgs'),
              orderBy: any(named: 'orderBy'),
            )).thenAnswer((_) async => []);

        await repository.searchItems('test%query');

        verify(() => mockDatabase.query(
              'clipboard_items',
              where: 'content LIKE ? ESCAPE "\\" AND is_deleted = ?',
              whereArgs: ['%test\\%query%', 0],
              orderBy: 'created_at DESC',
            )).called(1);
      });

      test('escapes underscore wildcard in query', () async {
        when(() => mockDatabase.query(
              'clipboard_items',
              where: any(named: 'where'),
              whereArgs: any(named: 'whereArgs'),
              orderBy: any(named: 'orderBy'),
            )).thenAnswer((_) async => []);

        await repository.searchItems('test_query');

        verify(() => mockDatabase.query(
              'clipboard_items',
              where: 'content LIKE ? ESCAPE "\\" AND is_deleted = ?',
              whereArgs: ['%test\\_query%', 0],
              orderBy: 'created_at DESC',
            )).called(1);
      });

      test('escapes backslash in query', () async {
        when(() => mockDatabase.query(
              'clipboard_items',
              where: any(named: 'where'),
              whereArgs: any(named: 'whereArgs'),
              orderBy: any(named: 'orderBy'),
            )).thenAnswer((_) async => []);

        await repository.searchItems('test\\query');

        verify(() => mockDatabase.query(
              'clipboard_items',
              where: 'content LIKE ? ESCAPE "\\" AND is_deleted = ?',
              whereArgs: ['%test\\\\query%', 0],
              orderBy: 'created_at DESC',
            )).called(1);
      });
    });

    group('getItemById', () {
      test('returns ClipboardItem when found', () async {
        final testMap = {
          'id': 1,
          'content': 'Test content',
          'content_type': 'text',
          'is_image': 0,
          'is_bookmarked': 0,
          'is_deleted': 0,
          'category': 'text',
          'content_hash': 'hash1',
          'created_at': 1000,
          'updated_at': 1000,
        };

        when(() => mockDatabase.query(
              'clipboard_items',
              where: any(named: 'where'),
              whereArgs: any(named: 'whereArgs'),
            )).thenAnswer((_) async => [testMap]);

        final result = await repository.getItemById(1);

        expect(result, isNotNull);
        expect(result!.id, 1);
        expect(result.content, 'Test content');
      });

      test('returns null when not found', () async {
        when(() => mockDatabase.query(
              'clipboard_items',
              where: any(named: 'where'),
              whereArgs: any(named: 'whereArgs'),
            )).thenAnswer((_) async => []);

        final result = await repository.getItemById(999);

        expect(result, isNull);
      });
    });

    group('getItemByHash', () {
      test('returns ClipboardItem when found', () async {
        final testMap = {
          'id': 1,
          'content': 'Test content',
          'content_type': 'text',
          'is_image': 0,
          'is_bookmarked': 0,
          'is_deleted': 0,
          'category': 'text',
          'content_hash': 'testhash',
          'created_at': 1000,
          'updated_at': 1000,
        };

        when(() => mockDatabase.query(
              'clipboard_items',
              where: any(named: 'where'),
              whereArgs: any(named: 'whereArgs'),
            )).thenAnswer((_) async => [testMap]);

        final result = await repository.getItemByHash('testhash');

        expect(result, isNotNull);
        expect(result!.contentHash, 'testhash');
      });

      test('returns null when not found', () async {
        when(() => mockDatabase.query(
              'clipboard_items',
              where: any(named: 'where'),
              whereArgs: any(named: 'whereArgs'),
            )).thenAnswer((_) async => []);

        final result = await repository.getItemByHash('nonexistent');

        expect(result, isNull);
      });
    });

    group('addItem', () {
      test('inserts item with generated hash', () async {
        when(() => mockDatabase.insert(
              any(),
              any(),
              conflictAlgorithm: any(named: 'conflictAlgorithm'),
            )).thenAnswer((_) async => 1);

        final item = ClipboardItem(
          content: 'New content',
          contentType: ContentType.text,
          category: Category.text,
          createdAt: 1000,
          updatedAt: 1000,
        );

        final result = await repository.addItem(item);

        expect(result, 1);
        verify(() => mockDatabase.insert(
              'clipboard_items',
              any(),
              conflictAlgorithm: any(named: 'conflictAlgorithm'),
            )).called(1);
      });
    });

    group('toggleBookmark', () {
      test('uses atomic SQL to toggle bookmark', () async {
        when(() => mockDatabase.rawUpdate(
              any(),
              any(),
            )).thenAnswer((_) async => 1);

        await repository.toggleBookmark(1);

        verify(() => mockDatabase.rawUpdate(
              'UPDATE clipboard_items SET is_bookmarked = NOT is_bookmarked, updated_at = ? WHERE id = ?',
              any(),
            )).called(1);
      });
    });

    group('deleteOldestNonBookmarked', () {
      test('soft deletes oldest items when count exceeds limit', () async {
        when(() => mockDatabase.count(
              any(),
              where: any(named: 'where'),
              whereArgs: any(named: 'whereArgs'),
            )).thenAnswer((_) async => 60);

        when(() => mockDatabase.query(
              any(),
              where: any(named: 'where'),
              whereArgs: any(named: 'whereArgs'),
              orderBy: any(named: 'orderBy'),
              limit: any(named: 'limit'),
            )).thenAnswer((_) async => [
              {'id': 11},
              {'id': 12},
              {'id': 13},
              {'id': 14},
              {'id': 15},
              {'id': 16},
              {'id': 17},
              {'id': 18},
              {'id': 19},
              {'id': 20},
            ]);

        when(() => mockDatabase.update(
              any(),
              any(),
              where: any(named: 'where'),
              whereArgs: any(named: 'whereArgs'),
            )).thenAnswer((_) async => 1);

        await repository.deleteOldestNonBookmarked(50);

        verify(() => mockDatabase.count(
              'clipboard_items',
              where: 'is_bookmarked = ? AND is_deleted = ?',
              whereArgs: [0, 0],
            )).called(1);
        verify(() => mockDatabase.update(
              'clipboard_items',
              any(),
              where: 'id = ?',
              whereArgs: any(named: 'whereArgs'),
            )).called(10);
      });

      test('does nothing when count is within limit', () async {
        when(() => mockDatabase.count(
              any(),
              where: any(named: 'where'),
              whereArgs: any(named: 'whereArgs'),
            )).thenAnswer((_) async => 30);

        await repository.deleteOldestNonBookmarked(50);

        verifyNever(() => mockDatabase.query(any(),
            where: any(named: 'where'),
            whereArgs: any(named: 'whereArgs'),
            orderBy: any(named: 'orderBy'),
            limit: any(named: 'limit')));
        verifyNever(() => mockDatabase.update(any(), any(),
            where: any(named: 'where'), whereArgs: any(named: 'whereArgs')));
      });
    });

    group('clearAll', () {
      test('calls database.clearAll', () async {
        when(() => mockDatabase.clearAll(any())).thenAnswer((_) async {});

        await repository.clearAll();

        verify(() => mockDatabase.clearAll('clipboard_items')).called(1);
      });
    });
  });
}
