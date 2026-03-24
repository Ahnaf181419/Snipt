import 'package:equatable/equatable.dart';

abstract class ClipboardEvent extends Equatable {
  const ClipboardEvent();

  @override
  List<Object?> get props => [];
}

class LoadRecentItems extends ClipboardEvent {
  final int limit;
  
  const LoadRecentItems({this.limit = 50});
  
  @override
  List<Object?> get props => [limit];
}

class LoadBookmarkedItems extends ClipboardEvent {}

class AddClipboardItem extends ClipboardEvent {
  final String content;
  final bool isImage;
  
  const AddClipboardItem({required this.content, this.isImage = false});
  
  @override
  List<Object?> get props => [content, isImage];
}

class DeleteClipboardItem extends ClipboardEvent {
  final int id;
  
  const DeleteClipboardItem(this.id);
  
  @override
  List<Object?> get props => [id];
}

class SoftDeleteClipboardItem extends ClipboardEvent {
  final int id;
  
  const SoftDeleteClipboardItem(this.id);
  
  @override
  List<Object?> get props => [id];
}

class RestoreClipboardItem extends ClipboardEvent {
  final int id;
  
  const RestoreClipboardItem(this.id);
  
  @override
  List<Object?> get props => [id];
}

class ToggleBookmark extends ClipboardEvent {
  final int id;
  
  const ToggleBookmark(this.id);
  
  @override
  List<Object?> get props => [id];
}

class SearchItems extends ClipboardEvent {
  final String query;
  
  const SearchItems(this.query);
  
  @override
  List<Object?> get props => [query];
}

class ClearSearch extends ClipboardEvent {}

class ClearAllItems extends ClipboardEvent {}

class UpdateStorageLimit extends ClipboardEvent {
  final int limit;
  
  const UpdateStorageLimit(this.limit);
  
  @override
  List<Object?> get props => [limit];
}
