import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'clip_repository.dart';
import 'db/database.dart';
import 'platform/capture_api.g.dart';
import 'platform/capture_bridge.dart';

/// Owns the singleton database for the app's lifetime.
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final clipRepositoryProvider = Provider<ClipRepository>((ref) {
  return ClipRepository(ref.watch(databaseProvider));
});

/// Connects the native capture engine to the repository. Reading this provider
/// registers the inbound channel, so it must be touched once at app start.
final captureBridgeProvider = Provider<CaptureBridge>((ref) {
  final bridge = CaptureBridge(ref.watch(clipRepositoryProvider));
  bridge.register();
  // Unregister the Pigeon handler when the provider is disposed (hot-restart,
  // test teardown) so stale handlers don't deliver to a dead repository.
  ref.onDispose(() => CaptureFlutterApi.setUp(null));
  return bridge;
});

/// Current search text entered by the user (raw, undebounced). Empty string
/// means "show full history".
class SearchQuery extends Notifier<String> {
  @override
  String build() => '';

  void set(String value) => state = value;
  void clear() => state = '';
}

final searchQueryProvider =
    NotifierProvider<SearchQuery, String>(SearchQuery.new);

/// Debounced search query — emits the trimmed query 200ms after the user stops
/// typing. This prevents FTS5 queries on every keystroke, keeping the UI
/// responsive and reducing database I/O on rapid typing.
final debouncedSearchProvider = StreamProvider.autoDispose<String>((ref) async* {
  final query = ref.watch(searchQueryProvider);
  await Future<void>.delayed(const Duration(milliseconds: 200));
  yield query.trim();
});

/// The list shown on the home screen: full history, or FTS results when the
/// user is searching. Reactive — updates as clips are captured or removed.
/// Uses the debounced query to avoid flooding the database during typing.
final clipListProvider = StreamProvider.autoDispose<List<Clip>>((ref) {
  final repo = ref.watch(clipRepositoryProvider);
  final query = ref.watch(debouncedSearchProvider).value ?? '';
  return query.isEmpty ? repo.watchHistory() : repo.watchSearch(query);
});

/// Mutations on a clip, shared by the list and detail screens.
class ClipActions {
  ClipActions(this._repo, this._bridge);

  final ClipRepository _repo;
  final CaptureBridge _bridge;

  /// Re-copy to the system clipboard and float the entry back to the top.
  /// Goes through the Pigeon channel so the native side can update its
  /// lastFocusDispatchedContent guard, preventing a double usageCount
  /// increment when the user returns to snipt after copying from within it.
  Future<void> copy(Clip clip) async {
    await _bridge.host.copyToClipboard(clip.content);
    await _repo.bumpUsage(clip.id);
  }

  Future<void> togglePin(Clip clip) => _repo.togglePin(clip.id, !clip.isPinned);

  Future<void> delete(String id) => _repo.softDelete(id);
}

final clipActionsProvider = Provider<ClipActions>((ref) => ClipActions(
      ref.watch(clipRepositoryProvider),
      ref.watch(captureBridgeProvider),
    ));
