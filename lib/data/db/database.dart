import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../domain/models/clip_type.dart';
import 'database_key.dart';

part 'database.g.dart';

/// Clipboard entries. The schema is sync-ready from day one:
///   * [id] is a UUID (not autoincrement) so rows can be created on any device
///   * [updatedAt] supports last-write-wins conflict resolution
///   * [deletedAt] is a soft-delete tombstone (rows are kept for future sync)
///   * [contentHash] is UNIQUE, giving O(1) duplicate detection
class Clips extends Table {
  TextColumn get id => text()();
  IntColumn get type => intEnum<ClipType>()();
  TextColumn get content => text()();
  TextColumn get contentHash => text().unique()();
  IntColumn get byteSize => integer()();
  BoolColumn get isPinned => boolean().withDefault(const Constant(false))();
  TextColumn get sourceApp => text().nullable()();
  IntColumn get usageCount => integer().withDefault(const Constant(1))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DriftDatabase(tables: [Clips])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _open());

  /// In-memory database for tests.
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          // Standalone FTS5 index (not external-content) kept in sync by the
          // DAO inside the same transaction as writes — avoids trigger drift.
          await customStatement(
            'CREATE VIRTUAL TABLE clip_fts USING fts5(id UNINDEXED, content)',
          );
          await customStatement(
            'CREATE INDEX idx_clips_active ON clips '
            '(deleted_at, is_pinned, created_at)',
          );
        },
      );

  static LazyDatabase _open() {
    return LazyDatabase(() async {
      final dir = await getApplicationDocumentsDirectory();
      final file = File(p.join(dir.path, 'snipt.sqlite'));
      // SQLCipher: the key is generated on first launch and stored in the
      // Android Keystore via flutter_secure_storage. Without it the database
      // is unreadable, so clipboard contents are protected at rest.
      final key = await DatabaseKeyManager.getOrCreate();
      return NativeDatabase.createInBackground(
        file,
        setup: (db) {
          db.execute("PRAGMA key = '$key'");
        },
      );
    });
  }
}
