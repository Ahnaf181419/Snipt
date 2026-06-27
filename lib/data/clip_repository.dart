import 'dart:convert';
import 'dart:io';

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

  /// Callback the UI sets to read whether the user owns Pro. The free-tier
  /// cap is enforced only when this is false. Defaults to `false` so a
  /// caller that forgets to wire it stays in the safe (capped) state.
  /// Wired from `providers.dart` after the settings store is ready.
  bool Function() isProSupplier = () => false;

  /// Active history, most-recently-used first, pinned entries floated to top.
  /// Sorted by [updatedAt] (not createdAt) so that copying a clip floats it
  /// back to the top without corrupting the immutable "Saved" timestamp.
  Stream<List<Clip>> watchHistory({int limit = AppConstants.historyPageSize}) {
    final query = _db.select(_db.clips)
      ..where((t) => t.deletedAt.isNull())
      ..orderBy([
        (t) => OrderingTerm.desc(t.isPinned),
        (t) => OrderingTerm.desc(t.updatedAt),
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
          'ORDER BY clips.is_pinned DESC, clips.updated_at DESC '
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

    // Hard cap: reject payloads that would bloat the DB and FTS index.
    if (utf8.encode(content).length > AppConstants.maxClipBytes) {
      return Future.error(
        ArgumentError('Clip exceeds maxClipBytes (${AppConstants.maxClipBytes} bytes)'),
      );
    }

    final type = ClipType.classify(content);
    final hash = _hash(type, content);
    final now = DateTime.now();

    return _db.transaction(() async {
      final existing = await (_db.select(_db.clips)
            ..where((t) => t.contentHash.equals(hash)))
          .getSingleOrNull();

      if (existing != null) {
        // Keep createdAt immutable — it represents the original capture time
        // displayed as "Saved" in the detail screen. Only updatedAt moves.
        final refreshed = existing.copyWith(
          updatedAt: now,
          usageCount: existing.usageCount + 1,
          // Value(null) clears any tombstone (undelete); Value.absent() would
          // keep the row hidden when re-capturing previously deleted content.
          deletedAt: const Value(null),
          sourceApp: Value(event.sourceApp ?? existing.sourceApp),
        );
        await _db.update(_db.clips).replace(refreshed);
        // Re-index using the stored content (not the event payload) to keep
        // the FTS table consistent with what is actually in the clips row.
        await _reindex(existing.id, existing.content);
        return refreshed;
      }

      // Free-tier cap: if a non-Pro user is at the cap, prune the oldest
      // non-pinned, non-tombstoned rows until we have room. Pinned rows
      // are never removed by the cap (mirroring the existing retention
      // rule). We do this *before* the insert so the new clip always fits.
      if (!isProSupplier()) {
        await _enforceFreeTierCap();
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

  /// Persist an image capture. Dedup is keyed on the file path's hash so
  /// re-sharing the same photo doesn't create a duplicate. Image rows have
  /// empty [content] and no FTS entry.
  Future<Clip> captureImage({
    required String mediaPath,
    required String mimeType,
    String? sourceApp,
  }) async {
    final hash = sha256.convert(utf8.encode('image:$mediaPath')).toString();
    final now = DateTime.now();
    final file = File(mediaPath);
    final size = await file.length();

    return _db.transaction(() async {
      final existing = await (_db.select(_db.clips)
            ..where((t) => t.contentHash.equals(hash)))
          .getSingleOrNull();
      if (existing != null) {
        final refreshed = existing.copyWith(
          updatedAt: now,
          usageCount: existing.usageCount + 1,
          deletedAt: const Value(null),
          sourceApp: Value(sourceApp ?? existing.sourceApp),
        );
        await _db.update(_db.clips).replace(refreshed);
        return refreshed;
      }

      if (!isProSupplier()) {
        await _enforceMediaSizeCap(size);
      }

      final clip = Clip(
        id: _uuid.v4(),
        type: ClipType.image,
        content: '',
        contentHash: hash,
        byteSize: size,
        isPinned: false,
        sourceApp: sourceApp,
        usageCount: 1,
        createdAt: now,
        updatedAt: now,
        deletedAt: null,
        mediaPath: mediaPath,
        mimeType: mimeType,
      );
      await _db.into(_db.clips).insert(clip);
      return clip;
    });
  }

  /// Drops oldest non-pinned, non-tombstoned image clips (and unlinks their
  /// files) until total media bytes + [incomingBytes] fits within the
  /// free-tier budget. No-op for Pro users.
  Future<void> _enforceMediaSizeCap(int incomingBytes) async {
    final images = await (_db.select(_db.clips)
          ..where((t) =>
              t.type.equals(ClipType.image.index) &
              t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.updatedAt)]))
        .get();
    final totalBytes = images.fold<int>(0, (sum, c) => sum + c.byteSize);
    if (totalBytes + incomingBytes <= AppConstants.freeTierMediaBytes) return;

    var budget = totalBytes + incomingBytes - AppConstants.freeTierMediaBytes;
    for (final clip in images) {
      if (clip.isPinned) continue;
      if (budget <= 0) break;
      await _unlinkMedia(clip.mediaPath);
      await _db.customStatement('DELETE FROM clip_fts WHERE id = ?', [clip.id]);
      await (_db.delete(_db.clips)..where((t) => t.id.equals(clip.id))).go();
      budget -= clip.byteSize;
    }
  }

  /// Deletes the media file at [path] if it exists. Swallows errors so a
  /// missing file never blocks a DB transaction.
  Future<void> _unlinkMedia(String? path) async {
    if (path == null) return;
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Best-effort: a missing file is not a failure.
    }
  }

  /// Removes the oldest non-pinned, non-tombstoned rows so that the active
  /// row count is below [AppConstants.freeTierClipCap]. Leaves a 5% margin
  /// so a small burst of captures doesn't trigger a prune on every single
  /// one. No-op for Pro users.
  Future<void> _enforceFreeTierCap() async {
    // Use a raw count query so we don't depend on selectOnly's table-type
    // inference (which is sensitive to clause order in this Drift version).
    final countRow = await _db.customSelect(
      'SELECT COUNT(*) AS c FROM clips WHERE deleted_at IS NULL',
      readsFrom: {_db.clips},
    ).getSingle();
    final count = countRow.read<int>('c');
    final target = (AppConstants.freeTierClipCap * 0.95).floor();
    if (count < target) return;
    // Prune the (count - target + 1) oldest non-pinned rows.
    final excess = count - target + 1;
    final victims = await (_db.select(_db.clips)
          ..where((t) => t.isPinned.equals(false) & t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.updatedAt)])
          ..limit(excess))
        .get();
    for (final v in victims) {
      await _unlinkMedia(v.mediaPath);
      await _db.customStatement('DELETE FROM clip_fts WHERE id = ?', [v.id]);
    }
    final ids = victims.map((v) => v.id).toList();
    if (ids.isNotEmpty) {
      await (_db.delete(_db.clips)..where((t) => t.id.isIn(ids))).go();
    }
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
  /// the search index. For image clips, the media file is also unlinked since
  /// it can never be restored from a tombstone row.
  Future<void> softDelete(String id) async {
    final clip = await (_db.select(_db.clips)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (clip == null) return;
    await _unlinkMedia(clip.mediaPath);
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
  /// Updates updatedAt (to float the clip to top) but leaves createdAt intact
  /// so the detail screen's "Saved" timestamp stays accurate.
  Future<void> bumpUsage(String id) async {
    final clip = await (_db.select(_db.clips)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (clip == null) return;
    await (_db.update(_db.clips)..where((t) => t.id.equals(id))).write(
      ClipsCompanion(
        usageCount: Value(clip.usageCount + 1),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Prune non-pinned, non-tombstoned clips not touched since [cutoff].
  /// Returns rows removed. Already-tombstoned rows are excluded so sync
  /// tombstones are not destroyed before a future sync peer can observe them.
  Future<int> prune(DateTime cutoff) async {
    return _db.transaction(() async {
      final victims = await (_db.select(_db.clips)
            ..where((t) =>
                t.isPinned.equals(false) &
                t.deletedAt.isNull() &
                t.updatedAt.isSmallerThanValue(cutoff)))
          .get();
      if (victims.isEmpty) return 0;
      for (final c in victims) {
        await _unlinkMedia(c.mediaPath);
      }
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
  /// Strips all FTS5 syntax characters to prevent query parse errors.
  String? _toFtsQuery(String raw) {
    final tokens = raw
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        // Strip all FTS5 operators/meta-chars — not just quotes — to prevent
        // SQLite parse errors on input like "(test", "-word", "a^b", etc.
        .map((t) => t.replaceAll(RegExp(r'["\(\)\^\-\*\\]'), ''))
        .where((t) => t.isNotEmpty)
        .map((t) => '"$t"*') // quoted prefix token
        .toList();
    return tokens.isEmpty ? null : tokens.join(' ');
  }
}
