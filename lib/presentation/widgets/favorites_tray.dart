import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../domain/entities/clipboard_item.dart';

class FavoritesTray extends StatelessWidget {
  final List<ClipboardItem> items;
  final Function(ClipboardItem)? onItemTap;

  const FavoritesTray({
    super.key,
    required this.items,
    this.onItemTap,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      height: 100,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              AppStrings.favorites,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: items.length > 5 ? 5 : items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return _buildFavoriteItem(item);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFavoriteItem(ClipboardItem item) {
    return GestureDetector(
      onTap: () {
        Clipboard.setData(ClipboardData(text: item.content));
        onItemTap?.call(item);
      },
      child: Container(
        width: 80,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: item.isBookmarked ? AppColors.bookmark : AppColors.divider,
            width: 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _getCategoryIcon(item.category),
              color: AppColors.accent,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              _getPreviewText(item.content),
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 10,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  IconData _getCategoryIcon(Category category) {
    switch (category) {
      case Category.url:
        return Icons.link;
      case Category.phone:
        return Icons.phone;
      case Category.image:
        return Icons.image;
      case Category.text:
        return Icons.text_snippet;
    }
  }

  String _getPreviewText(String content) {
    if (content.length > 20) {
      return '${content.substring(0, 20)}...';
    }
    return content;
  }
}
