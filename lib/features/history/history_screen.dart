import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/haptics.dart';
import '../../data/db/database.dart';
import '../../data/providers.dart';
import '../../data/settings.dart';
import '../../domain/models/capture_event.dart';
import '../../widgets/empty_state.dart';
import 'widgets/clip_tile.dart';
import 'widgets/skeleton_clip_tile.dart';

/// Home: searchable, reactive clipboard history with pin / copy / delete.
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    // Restore any active search query so the text field matches the list state
    // if the screen is rebuilt while a search is in progress.
    _searchController =
        TextEditingController(text: ref.read(searchQueryProvider));
    _runRetention();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Prune expired, non-pinned clips once per launch.
  Future<void> _runRetention() async {
    final settings = await ref.read(settingsControllerProvider.future);
    if (!mounted) return;
    if (settings.retentionDays <= 0) return;
    final cutoff =
        DateTime.now().subtract(Duration(days: settings.retentionDays));
    if (!mounted) return;
    await ref.read(clipRepositoryProvider).prune(cutoff);
  }

  /// Reads the current clipboard via the native bridge (avoids duplicating the
  /// same logic that lives in [CaptureBridge.captureFromClipboard]).
  Future<void> _captureFromClipboard() async {
    final messenger = ScaffoldMessenger.of(context);
    await Haptics.light();
    final captured =
        await ref.read(captureBridgeProvider).captureFromClipboard();
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(captured ? 'Saved to history' : 'Clipboard is empty'),
      ),
    );
  }

  Future<void> _copy(Clip clip) async {
    await Haptics.light();
    await ref.read(clipActionsProvider).copy(clip);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied'), duration: Duration(seconds: 1)),
    );
  }

  Future<void> _delete(Clip clip) async {
    await Haptics.medium();
    await ref.read(clipActionsProvider).delete(clip.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Deleted'),
        action: SnackBarAction(
          label: 'Undo',
          // Re-capturing restores the content and clears the tombstone.
          onPressed: () => ref.read(clipRepositoryProvider).capture(
                CaptureEvent(content: clip.content, sourceApp: clip.sourceApp),
              ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final clips = ref.watch(clipListProvider);
    final query = ref.watch(searchQueryProvider);
    final settings = ref.watch(settingsControllerProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('snipt'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
            tooltip: 'Settings',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _captureFromClipboard,
        icon: const Icon(Icons.add),
        label: const Text('Capture'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: TextField(
              controller: _searchController,
              onChanged: (v) {
                ref.read(searchQueryProvider.notifier).set(v);
                setState(() {});
              },
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search clips',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          ref.read(searchQueryProvider.notifier).clear();
                          setState(() {});
                        },
                      ),
              ),
            ),
          ),
          if (settings != null && !settings.captureServiceEnabled)
            _SetupBanner(onTap: () => context.push('/onboarding')),
          Expanded(
            child: clips.when(
              loading: () => const SkeletonClipList(),
              error: (e, _) => EmptyState(
                icon: Icons.error_outline,
                title: 'Something went wrong',
                subtitle: '$e',
              ),
              data: (items) => _list(items, query),
            ),
          ),
        ],
      ),
    );
  }

  Widget _list(List<Clip> items, String query) {
    if (items.isEmpty) {
      return query.trim().isNotEmpty
          ? const EmptyState(
              icon: Icons.search_off,
              title: 'No matches found',
              subtitle: 'Try a different search term',
            )
          : const EmptyState(
              icon: Icons.assignment_outlined,
              title: 'No clips yet',
              subtitle: 'Copy text anywhere, then tap Capture to save it',
            );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 96),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final clip = items[i];
        return Dismissible(
          key: ValueKey(clip.id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 24),
            child: const Icon(Icons.delete_outline),
          ),
          onDismissed: (_) => _delete(clip),
          child: ClipTile(
            clip: clip,
            onCopy: () => _copy(clip),
            onTogglePin: () {
              Haptics.light();
              ref.read(clipActionsProvider).togglePin(clip);
            },
            onDelete: () => _delete(clip),
            onOpen: () => context.push('/detail', extra: clip),
          ),
        );
      },
    );
  }
}

class _SetupBanner extends StatelessWidget {
  const _SetupBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.secondaryContainer,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(Icons.bolt, color: scheme.onSecondaryContainer),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Finish capture setup to save clips faster',
                  style: TextStyle(color: scheme.onSecondaryContainer),
                ),
              ),
              Icon(Icons.chevron_right, color: scheme.onSecondaryContainer),
            ],
          ),
        ),
      ),
    );
  }
}
