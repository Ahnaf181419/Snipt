import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snipt/data/clip_repository.dart';
import 'package:snipt/data/db/database.dart';
import 'package:snipt/domain/models/capture_event.dart';
import 'package:snipt/domain/models/clip_type.dart';

void main() {
  late AppDatabase db;
  late ClipRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = ClipRepository(db);
  });

  tearDown(() async => db.close());

  CaptureEvent ev(String content) => CaptureEvent(content: content);

  test('captures a clip and classifies a URL', () async {
    final clip = await repo.capture(ev('https://example.com'));
    expect(clip.type, ClipType.url);
    final history = await repo.watchHistory().first;
    expect(history, hasLength(1));
    expect(history.single.content, 'https://example.com');
  });

  test('collapses duplicates and bumps usage instead of inserting', () async {
    await repo.capture(ev('  hello world '));
    await repo.capture(ev('hello world'));
    final history = await repo.watchHistory().first;
    expect(history, hasLength(1));
    expect(history.single.usageCount, 2);
  });

  test('full-text search matches by prefix and ignores tombstones', () async {
    await repo.capture(ev('flutter clipboard manager'));
    await repo.capture(ev('completely unrelated note'));

    final hits = await repo.watchSearch('clip').first;
    expect(hits, hasLength(1));
    expect(hits.single.content, contains('clipboard'));

    await repo.softDelete(hits.single.id);
    expect(await repo.watchSearch('clip').first, isEmpty);
    expect(await repo.watchHistory().first, hasLength(1));
  });

  test('re-capturing a deleted clip restores it (undo path)', () async {
    final clip = await repo.capture(ev('restore me'));
    await repo.softDelete(clip.id);
    expect(await repo.watchHistory().first, isEmpty);

    // Same content again — dedup hits the tombstoned row and must undelete it.
    await repo.capture(ev('restore me'));
    final history = await repo.watchHistory().first;
    expect(history, hasLength(1));
    expect(history.single.content, 'restore me');
    // And it's searchable again.
    expect(await repo.watchSearch('restore').first, hasLength(1));
  });

  test('pin floats to the top and survives prune', () async {
    final keep = await repo.capture(ev('pinned item'));
    await repo.capture(ev('transient item'));
    await repo.togglePin(keep.id, true);

    final history = await repo.watchHistory().first;
    expect(history.first.id, keep.id, reason: 'pinned should sort first');

    // Prune everything older than tomorrow: only the unpinned row should go.
    final removed = await repo.prune(DateTime.now().add(const Duration(days: 1)));
    expect(removed, 1);
    final after = await repo.watchHistory().first;
    expect(after, hasLength(1));
    expect(after.single.id, keep.id);
  });
}
