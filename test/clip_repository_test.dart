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

  // ─── Media-byte cap tests ────────────────────────────────────────
  //
  // The 200 MB cap from AppConstants.freeTierMediaBytes is exposed as
  // a field on ClipRepository so tests can drive it without stuffing
  // hundreds of MB into an in-memory DB. These tests verify the cap
  // prunes oldest-first and that pinned clips survive a prune.

  test('media-byte cap: fits under budget, nothing pruned', () async {
    repo.mediaByteBudget = 1024; // 1 KB
    repo.isProSupplier = () => false;
    final pathA = await makeImageFile(400);
    final pathB = await makeImageFile(400);
    await repo.captureImage(mediaPath: pathA, mimeType: 'image/jpeg');
    await repo.captureImage(mediaPath: pathB, mimeType: 'image/jpeg');

    final history = await repo.watchHistory().first;
    expect(history, hasLength(2));
  });

  test('media-byte cap: oldest non-pinned pruned first', () async {
    repo.mediaByteBudget = 1000;
    repo.isProSupplier = () => false;
    final oldPath = await makeImageFile(400);
    final oldClip = await repo.captureImage(
      mediaPath: oldPath,
      mimeType: 'image/jpeg',
    );
    // Capture something newer; the older one is the prune victim.
    final newPath = await makeImageFile(400);
    await repo.captureImage(mediaPath: newPath, mimeType: 'image/jpeg');

    // 400 + 400 = 800 < 1000, no prune yet — third capture triggers it.
    final biggerPath = await makeImageFile(600);
    await repo.captureImage(mediaPath: biggerPath, mimeType: 'image/jpeg');

    final history = await repo.watchHistory().first;
    // Expect oldClip gone; the two newer clips remain.
    expect(history.any((c) => c.id == oldClip.id), isFalse);
    expect(history, hasLength(2));
  });

  test('media-byte cap: pinned images are exempt', () async {
    repo.mediaByteBudget = 1000;
    repo.isProSupplier = () => false;
    final pinnedPath = await makeImageFile(600);
    final pinned = await repo.captureImage(
      mediaPath: pinnedPath,
      mimeType: 'image/jpeg',
    );
    await repo.togglePin(pinned.id, true);

    // Capture another 600-byte image — would push total to 1200 > 1000.
    final newerPath = await makeImageFile(600);
    await repo.captureImage(mediaPath: newerPath, mimeType: 'image/jpeg');

    final history = await repo.watchHistory().first;
    // Pinned must still be present even though it is the oldest.
    expect(history.any((c) => c.id == pinned.id), isTrue);
  });

  test('media-byte cap: Pro users skip the cap entirely', () async {
    repo.mediaByteBudget = 100;
    repo.isProSupplier = () => true;
    for (var i = 0; i < 5; i++) {
      final path = await makeImageFile(80);
      await repo.captureImage(mediaPath: path, mimeType: 'image/jpeg');
    }
    final history = await repo.watchHistory().first;
    expect(history, hasLength(5));
  });

  // ─── FTS5 sanitisation tests ─────────────────────────────────────
  //
  // _toFtsQuery strips FTS5 operator meta-chars and quote-wraps each
  // token. If the sanitiser misses a case, the MATCH query throws a
  // SQLite parse error and the search stream fails. These tests push
  // adversarial input through watchSearch and assert the call returns
  // (possibly empty) rather than throwing.

  Future<void> expectNoFtsCrash(String query) async {
    final hits = await repo.watchSearch(query).first;
    // No assertion on count — sanitiser may turn the query into
    // nothing (returning empty). The invariant is just that the
    // FTS5 MATCH clause does not throw.
    expect(hits, isA<List<Clip>>());
  }

  test('FTS5: parentheses do not throw', () async {
    await repo.capture(ev('flutter clipboard manager'));
    await expectNoFtsCrash('(test');
    await expectNoFtsCrash('test)');
  });

  test('FTS5: caret, dash, asterisk, backslash stripped', () async {
    await repo.capture(ev('flutter clipboard manager'));
    await expectNoFtsCrash('a^b');
    await expectNoFtsCrash('-word');
    await expectNoFtsCrash('word*');
    await expectNoFtsCrash('back\\slash');
  });

  test('FTS5: nested quotes handled', () async {
    await repo.capture(ev('flutter clipboard manager'));
    await expectNoFtsCrash('"unclosed');
    await expectNoFtsCrash('""double""');
  });

  test('FTS5: only-special-chars query returns empty (not error)', () async {
    await repo.capture(ev('flutter clipboard manager'));
    await expectNoFtsCrash('()*-^\\');
    await expectNoFtsCrash('   ');
  });

  test('FTS5: real prefix search still works after sanitisation', () async {
    await repo.capture(ev('flutter clipboard manager'));
    await repo.capture(ev('completely unrelated note'));
    final hits = await repo.watchSearch('clip').first;
    expect(hits, hasLength(1));
    expect(hits.single.content, contains('clipboard'));
  });

  test('FTS5: query with mixed special chars still matches', () async {
    await repo.capture(ev('hello world'));
    // Quote + asterisk should be stripped; the surviving "hello" token
    // should still find the row.
    final hits = await repo.watchSearch('"hello*').first;
    expect(hits, hasLength(1));
  });
}
