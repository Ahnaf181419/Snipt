import 'dart:convert';
import 'package:uuid/uuid.dart' as uuid_pkg;
import 'package:uuid/enums.dart';
import '../../domain/entities/clipboard_item.dart';
import '../../domain/repositories/clipboard_repository.dart';
import '../datasources/local_database.dart';
import '../models/clipboard_item_model.dart';

class ClipboardRepositoryImpl implements ClipboardRepository {
  final LocalDatabase _database;
  static const String _tableName = 'clipboard_items';
  final uuid_pkg.Uuid _uuid = const uuid_pkg.Uuid();

  ClipboardRepositoryImpl(this._database);

  @override
  Future<List<ClipboardItem>> getRecentItems({int limit = 50}) async {
    final maps = await _database.query(
      _tableName,
      where: 'is_deleted = ?',
      whereArgs: [0],
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return maps.map((map) => ClipboardItemModel.fromMap(map)).toList();
  }

  @override
  Future<List<ClipboardItem>> getBookmarkedItems() async {
    final maps = await _database.query(
      _tableName,
      where: 'is_bookmarked = ? AND is_deleted = ?',
      whereArgs: [1, 0],
      orderBy: 'updated_at DESC',
    );
    return maps.map((map) => ClipboardItemModel.fromMap(map)).toList();
  }

  @override
  Future<List<ClipboardItem>> getDeletedItems() async {
    final maps = await _database.query(
      _tableName,
      where: 'is_deleted = ?',
      whereArgs: [1],
      orderBy: 'updated_at DESC',
    );
    return maps.map((map) => ClipboardItemModel.fromMap(map)).toList();
  }

  @override
  Future<List<ClipboardItem>> searchItems(String query) async {
    final escapedQuery = query
        .replaceAll('\\', '\\\\')
        .replaceAll('%', '\\%')
        .replaceAll('_', '\\_');
    final maps = await _database.query(
      _tableName,
      where: 'content LIKE ? ESCAPE "\\" AND is_deleted = ?',
      whereArgs: ['%$escapedQuery%', 0],
      orderBy: 'created_at DESC',
    );
    return maps.map((map) => ClipboardItemModel.fromMap(map)).toList();
  }

  @override
  Future<ClipboardItem?> getItemById(int id) async {
    final maps = await _database.query(
      _tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return ClipboardItemModel.fromMap(maps.first);
  }

  @override
  Future<ClipboardItem?> getItemByHash(String hash) async {
    final maps = await _database.query(
      _tableName,
      where: 'content_hash = ?',
      whereArgs: [hash],
    );
    if (maps.isEmpty) return null;
    return ClipboardItemModel.fromMap(maps.first);
  }

  @override
  Future<int> addItem(ClipboardItem item) async {
    final model = ClipboardItemModel(
      content: item.content,
      contentType: item.contentType,
      isImage: item.isImage,
      isBookmarked: item.isBookmarked,
      isDeleted: item.isDeleted,
      category: item.category,
      contentHash: item.contentHash ?? _generateHash(item.content),
      createdAt: item.createdAt,
      updatedAt: item.updatedAt,
    );
    return await _database.insert(_tableName, model.toMap());
  }

  @override
  Future<void> updateItem(ClipboardItem item) async {
    final model = ClipboardItemModel.fromEntity(item);
    await _database.update(
      _tableName,
      model.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  @override
  Future<void> deleteItem(int id) async {
    await _database.delete(
      _tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> softDeleteItem(int id) async {
    await _database.update(
      _tableName,
      {
        'is_deleted': 1,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> restoreItem(int id) async {
    await _database.update(
      _tableName,
      {
        'is_deleted': 0,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> toggleBookmark(int id) async {
    await _database.rawUpdate(
      'UPDATE $_tableName SET is_bookmarked = NOT is_bookmarked, updated_at = ? WHERE id = ?',
      [DateTime.now().millisecondsSinceEpoch, id],
    );
  }

  @override
  Future<void> deleteOldestNonBookmarked(int keepCount) async {
    final count = await _database.count(
      _tableName,
      where: 'is_bookmarked = ? AND is_deleted = ?',
      whereArgs: [0, 0],
    );

    if (count <= keepCount) return;

    final itemsToDelete = count - keepCount;
    final oldestItems = await _database.query(
      _tableName,
      where: 'is_bookmarked = ? AND is_deleted = ?',
      whereArgs: [0, 0],
      orderBy: 'created_at ASC',
      limit: itemsToDelete,
    );

    for (final map in oldestItems) {
      await softDeleteItem(map['id'] as int);
    }
  }

  @override
  Future<int> getTotalCount() async {
    return await _database.count(
      _tableName,
      where: 'is_deleted = ?',
      whereArgs: [0],
    );
  }

  @override
  Future<void> clearAll() async {
    await _database.clearAll(_tableName);
  }

  @override
  Future<String> exportToJson() async {
    final items = await getRecentItems(limit: 1000);
    final bookmarked = await getBookmarkedItems();
    
    final Map<String, dynamic> exportData = {
      'exportDate': DateTime.now().toIso8601String(),
      'appVersion': '1.0.0',
      'recentItems': items.map((item) => _itemToJson(item)).toList(),
      'bookmarkedItems': bookmarked.map((item) => _itemToJson(item)).toList(),
    };
    
    return jsonEncode(exportData);
  }

  Map<String, dynamic> _itemToJson(ClipboardItem item) {
    return {
      'id': item.id,
      'content': item.content,
      'contentType': item.contentType.name,
      'category': item.category.name,
      'isBookmarked': item.isBookmarked,
      'createdAt': item.createdAt,
      'updatedAt': item.updatedAt,
    };
  }

  // ignore: deprecated_member_use
  String _generateHash(String content) {
    return _uuid.v5(Namespace.url.value, content);
  }
}
