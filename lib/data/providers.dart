import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'clip_repository.dart';
import 'db/database.dart';

/// Owns the singleton database for the app's lifetime.
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final clipRepositoryProvider = Provider<ClipRepository>((ref) {
  return ClipRepository(ref.watch(databaseProvider));
});

/// Current search text. Empty string means "show full history".
class SearchQuery extends Notifier<String> {
  @override
  String build() => '';

  void set(String value) => state = value;
  void clear() => state = '';
}

final searchQueryProvider =
    NotifierProvider<SearchQuery, String>(SearchQuery.new);

/// The list shown on the home screen: full history, or FTS results when the
/// user is searching. Reactive — updates as clips are captured or removed.
final clipListProvider = StreamProvider.autoDispose<List<Clip>>((ref) {
  final repo = ref.watch(clipRepositoryProvider);
  final query = ref.watch(searchQueryProvider).trim();
  return query.isEmpty ? repo.watchHistory() : repo.watchSearch(query);
});
