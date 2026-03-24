import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart' as uuid_pkg;
import 'package:uuid/enums.dart';
import '../../../domain/entities/clipboard_item.dart';
import '../../../domain/repositories/clipboard_repository.dart';
import '../../../domain/use_cases/detect_category_use_case.dart';
import 'clipboard_event.dart';
import 'clipboard_state.dart';

class _SearchResultsReady extends ClipboardEvent {
  final String query;
  const _SearchResultsReady(this.query);
  @override
  List<Object?> get props => [query];
}

class ClipboardBloc extends Bloc<ClipboardEvent, ClipboardState> {
  final ClipboardRepository _repository;
  final DetectCategoryUseCase _detectCategory = DetectCategoryUseCase();
  final uuid_pkg.Uuid _uuid = const uuid_pkg.Uuid();
  Timer? _searchDebounceTimer;
  String _lastQuery = '';

  ClipboardBloc(this._repository) : super(const ClipboardState()) {
    on<LoadRecentItems>(_onLoadRecentItems);
    on<LoadBookmarkedItems>(_onLoadBookmarkedItems);
    on<AddClipboardItem>(_onAddClipboardItem);
    on<DeleteClipboardItem>(_onDeleteClipboardItem);
    on<SoftDeleteClipboardItem>(_onSoftDeleteClipboardItem);
    on<RestoreClipboardItem>(_onRestoreClipboardItem);
    on<ToggleBookmark>(_onToggleBookmark);
    on<SearchItems>(_onSearchItems);
    on<_SearchResultsReady>(_onSearchResultsReady);
    on<ClearSearch>(_onClearSearch);
    on<ClearAllItems>(_onClearAllItems);
    on<UpdateStorageLimit>(_onUpdateStorageLimit);
  }

  @override
  Future<void> close() {
    _searchDebounceTimer?.cancel();
    return super.close();
  }

  Future<void> _onLoadRecentItems(
    LoadRecentItems event,
    Emitter<ClipboardState> emit,
  ) async {
    emit(state.copyWith(status: ClipboardLoadStatus.loading));
    try {
      final items = await _repository.getRecentItems(limit: event.limit);
      emit(state.copyWith(
        status: ClipboardLoadStatus.loaded,
        recentItems: items,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: ClipboardLoadStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onLoadBookmarkedItems(
    LoadBookmarkedItems event,
    Emitter<ClipboardState> emit,
  ) async {
    try {
      final items = await _repository.getBookmarkedItems();
      emit(state.copyWith(bookmarkedItems: items));
    } catch (e) {
      emit(state.copyWith(
        status: ClipboardLoadStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  String _generateHash(String content) {
    return _uuid.v5(Namespace.url.value, content);
  }

  Future<void> _onAddClipboardItem(
    AddClipboardItem event,
    Emitter<ClipboardState> emit,
  ) async {
    final currentLimit = state.storageLimit;
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final category = _detectCategory.call(event.content, event.isImage);
      final contentHash = _generateHash(event.content);

      final item = ClipboardItem(
        content: event.content,
        contentType: event.isImage ? ContentType.image : ContentType.text,
        isImage: event.isImage,
        category: category,
        contentHash: contentHash,
        createdAt: now,
        updatedAt: now,
      );

      final existingItem = await _repository.getItemByHash(contentHash);

      if (existingItem != null) {
        final updatedItem = existingItem.copyWith(
          updatedAt: now,
          isDeleted: false,
        );
        await _repository.updateItem(updatedItem);
      } else {
        await _repository.addItem(item);
      }

      await _repository.deleteOldestNonBookmarked(currentLimit);

      add(LoadRecentItems(limit: currentLimit));
    } catch (e) {
      emit(state.copyWith(
        status: ClipboardLoadStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onDeleteClipboardItem(
    DeleteClipboardItem event,
    Emitter<ClipboardState> emit,
  ) async {
    try {
      final item = await _repository.getItemById(event.id);
      if (item != null) {
        emit(state.copyWith(lastDeletedItem: item));
      }
      await _repository.deleteItem(event.id);
      add(LoadRecentItems(limit: state.storageLimit));
      add(LoadBookmarkedItems());
    } catch (e) {
      emit(state.copyWith(
        status: ClipboardLoadStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onSoftDeleteClipboardItem(
    SoftDeleteClipboardItem event,
    Emitter<ClipboardState> emit,
  ) async {
    try {
      final item = await _repository.getItemById(event.id);
      if (item != null) {
        emit(state.copyWith(lastDeletedItem: item));
      }
      await _repository.softDeleteItem(event.id);
      add(LoadRecentItems(limit: state.storageLimit));
      add(LoadBookmarkedItems());
    } catch (e) {
      emit(state.copyWith(
        status: ClipboardLoadStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onRestoreClipboardItem(
    RestoreClipboardItem event,
    Emitter<ClipboardState> emit,
  ) async {
    try {
      await _repository.restoreItem(event.id);
      add(LoadRecentItems(limit: state.storageLimit));
    } catch (e) {
      emit(state.copyWith(
        status: ClipboardLoadStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onToggleBookmark(
    ToggleBookmark event,
    Emitter<ClipboardState> emit,
  ) async {
    try {
      await _repository.toggleBookmark(event.id);
      add(LoadRecentItems(limit: state.storageLimit));
      add(LoadBookmarkedItems());
    } catch (e) {
      emit(state.copyWith(
        status: ClipboardLoadStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onSearchItems(
    SearchItems event,
    Emitter<ClipboardState> emit,
  ) async {
    _searchDebounceTimer?.cancel();

    if (event.query.isEmpty) {
      _lastQuery = '';
      emit(state.copyWith(
        isSearching: false,
        searchQuery: '',
        searchResults: [],
      ));
      return;
    }

    if (event.query == _lastQuery) return;
    _lastQuery = event.query;

    _searchDebounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (!isClosed) {
        add(_SearchResultsReady(event.query));
      }
    });
  }

  Future<void> _onSearchResultsReady(
    _SearchResultsReady event,
    Emitter<ClipboardState> emit,
  ) async {
    try {
      final results = await _repository.searchItems(event.query);
      emit(state.copyWith(
        isSearching: true,
        searchQuery: event.query,
        searchResults: results,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: ClipboardLoadStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onClearSearch(
    ClearSearch event,
    Emitter<ClipboardState> emit,
  ) async {
    _lastQuery = '';
    emit(state.copyWith(
      isSearching: false,
      searchQuery: '',
      searchResults: [],
    ));
  }

  Future<void> _onClearAllItems(
    ClearAllItems event,
    Emitter<ClipboardState> emit,
  ) async {
    try {
      await _repository.clearAll();
      add(LoadRecentItems(limit: state.storageLimit));
      add(LoadBookmarkedItems());
    } catch (e) {
      emit(state.copyWith(
        status: ClipboardLoadStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onUpdateStorageLimit(
    UpdateStorageLimit event,
    Emitter<ClipboardState> emit,
  ) async {
    emit(state.copyWith(storageLimit: event.limit));
    await _repository.deleteOldestNonBookmarked(event.limit);
    add(LoadRecentItems(limit: event.limit));
  }
}
