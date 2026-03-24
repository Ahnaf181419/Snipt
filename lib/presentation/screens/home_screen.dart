import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../bloc/clipboard/clipboard_bloc.dart';
import '../bloc/clipboard/clipboard_event.dart';
import '../bloc/clipboard/clipboard_state.dart';
import '../widgets/clipboard_item_card.dart';
import '../widgets/favorites_tray.dart';
import '../widgets/search_bar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ClipboardBloc>().add(const LoadRecentItems());
      context.read<ClipboardBloc>().add(LoadBookmarkedItems());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.appName)),
      body: Column(
        children: [
          CustomSearchBar(
            controller: _searchController,
            onChanged: (query) {
              context.read<ClipboardBloc>().add(SearchItems(query));
            },
            onClear: () {
              context.read<ClipboardBloc>().add(ClearSearch());
            },
          ),
          BlocBuilder<ClipboardBloc, ClipboardState>(
            builder: (context, state) {
              if (!state.isSearching) {
                return FavoritesTray(
                  items: state.bookmarkedItems,
                  onItemTap: (_) {},
                );
              }
              return const SizedBox.shrink();
            },
          ),
          Expanded(
            child: BlocBuilder<ClipboardBloc, ClipboardState>(
              builder: (context, state) {
                if (state.status == ClipboardLoadStatus.loading) {
                  return const Center(child: CircularProgressIndicator());
                }

                final items = state.isSearching
                    ? state.searchResults
                    : state.recentItems;

                if (items.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.content_paste_off,
                          size: 64,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          state.isSearching
                              ? 'No results found'
                              : AppStrings.noItems,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    context.read<ClipboardBloc>().add(const LoadRecentItems());
                  },
                  child: ListView.builder(
                    itemCount: items.length,
                    padding: const EdgeInsets.only(bottom: 80),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return ClipboardItemCard(
                        item: item,
                        onBookmark: () {
                          if (item.id != null) {
                            context.read<ClipboardBloc>().add(
                              ToggleBookmark(item.id!),
                            );
                          }
                        },
                        onDelete: () {
                          if (item.id != null) {
                            _showDeleteConfirmation(context, item.id!);
                          }
                        },
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
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
              context.read<ClipboardBloc>().add(
                SoftDeleteClipboardItem(itemId),
              );
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(AppStrings.itemDeleted),
                  action: SnackBarAction(
                    label: AppStrings.undo,
                    onPressed: () {
                      context.read<ClipboardBloc>().add(
                        RestoreClipboardItem(itemId),
                      );
                    },
                  ),
                ),
              );
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
