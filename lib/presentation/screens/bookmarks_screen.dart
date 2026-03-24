import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../bloc/clipboard/clipboard_bloc.dart';
import '../bloc/clipboard/clipboard_event.dart';
import '../bloc/clipboard/clipboard_state.dart';
import '../widgets/clipboard_item_card.dart';

class BookmarksScreen extends StatefulWidget {
  const BookmarksScreen({super.key});

  @override
  State<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends State<BookmarksScreen> {
  @override
  void initState() {
    super.initState();
    context.read<ClipboardBloc>().add(LoadBookmarkedItems());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.bookmarks),
      ),
      body: BlocBuilder<ClipboardBloc, ClipboardState>(
        builder: (context, state) {
          if (state.status == ClipboardLoadStatus.loading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final items = state.bookmarkedItems;

          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.bookmark_border,
                    size: 64,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    AppStrings.noBookmarks,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: items.length,
            padding: const EdgeInsets.only(bottom: 80),
            itemBuilder: (context, index) {
              final item = items[index];
              return ClipboardItemCard(
                item: item,
                onBookmark: () {
                  if (item.id != null) {
                    context.read<ClipboardBloc>().add(ToggleBookmark(item.id!));
                  }
                },
                onDelete: () {
                  if (item.id != null) {
                    _showDeleteConfirmation(context, item.id!);
                  }
                },
              );
            },
          );
        },
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, int itemId) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          AppStrings.delete,
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          AppStrings.clearAllConfirm,
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              AppStrings.cancel,
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              context.read<ClipboardBloc>().add(DeleteClipboardItem(itemId));
            },
            child: Text(
              AppStrings.delete,
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}
