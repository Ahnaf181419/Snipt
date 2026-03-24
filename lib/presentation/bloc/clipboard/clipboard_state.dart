import 'package:equatable/equatable.dart';
import '../../../domain/entities/clipboard_item.dart';

enum ClipboardLoadStatus { initial, loading, loaded, error }

class ClipboardState extends Equatable {
  final ClipboardLoadStatus status;
  final List<ClipboardItem> recentItems;
  final List<ClipboardItem> bookmarkedItems;
  final List<ClipboardItem> searchResults;
  final bool isSearching;
  final String searchQuery;
  final String? errorMessage;
  final int storageLimit;
  final ClipboardItem? lastDeletedItem;

  const ClipboardState({
    this.status = ClipboardLoadStatus.initial,
    this.recentItems = const [],
    this.bookmarkedItems = const [],
    this.searchResults = const [],
    this.isSearching = false,
    this.searchQuery = '',
    this.errorMessage,
    this.storageLimit = 50,
    this.lastDeletedItem,
  });

  ClipboardState copyWith({
    ClipboardLoadStatus? status,
    List<ClipboardItem>? recentItems,
    List<ClipboardItem>? bookmarkedItems,
    List<ClipboardItem>? searchResults,
    bool? isSearching,
    String? searchQuery,
    String? errorMessage,
    int? storageLimit,
    ClipboardItem? lastDeletedItem,
  }) {
    return ClipboardState(
      status: status ?? this.status,
      recentItems: recentItems ?? this.recentItems,
      bookmarkedItems: bookmarkedItems ?? this.bookmarkedItems,
      searchResults: searchResults ?? this.searchResults,
      isSearching: isSearching ?? this.isSearching,
      searchQuery: searchQuery ?? this.searchQuery,
      errorMessage: errorMessage ?? this.errorMessage,
      storageLimit: storageLimit ?? this.storageLimit,
      lastDeletedItem: lastDeletedItem ?? this.lastDeletedItem,
    );
  }

  @override
  List<Object?> get props => [
        status,
        recentItems,
        bookmarkedItems,
        searchResults,
        isSearching,
        searchQuery,
        errorMessage,
        storageLimit,
        lastDeletedItem,
      ];
}
