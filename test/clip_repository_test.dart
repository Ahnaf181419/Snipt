import 'dart:io';

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

  test('free-tier cap prunes oldest non-pinned rows; pinned survive', () async {
    repo.isProSupplier = () => false;
    // Capture 205 distinct clips so the cap (200) kicks in. Each capture
    // bumps updatedAt, so the 5 oldest non-pinned should be evicted.
    for (var i = 0; i < 205; i++) {
      await repo.capture(ev('free cap clip $i'));
    }
    final history = await repo.watchHistory().first;
    expect(history.length, lessThanOrEqualTo(200));
    // The oldest contents should be gone, the newest should remain.
    expect(history.any((c) => c.content == 'free cap clip 0'), isFalse);
    expect(history.any((c) => c.content == 'free cap clip 204'), isTrue);
  });

  test('Pro users bypass the free-tier cap', () async {
    repo.isProSupplier = () => true;
    for (var i = 0; i < 50; i++) {
      await repo.capture(ev('pro clip $i'));
    }
    final history = await repo.watchHistory().first;
    expect(history, hasLength(50));
  });

  // ─── Image clip tests ───────────────────────────────────────────────

  /// Creates a temp file with [bytes] of dummy data and returns its path.
  Future<String> makeImageFile(int bytes) async {
    final dir = await Directory.systemTemp.createTemp('snipt_test');
    final file = File('${dir.path}/img_${DateTime.now().microsecondsSinceEpoch}.jpg');
    await file.writeAsBytes(List.filled(bytes, 0));
    return file.path;
  }

  test('image capture persists with type=image and correct mediaPath', () async {
    final path = await makeImageFile(1024);
    final clip = await repo.captureImage(
      mediaPath: path,
      mimeType: 'image/jpeg',
    );
    expect(clip.type, ClipType.image);
    expect(clip.mediaPath, path);
    expect(clip.mimeType, 'image/jpeg');
    expect(clip.content, isEmpty);
    expect(clip.byteSize, 1024);

    final history = await repo.watchHistory().first;
    expect(history, hasLength(1));
    expect(history.single.type, ClipType.image);
  });

  test('image dedup: same path bumps usage instead of inserting', () async {
    final path = await makeImageFile(512);
    await repo.captureImage(mediaPath: path, mimeType: 'image/png');
    await repo.captureImage(mediaPath: path, mimeType: 'image/png');

    final history = await repo.watchHistory().first;
    expect(history, hasLength(1));
    expect(history.single.usageCount, 2);
  });

  test('different images create separate rows', () async {
    final pathA = await makeImageFile(256);
    final pathB = await makeImageFile(512);
    await repo.captureImage(mediaPath: pathA, mimeType: 'image/jpeg');
    await repo.captureImage(mediaPath: pathB, mimeType: 'image/webp');

    final history = await repo.watchHistory().first;
    expect(history, hasLength(2));
  });

  test('image clips are not searchable (no FTS entry)', () async {
    final path = await makeImageFile(128);
    await repo.captureImage(mediaPath: path, mimeType: 'image/jpeg');
    await repo.capture(ev('a text clip to search for'));

    // Image should appear in history but not in search results.
    final history = await repo.watchHistory().first;
    expect(history, hasLength(2));

    final search = await repo.watchSearch('text').first;
    expect(search, hasLength(1));
    expect(search.single.content, contains('text clip'));
  });
}
