import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/db/database.dart';
import '../../data/providers.dart';
import '../../data/settings.dart';
import '../../domain/models/capture_event.dart';
import 'widgets/clip_tile.dart';

/// Home: searchable, reactive clipboard history with pin / copy / delete.
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
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
    if (settings.retentionDays <= 0) return;
    final cutoff =
        DateTime.now().subtract(Duration(days: settings.retentionDays));
    await ref.read(clipRepositoryProvider).prune(cutoff);
  }

  Future<void> _captureFromClipboard() async {
    final messenger = ScaffoldMessenger.of(context);
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Clipboard is empty')),
      );
      return;
    }
    await ref.read(clipRepositoryProvider).capture(
          CaptureEvent(content: text, source: CaptureSource.manual),
        );
    messenger.showSnackBar(const SnackBar(content: Text('Saved to history')));
  }

  Future<void> _copy(Clip clip) async {
    await ref.read(clipActionsProvider).copy(clip);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied'), duration: Duration(seconds: 1)),
    );
  }

  Future<void> _delete(Clip clip) async {
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
              onChanged: (v) => ref.read(searchQueryProvider.notifier).set(v),
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
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (items) => _list(items),
            ),
          ),
        ],
      ),
    );
  }

  Widget _list(List<Clip> items) {
    if (items.isEmpty) {
      final searching = ref.read(searchQueryProvider).trim().isNotEmpty;
      return Center(
        child: Text(searching ? 'No matches' : 'No clips yet'),
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
            onTogglePin: () => ref.read(clipActionsProvider).togglePin(clip),
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
