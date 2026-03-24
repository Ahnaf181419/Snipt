import 'package:equatable/equatable.dart';

enum ContentType { text, image }

enum Category { text, url, phone, image }

class ClipboardItem extends Equatable {
  final int? id;
  final String content;
  final ContentType contentType;
  final bool isImage;
  final bool isBookmarked;
  final bool isDeleted;
  final Category category;
  final String? contentHash;
  final int createdAt;
  final int updatedAt;

  const ClipboardItem({
    this.id,
    required this.content,
    required this.contentType,
    this.isImage = false,
    this.isBookmarked = false,
    this.isDeleted = false,
    this.category = Category.text,
    this.contentHash,
    required this.createdAt,
    required this.updatedAt,
  });

  ClipboardItem copyWith({
    int? id,
    String? content,
    ContentType? contentType,
    bool? isImage,
    bool? isBookmarked,
    bool? isDeleted,
    Category? category,
    String? contentHash,
    int? createdAt,
    int? updatedAt,
  }) {
    return ClipboardItem(
      id: id ?? this.id,
      content: content ?? this.content,
      contentType: contentType ?? this.contentType,
      isImage: isImage ?? this.isImage,
      isBookmarked: isBookmarked ?? this.isBookmarked,
      isDeleted: isDeleted ?? this.isDeleted,
      category: category ?? this.category,
      contentHash: contentHash ?? this.contentHash,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        content,
        contentType,
        isImage,
        isBookmarked,
        isDeleted,
        category,
        contentHash,
        createdAt,
        updatedAt,
      ];
}
