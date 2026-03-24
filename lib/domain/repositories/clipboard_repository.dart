import '../entities/clipboard_item.dart';

abstract class ClipboardRepository {
  Future<List<ClipboardItem>> getRecentItems({int limit = 50});
  Future<List<ClipboardItem>> getBookmarkedItems();
  Future<List<ClipboardItem>> getDeletedItems();
  Future<List<ClipboardItem>> searchItems(String query);
  Future<ClipboardItem?> getItemById(int id);
  Future<ClipboardItem?> getItemByHash(String hash);
  Future<int> addItem(ClipboardItem item);
  Future<void> updateItem(ClipboardItem item);
  Future<void> deleteItem(int id);
  Future<void> softDeleteItem(int id);
  Future<void> restoreItem(int id);
  Future<void> toggleBookmark(int id);
  Future<void> deleteOldestNonBookmarked(int keepCount);
  Future<int> getTotalCount();
  Future<void> clearAll();
  Future<String> exportToJson();
}
