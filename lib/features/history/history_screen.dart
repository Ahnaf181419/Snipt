import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../core/haptics.dart';
import '../../data/db/database.dart';
import '../../data/providers.dart';
import '../../data/settings.dart';
import '../../domain/models/capture_event.dart';
import '../../domain/models/clip_type.dart';
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
    _searchController =
        TextEditingController(text: ref.read(searchQueryProvider));
    _runRetention();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _runRetention() async {
    final settings = await ref.read(settingsControllerProvider.future);
    if (!mounted) return;
    if (settings.retentionDays <= 0) return;
    final cutoff =
        DateTime.now().subtract(Duration(days: settings.retentionDays));
    if (!mounted) return;
    await ref.read(clipRepositoryProvider).prune(cutoff);
  }

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

  Future<void> _pickImage() async {
    final messenger = ScaffoldMessenger.of(context);
    await Haptics.light();
    final picker = ImagePicker();
    final xFile = await picker.pickImage(source: ImageSource.gallery);
    if (xFile == null) return;

    final bridge = ref.read(captureBridgeProvider);
    final mimeType = xFile.mimeType ?? 'image/jpeg';
    final importedPath =
        await bridge.host.importImageFromPath(xFile.path, mimeType);
    if (importedPath == null) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not import image')),
      );
      return;
    }
    await ref.read(clipRepositoryProvider).captureImage(
          mediaPath: importedPath,
          mimeType: mimeType,
        );
    if (!mounted) return;
    messenger.showSnackBar(
      const SnackBar(content: Text('Image saved')),
    );
  }

  void _showCaptureSheet() {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(LucideIcons.clipboard),
              title: const Text('Capture clipboard text'),
              onTap: () {
                Navigator.pop(context);
                _captureFromClipboard();
              },
            ),
            ListTile(
              leading: const Icon(LucideIcons.image),
              title: const Text('Pick image from gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _copy(Clip clip) async {
    await Haptics.light();
    final actions = ref.read(clipActionsProvider);
    if (clip.type == ClipType.image && clip.mediaPath != null) {
      final ok = await actions.copyImage(clip);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? 'Image copied' : 'Copy failed'),
          duration: const Duration(seconds: 1),
        ),
      );
    } else {
      await actions.copy(clip);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Copied'), duration: Duration(seconds: 1)),
      );
    }
  }

  Future<void> _delete(Clip clip) async {
    await Haptics.medium();
    await ref.read(clipActionsProvider).delete(clip.id);
    if (!mounted) return;
    final isImage = clip.type == ClipType.image;
    final messenger = ScaffoldMessenger.of(context);
    if (isImage) {
      messenger.showSnackBar(const SnackBar(content: Text('Deleted')));
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Deleted'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => ref.read(clipRepositoryProvider).capture(
                  CaptureEvent(
                      content: clip.content, sourceApp: clip.sourceApp),
                ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final clips = ref.watch(clipListProvider);
    final query = ref.watch(searchQueryProvider);
    final settings = ref.watch(settingsControllerProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('snipt'),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.settings),
            onPressed: () => context.push('/settings'),
            tooltip: 'Settings',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCaptureSheet,
        icon: const Icon(LucideIcons.plus),
        label: const Text('Capture'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: ShadInput(
              controller: _searchController,
              placeholder: const Text('Search clips'),
              leading: Icon(LucideIcons.search, size: 18,
                  color: theme.colorScheme.mutedForeground),
              onChanged: (v) {
                ref.read(searchQueryProvider.notifier).set(v);
                setState(() {});
              },
              trailing: _searchController.text.isEmpty
                  ? null
                  : ShadIconButton.ghost(
                      icon: Icon(LucideIcons.x, size: 16,
                          color: theme.colorScheme.mutedForeground),
                      onPressed: () {
                        _searchController.clear();
                        ref.read(searchQueryProvider.notifier).clear();
                        setState(() {});
                      },
                    ),
            ),
          ),
          if (settings != null && !settings.captureServiceEnabled)
            _SetupBanner(onTap: () => context.push('/onboarding')),
          Expanded(
            child: clips.when(
              loading: () => const SkeletonClipList(),
              error: (e, _) => EmptyState(
                icon: LucideIcons.circleAlert,
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
              icon: LucideIcons.searchX,
              title: 'No matches found',
              subtitle: 'Try a different search term',
            )
          : const EmptyState(
              icon: LucideIcons.clipboardList,
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
            child: const Icon(LucideIcons.trash2),
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
    final theme = ShadTheme.of(context);
    return Material(
      color: theme.colorScheme.accent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(LucideIcons.zap, color: theme.colorScheme.accentForeground),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Finish capture setup to save clips faster',
                  style: TextStyle(color: theme.colorScheme.accentForeground),
                ),
              ),
              Icon(LucideIcons.chevronRight,
                  color: theme.colorScheme.accentForeground),
            ],
          ),
        ),
      ),
    );
  }
}
