import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:snipt/domain/entities/clipboard_item.dart';
import 'package:snipt/domain/repositories/clipboard_repository.dart';
import 'package:snipt/presentation/bloc/clipboard/clipboard_bloc.dart';
import 'package:snipt/presentation/bloc/clipboard/clipboard_event.dart';
import 'package:snipt/presentation/bloc/clipboard/clipboard_state.dart';

class MockClipboardRepository extends Mock implements ClipboardRepository {}

class FakeClipboardItem extends Fake implements ClipboardItem {}

void main() {
  late MockClipboardRepository mockRepository;
  late ClipboardBloc bloc;

  setUpAll(() {
    registerFallbackValue(FakeClipboardItem());
  });

  setUp(() {
    mockRepository = MockClipboardRepository();
    bloc = ClipboardBloc(mockRepository);
  });

  tearDown(() {
    bloc.close();
  });

  group('ClipboardBloc', () {
    test('initial state is correct', () {
      expect(bloc.state, const ClipboardState());
      expect(bloc.state.status, ClipboardLoadStatus.initial);
      expect(bloc.state.recentItems, isEmpty);
      expect(bloc.state.bookmarkedItems, isEmpty);
      expect(bloc.state.searchResults, isEmpty);
      expect(bloc.state.isSearching, false);
      expect(bloc.state.storageLimit, 50);
    });

    group('LoadRecentItems', () {
      final testItems = [
        ClipboardItem(
          id: 1,
          content: 'Test content 1',
          contentType: ContentType.text,
          category: Category.text,
          createdAt: 1000,
          updatedAt: 1000,
        ),
        ClipboardItem(
          id: 2,
          content: 'Test content 2',
          contentType: ContentType.text,
          category: Category.text,
          createdAt: 2000,
          updatedAt: 2000,
        ),
      ];

      blocTest<ClipboardBloc, ClipboardState>(
        'emits [loading, loaded] when LoadRecentItems succeeds',
        build: () {
          when(() => mockRepository.getRecentItems(limit: any(named: 'limit')))
              .thenAnswer((_) async => testItems);
          return bloc;
        },
        act: (bloc) => bloc.add(const LoadRecentItems()),
        expect: () => [
          const ClipboardState(status: ClipboardLoadStatus.loading),
          ClipboardState(
            status: ClipboardLoadStatus.loaded,
            recentItems: testItems,
          ),
        ],
        verify: (_) {
          verify(() => mockRepository.getRecentItems(limit: 50)).called(1);
        },
      );

      blocTest<ClipboardBloc, ClipboardState>(
        'emits [loading, error] when LoadRecentItems fails',
        build: () {
          when(() => mockRepository.getRecentItems(limit: any(named: 'limit')))
              .thenThrow(Exception('Database error'));
          return bloc;
        },
        act: (bloc) => bloc.add(const LoadRecentItems()),
        expect: () => [
          const ClipboardState(status: ClipboardLoadStatus.loading),
          isA<ClipboardState>()
              .having((s) => s.status, 'status', ClipboardLoadStatus.error)
              .having((s) => s.errorMessage, 'errorMessage', isNotNull),
        ],
      );
    });

    group('LoadBookmarkedItems', () {
      final testBookmarks = [
        ClipboardItem(
          id: 1,
          content: 'Bookmarked content',
          contentType: ContentType.text,
          isBookmarked: true,
          category: Category.text,
          createdAt: 1000,
          updatedAt: 1000,
        ),
      ];

      blocTest<ClipboardBloc, ClipboardState>(
        'emits [loaded] with bookmarked items when LoadBookmarkedItems succeeds',
        build: () {
          when(() => mockRepository.getBookmarkedItems())
              .thenAnswer((_) async => testBookmarks);
          return bloc;
        },
        act: (bloc) => bloc.add(LoadBookmarkedItems()),
        expect: () => [
          ClipboardState(bookmarkedItems: testBookmarks),
        ],
        verify: (_) {
          verify(() => mockRepository.getBookmarkedItems()).called(1);
        },
      );

      blocTest<ClipboardBloc, ClipboardState>(
        'emits [error] when LoadBookmarkedItems fails',
        build: () {
          when(() => mockRepository.getBookmarkedItems())
              .thenThrow(Exception('Database error'));
          return bloc;
        },
        act: (bloc) => bloc.add(LoadBookmarkedItems()),
        expect: () => [
          isA<ClipboardState>()
              .having((s) => s.status, 'status', ClipboardLoadStatus.error)
              .having((s) => s.errorMessage, 'errorMessage', isNotNull),
        ],
      );
    });

    group('AddClipboardItem', () {
      blocTest<ClipboardBloc, ClipboardState>(
        'calls repository.addItem when adding new content',
        build: () {
          when(() => mockRepository.getItemByHash(any()))
              .thenAnswer((_) async => null);
          when(() => mockRepository.addItem(any()))
              .thenAnswer((_) async => 1);
          when(() => mockRepository.deleteOldestNonBookmarked(any()))
              .thenAnswer((_) async {});
          when(() => mockRepository.getRecentItems(limit: any(named: 'limit')))
              .thenAnswer((_) async => []);
          return bloc;
        },
        act: (bloc) => bloc.add(const AddClipboardItem(content: 'New content')),
        verify: (_) {
          verify(() => mockRepository.addItem(any())).called(1);
          verify(() => mockRepository.deleteOldestNonBookmarked(50)).called(1);
        },
      );

      blocTest<ClipboardBloc, ClipboardState>(
        'calls repository.updateItem when content already exists',
        build: () {
          final existingItem = ClipboardItem(
            id: 1,
            content: 'Existing content',
            contentType: ContentType.text,
            category: Category.text,
            createdAt: 1000,
            updatedAt: 1000,
          );
          when(() => mockRepository.getItemByHash(any()))
              .thenAnswer((_) async => existingItem);
          when(() => mockRepository.updateItem(any()))
              .thenAnswer((_) async {});
          when(() => mockRepository.deleteOldestNonBookmarked(any()))
              .thenAnswer((_) async {});
          when(() => mockRepository.getRecentItems(limit: any(named: 'limit')))
              .thenAnswer((_) async => []);
          return bloc;
        },
        act: (bloc) =>
            bloc.add(const AddClipboardItem(content: 'Existing content')),
        verify: (_) {
          verify(() => mockRepository.updateItem(any())).called(1);
          verifyNever(() => mockRepository.addItem(any()));
        },
      );

      blocTest<ClipboardBloc, ClipboardState>(
        'emits [error] when AddClipboardItem fails',
        build: () {
          when(() => mockRepository.getItemByHash(any()))
              .thenThrow(Exception('Database error'));
          return bloc;
        },
        act: (bloc) => bloc.add(const AddClipboardItem(content: 'Content')),
        expect: () => [
          isA<ClipboardState>()
              .having((s) => s.status, 'status', ClipboardLoadStatus.error)
              .having((s) => s.errorMessage, 'errorMessage', isNotNull),
        ],
      );
    });

    group('ToggleBookmark', () {
      blocTest<ClipboardBloc, ClipboardState>(
        'calls repository.toggleBookmark with correct id',
        build: () {
          when(() => mockRepository.toggleBookmark(any()))
              .thenAnswer((_) async {});
          when(() => mockRepository.getRecentItems(limit: any(named: 'limit')))
              .thenAnswer((_) async => []);
          when(() => mockRepository.getBookmarkedItems())
              .thenAnswer((_) async => []);
          return bloc;
        },
        act: (bloc) => bloc.add(const ToggleBookmark(1)),
        verify: (_) {
          verify(() => mockRepository.toggleBookmark(1)).called(1);
        },
      );

      blocTest<ClipboardBloc, ClipboardState>(
        'emits [error] when ToggleBookmark fails',
        build: () {
          when(() => mockRepository.toggleBookmark(any()))
              .thenThrow(Exception('Database error'));
          return bloc;
        },
        act: (bloc) => bloc.add(const ToggleBookmark(1)),
        expect: () => [
          isA<ClipboardState>()
              .having((s) => s.status, 'status', ClipboardLoadStatus.error)
              .having((s) => s.errorMessage, 'errorMessage', isNotNull),
        ],
      );
    });

    group('DeleteClipboardItem', () {
      final testItem = ClipboardItem(
        id: 1,
        content: 'Content to delete',
        contentType: ContentType.text,
        category: Category.text,
        createdAt: 1000,
        updatedAt: 1000,
      );

      blocTest<ClipboardBloc, ClipboardState>(
        'saves deleted item and calls repository.deleteItem',
        build: () {
          when(() => mockRepository.getItemById(any()))
              .thenAnswer((_) async => testItem);
          when(() => mockRepository.deleteItem(any()))
              .thenAnswer((_) async {});
          when(() => mockRepository.getRecentItems(limit: any(named: 'limit')))
              .thenAnswer((_) async => []);
          when(() => mockRepository.getBookmarkedItems())
              .thenAnswer((_) async => []);
          return bloc;
        },
        act: (bloc) => bloc.add(const DeleteClipboardItem(1)),
        verify: (_) {
          verify(() => mockRepository.deleteItem(1)).called(1);
        },
      );

      blocTest<ClipboardBloc, ClipboardState>(
        'emits [error] when DeleteClipboardItem fails',
        build: () {
          when(() => mockRepository.getItemById(any()))
              .thenThrow(Exception('Database error'));
          return bloc;
        },
        act: (bloc) => bloc.add(const DeleteClipboardItem(1)),
        expect: () => [
          isA<ClipboardState>()
              .having((s) => s.status, 'status', ClipboardLoadStatus.error)
              .having((s) => s.errorMessage, 'errorMessage', isNotNull),
        ],
      );
    });

    group('SoftDeleteClipboardItem', () {
      final testItem = ClipboardItem(
        id: 1,
        content: 'Content to soft delete',
        contentType: ContentType.text,
        category: Category.text,
        createdAt: 1000,
        updatedAt: 1000,
      );

      blocTest<ClipboardBloc, ClipboardState>(
        'saves deleted item and calls repository.softDeleteItem',
        build: () {
          when(() => mockRepository.getItemById(any()))
              .thenAnswer((_) async => testItem);
          when(() => mockRepository.softDeleteItem(any()))
              .thenAnswer((_) async {});
          when(() => mockRepository.getRecentItems(limit: any(named: 'limit')))
              .thenAnswer((_) async => []);
          when(() => mockRepository.getBookmarkedItems())
              .thenAnswer((_) async => []);
          return bloc;
        },
        act: (bloc) => bloc.add(const SoftDeleteClipboardItem(1)),
        verify: (_) {
          verify(() => mockRepository.softDeleteItem(1)).called(1);
        },
      );
    });

    group('RestoreClipboardItem', () {
      blocTest<ClipboardBloc, ClipboardState>(
        'calls repository.restoreItem with correct id',
        build: () {
          when(() => mockRepository.restoreItem(any()))
              .thenAnswer((_) async {});
          when(() => mockRepository.getRecentItems(limit: any(named: 'limit')))
              .thenAnswer((_) async => []);
          return bloc;
        },
        act: (bloc) => bloc.add(const RestoreClipboardItem(1)),
        verify: (_) {
          verify(() => mockRepository.restoreItem(1)).called(1);
        },
      );

      blocTest<ClipboardBloc, ClipboardState>(
        'emits [error] when RestoreClipboardItem fails',
        build: () {
          when(() => mockRepository.restoreItem(any()))
              .thenThrow(Exception('Database error'));
          return bloc;
        },
        act: (bloc) => bloc.add(const RestoreClipboardItem(1)),
        expect: () => [
          isA<ClipboardState>()
              .having((s) => s.status, 'status', ClipboardLoadStatus.error)
              .having((s) => s.errorMessage, 'errorMessage', isNotNull),
        ],
      );
    });

    group('SearchItems', () {
      final searchResults = [
        ClipboardItem(
          id: 1,
          content: 'Search result',
          contentType: ContentType.text,
          category: Category.text,
          createdAt: 1000,
          updatedAt: 1000,
        ),
      ];

      blocTest<ClipboardBloc, ClipboardState>(
        'emits [searching] with results when SearchItems succeeds',
        build: () {
          when(() => mockRepository.searchItems(any()))
              .thenAnswer((_) async => searchResults);
          return bloc;
        },
        act: (bloc) => bloc.add(const SearchItems('query')),
        wait: const Duration(milliseconds: 400),
        expect: () => [
          isA<ClipboardState>()
              .having((s) => s.isSearching, 'isSearching', true)
              .having((s) => s.searchQuery, 'searchQuery', 'query')
              .having((s) => s.searchResults, 'searchResults', searchResults),
        ],
        verify: (_) {
          verify(() => mockRepository.searchItems('query')).called(1);
        },
      );

      blocTest<ClipboardBloc, ClipboardState>(
        'emits [not searching] when query is empty',
        build: () => bloc,
        act: (bloc) => bloc.add(const SearchItems('')),
        expect: () => [
          const ClipboardState(
            isSearching: false,
            searchQuery: '',
            searchResults: [],
          ),
        ],
        verify: (_) {
          verifyNever(() => mockRepository.searchItems(any()));
        },
      );

      blocTest<ClipboardBloc, ClipboardState>(
        'emits [error] when SearchItems fails',
        build: () {
          when(() => mockRepository.searchItems(any()))
              .thenThrow(Exception('Search error'));
          return bloc;
        },
        act: (bloc) => bloc.add(const SearchItems('query')),
        wait: const Duration(milliseconds: 400),
        expect: () => [
          isA<ClipboardState>()
              .having((s) => s.status, 'status', ClipboardLoadStatus.error)
              .having((s) => s.errorMessage, 'errorMessage', isNotNull),
        ],
      );
    });

    group('ClearSearch', () {
      blocTest<ClipboardBloc, ClipboardState>(
        'emits [not searching] with empty results',
        build: () => bloc,
        seed: () => const ClipboardState(
          isSearching: true,
          searchQuery: 'test',
          searchResults: [],
        ),
        act: (bloc) => bloc.add(ClearSearch()),
        expect: () => [
          const ClipboardState(
            isSearching: false,
            searchQuery: '',
            searchResults: [],
          ),
        ],
      );
    });

    group('ClearAllItems', () {
      blocTest<ClipboardBloc, ClipboardState>(
        'calls repository.clearAll',
        build: () {
          when(() => mockRepository.clearAll()).thenAnswer((_) async {});
          when(() => mockRepository.getRecentItems(limit: any(named: 'limit')))
              .thenAnswer((_) async => []);
          when(() => mockRepository.getBookmarkedItems())
              .thenAnswer((_) async => []);
          return bloc;
        },
        act: (bloc) => bloc.add(ClearAllItems()),
        verify: (_) {
          verify(() => mockRepository.clearAll()).called(1);
        },
      );

      blocTest<ClipboardBloc, ClipboardState>(
        'emits [error] when ClearAllItems fails',
        build: () {
          when(() => mockRepository.clearAll())
              .thenThrow(Exception('Clear error'));
          return bloc;
        },
        act: (bloc) => bloc.add(ClearAllItems()),
        expect: () => [
          isA<ClipboardState>()
              .having((s) => s.status, 'status', ClipboardLoadStatus.error)
              .having((s) => s.errorMessage, 'errorMessage', isNotNull),
        ],
      );
    });

    group('UpdateStorageLimit', () {
      blocTest<ClipboardBloc, ClipboardState>(
        'updates storage limit and enforces it',
        build: () {
          when(() => mockRepository.deleteOldestNonBookmarked(any()))
              .thenAnswer((_) async {});
          when(() => mockRepository.getRecentItems(limit: any(named: 'limit')))
              .thenAnswer((_) async => []);
          return bloc;
        },
        act: (bloc) => bloc.add(const UpdateStorageLimit(100)),
        expect: () => [
          const ClipboardState(storageLimit: 100),
          const ClipboardState(status: ClipboardLoadStatus.loading, storageLimit: 100),
          const ClipboardState(status: ClipboardLoadStatus.loaded, storageLimit: 100),
        ],
        verify: (_) {
          verify(() => mockRepository.deleteOldestNonBookmarked(100)).called(1);
        },
      );
    });
  });
}
