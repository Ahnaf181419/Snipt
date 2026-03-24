import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/utils/date_formatter.dart';
import '../../domain/entities/clipboard_item.dart';

class ClipboardItemCard extends StatelessWidget {
  final ClipboardItem item;
  final VoidCallback? onTap;
  final VoidCallback? onBookmark;
  final VoidCallback? onDelete;

  const ClipboardItemCard({
    super.key,
    required this.item,
    this.onTap,
    this.onBookmark,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key('clipboard_${item.id}'),
      background: _buildSwipeBackground(
        color: AppColors.bookmark,
        icon: Icons.bookmark,
        alignment: Alignment.centerLeft,
      ),
      secondaryBackground: _buildSwipeBackground(
        color: AppColors.delete,
        icon: Icons.delete,
        alignment: Alignment.centerRight,
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          onBookmark?.call();
          return false;
        } else {
          onDelete?.call();
          return false;
        }
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: InkWell(
          onTap: () {
            _copyToClipboard(context);
            onTap?.call();
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCategoryIcon(),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildContent(),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              _buildCategoryBadge(),
                              const SizedBox(width: 8),
                              Text(
                                DateFormatter.formatTimestamp(item.createdAt),
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          if (item.isBookmarked)
                            Icon(
                              Icons.bookmark,
                              color: AppColors.bookmark,
                              size: 20,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSwipeBackground({
    required Color color,
    required IconData icon,
    required Alignment alignment,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Icon(
        icon,
        color: Colors.white,
        size: 28,
      ),
    );
  }

  Widget _buildCategoryIcon() {
    IconData iconData;
    Color iconColor;

    switch (item.category) {
      case Category.url:
        iconData = Icons.link;
        iconColor = AppColors.accent;
        break;
      case Category.phone:
        iconData = Icons.phone;
        iconColor = AppColors.success;
        break;
      case Category.image:
        iconData = Icons.image;
        iconColor = AppColors.warning;
        break;
      case Category.text:
        iconData = Icons.text_snippet;
        iconColor = AppColors.textSecondary;
    }

    if (item.isImage) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          File(item.content),
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(iconData, color: iconColor),
            );
          },
        ),
      );
    }

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(iconData, color: iconColor),
    );
  }

  Widget _buildContent() {
    if (item.isImage) {
      return Text(
        AppStrings.image,
        style: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 14,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      );
    }

    return Text(
      item.content,
      style: TextStyle(
        color: AppColors.textPrimary,
        fontSize: 14,
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildCategoryBadge() {
    String label;
    Color color;

    switch (item.category) {
      case Category.url:
        label = 'URL';
        color = AppColors.accent;
        break;
      case Category.phone:
        label = 'Phone';
        color = AppColors.success;
        break;
      case Category.image:
        label = 'Image';
        color = AppColors.warning;
        break;
      case Category.text:
        return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  void _copyToClipboard(BuildContext context) {
    if (item.isImage) {
      Clipboard.setData(ClipboardData(text: item.content));
    } else {
      Clipboard.setData(ClipboardData(text: item.content));
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: AppColors.success, size: 20),
            const SizedBox(width: 8),
            Text(AppStrings.copied),
          ],
        ),
        duration: const Duration(seconds: 1),
      ),
    );
  }
}
