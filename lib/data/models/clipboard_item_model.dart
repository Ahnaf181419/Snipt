import '../../domain/entities/clipboard_item.dart';

class ClipboardItemModel extends ClipboardItem {
  const ClipboardItemModel({
    super.id,
    required super.content,
    required super.contentType,
    super.isImage = false,
    super.isBookmarked = false,
    super.isDeleted = false,
    super.category = Category.text,
    super.contentHash,
    required super.createdAt,
    required super.updatedAt,
  });

  factory ClipboardItemModel.fromMap(Map<String, dynamic> map) {
    return ClipboardItemModel(
      id: map['id'] as int?,
      content: map['content'] as String,
      contentType: map['content_type'] == 'text'
          ? ContentType.text
          : ContentType.image,
      isImage: (map['is_image'] as int) == 1,
      isBookmarked: (map['is_bookmarked'] as int) == 1,
      isDeleted: (map['is_deleted'] as int) == 1,
      category: _categoryFromString(map['category'] as String),
      contentHash: map['content_hash'] as String?,
      createdAt: map['created_at'] as int,
      updatedAt: map['updated_at'] as int,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'content': content,
      'content_type': contentType == ContentType.text ? 'text' : 'image',
      'is_image': isImage ? 1 : 0,
      'is_bookmarked': isBookmarked ? 1 : 0,
      'is_deleted': isDeleted ? 1 : 0,
      'category': _categoryToString(category),
      'content_hash': contentHash,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory ClipboardItemModel.fromEntity(ClipboardItem entity) {
    return ClipboardItemModel(
      id: entity.id,
      content: entity.content,
      contentType: entity.contentType,
      isImage: entity.isImage,
      isBookmarked: entity.isBookmarked,
      isDeleted: entity.isDeleted,
      category: entity.category,
      contentHash: entity.contentHash,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
    );
  }

  static Category _categoryFromString(String value) {
    switch (value) {
      case 'url':
        return Category.url;
      case 'phone':
        return Category.phone;
      case 'image':
        return Category.image;
      default:
        return Category.text;
    }
  }

  static String _categoryToString(Category category) {
    switch (category) {
      case Category.url:
        return 'url';
      case Category.phone:
        return 'phone';
      case Category.image:
        return 'image';
      case Category.text:
        return 'text';
    }
  }
}
