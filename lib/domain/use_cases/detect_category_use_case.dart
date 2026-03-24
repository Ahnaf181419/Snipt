import '../entities/clipboard_item.dart';

class DetectCategoryUseCase {
  Category call(String content, bool isImage) {
    if (isImage) return Category.image;

    final urlPattern = RegExp(
      r'^(https?:\/\/)?([\da-z\.-]+)\.([a-z\.]{2,6})([\/\w \.-]*)*\/?$',
      caseSensitive: false,
    );
    if (urlPattern.hasMatch(content)) return Category.url;

    final phonePattern = RegExp(r'^[\+]?[(]?[0-9]{1-4}[)]?[-\s\./0-9]{6,}$');
    if (phonePattern.hasMatch(content.replaceAll(' ', ''))) return Category.phone;

    return Category.text;
  }
}
