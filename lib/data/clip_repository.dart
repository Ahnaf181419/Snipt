import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../core/constants.dart';
import '../domain/models/capture_event.dart';
import '../domain/models/clip_type.dart';
import 'db/database.dart';

/// Single source of truth for clipboard entries. Owns hashing, duplicate
/// collapsing and the FTS index so callers never touch SQL.
///
/// A future `RemoteSyncRepository` can wrap this same surface to push/pull
/// the sync-ready columns (id / updatedAt / deletedAt).
class ClipRepository {
  ClipRepository(this._db, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final AppDatabase _db;
  final Uuid _uuid;

  /// Active history, newest first, pinned entries floated to the top.
  Stream<List<Clip>> watchHistory({int limit = AppConstants.historyPageSize}) {
    final query = _db.select(_db.clips)
      ..where((t) => t.deletedAt.isNull())
      ..orderBy([
        (t) => OrderingTerm.desc(t.isPinned),
        (t) => OrderingTerm.desc(t.createdAt),
      ])
      ..limit(limit);
    return query.watch();
  }

  /// Full-text search over active clips (prefix match, search-as-you-type).
  Stream<List<Clip>> watchSearch(String rawQuery,
      {int limit = AppConstants.historyPageSize}) {
    final match = _toFtsQuery(rawQuery);
    if (match == null) return watchHistory(limit: limit);
    return _db
        .customSelect(
          'SELECT clips.* FROM clips '
          'JOIN clip_fts ON clip_fts.id = clips.id '
          'WHERE clip_fts MATCH ?1 AND clips.deleted_at IS NULL '
          'ORDER BY clips.is_pinned DESC, clips.created_at DESC '
          'LIMIT ?2',
          variables: [Variable.withString(match), Variable.withInt(limit)],
          readsFrom: {_db.clips},
        )
        .watch()
        .map((rows) => rows.map((r) => _db.clips.map(r.data)).toList());
  }

  /// Persist a capture. Duplicates (same type + content) are collapsed onto the
  /// existing row, which is refreshed and floated back to the top.
  Future<Clip> capture(CaptureEvent event) async {
    final content = event.content.trim();
    final type = ClipType.classify(content);
    final hash = _hash(type, content);
    final now = DateTime.now();

    return _db.transaction(() async {
      final existing = await (_db.select(_db.clips)
            ..where((t) => t.contentHash.equals(hash)))
          .getSingleOrNull();

      if (existing != null) {
        final refreshed = existing.copyWith(
          createdAt: now,
          updatedAt: now,
          usageCount: existing.usageCount + 1,
          deletedAt: const Value.absent(),
          sourceApp: Value(event.sourceApp ?? existing.sourceApp),
        );
        await _db.update(_db.clips).replace(refreshed);
        // A previously pruned duplicate would be gone from the index; re-add.
        await _reindex(existing.id, content);
        return refreshed;
      }

      final clip = Clip(
        id: _uuid.v4(),
        type: type,
        content: content,
        contentHash: hash,
        byteSize: utf8.encode(content).length,
        isPinned: false,
        sourceApp: event.sourceApp,
        usageCount: 1,
        createdAt: now,
        updatedAt: now,
        deletedAt: null,
      );
      await _db.into(_db.clips).insert(clip);
      await _reindex(clip.id, content);
      return clip;
    });
  }

  Future<void> togglePin(String id, bool isPinned) async {
    await (_db.update(_db.clips)..where((t) => t.id.equals(id))).write(
      ClipsCompanion(
        isPinned: Value(isPinned),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Soft delete: tombstone the row (kept for future sync) and drop it from
  /// the search index.
  Future<void> softDelete(String id) async {
    await _db.transaction(() async {
      await (_db.update(_db.clips)..where((t) => t.id.equals(id))).write(
        ClipsCompanion(
          deletedAt: Value(DateTime.now()),
          updatedAt: Value(DateTime.now()),
        ),
      );
      await _db.customStatement('DELETE FROM clip_fts WHERE id = ?', [id]);
    });
  }

  /// Called when a clip is re-copied to the system clipboard from the app.
  Future<void> bumpUsage(String id) async {
    await _db.customStatement(
      'UPDATE clips SET usage_count = usage_count + 1, '
      'created_at = ?1, updated_at = ?1 WHERE id = ?2',
      [DateTime.now().millisecondsSinceEpoch ~/ 1000, id],
    );
  }

  /// Prune non-pinned clips last touched before [cutoff]. Returns rows removed.
  Future<int> prune(DateTime cutoff) async {
    return _db.transaction(() async {
      final victims = await (_db.select(_db.clips)
            ..where((t) =>
                t.isPinned.equals(false) &
                t.createdAt.isSmallerThanValue(cutoff)))
          .get();
      if (victims.isEmpty) return 0;
      final ids = victims.map((c) => c.id).toList();
      await (_db.delete(_db.clips)..where((t) => t.id.isIn(ids))).go();
      for (final id in ids) {
        await _db.customStatement('DELETE FROM clip_fts WHERE id = ?', [id]);
      }
      return ids.length;
    });
  }

  Future<void> _reindex(String id, String content) async {
    await _db.customStatement('DELETE FROM clip_fts WHERE id = ?', [id]);
    await _db.customStatement(
      'INSERT INTO clip_fts(id, content) VALUES(?, ?)',
      [id, content],
    );
  }

  String _hash(ClipType type, String content) =>
      sha256.convert(utf8.encode('${type.index}:$content')).toString();

  /// Builds a safe FTS5 prefix query from free-form input, or null if empty.
  String? _toFtsQuery(String raw) {
    final tokens = raw
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .map((t) => t.replaceAll('"', '')) // strip quotes to avoid syntax errs
        .where((t) => t.isNotEmpty)
        .map((t) => '"$t"*') // quoted prefix token
        .toList();
    return tokens.isEmpty ? null : tokens.join(' ');
  }
}
