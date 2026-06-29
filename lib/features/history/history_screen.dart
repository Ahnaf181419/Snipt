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
import '../tutorial/tutorial_overlay.dart';
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

  final _searchKey = GlobalKey();
  final _settingsKey = GlobalKey();
  final _bannerKey = GlobalKey();
  final _fabKey = GlobalKey();
  final _firstTileKey = GlobalKey();
  bool _tutorialActive = false;
  bool _tutorialChecked = false;

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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _maybeStartTutorial();
  }

  void _maybeStartTutorial() {
    if (_tutorialChecked) return;
    _tutorialChecked = true;
    final settings = ref.read(settingsControllerProvider).value;
    if (settings == null || !settings.onboarded || settings.tutorialShown) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _tutorialActive = true);
    });
  }

  void _dismissTutorial() {
    setState(() => _tutorialActive = false);
    ref.read(settingsControllerProvider.notifier).markTutorialShown();
  }

  List<TutorialStep> _buildSteps(bool showBannerStep) {
    return [
      TutorialStep(
        targetKey: _searchKey,
        title: 'Search your clips',
        body: "Find any text you've copied by typing here.",
      ),
      TutorialStep(
        targetKey: _settingsKey,
        title: 'Settings',
        body: 'Adjust retention, enable Pro features, and manage capture.',
      ),
      if (showBannerStep)
        TutorialStep(
          targetKey: _bannerKey,
          title: 'Enable capture service',
          body: 'Turn on the foreground service to capture clips from the '
              'notification or Quick-Settings tile.',
        ),
      TutorialStep(
        targetKey: _fabKey,
        title: 'Capture',
        body: 'Tap to save text from your clipboard or pick an image.',
        placement: TooltipPlacement.above,
      ),
      TutorialStep(
        targetKey: _firstTileKey,
        title: 'Manage clips',
        body: 'Tap to copy \u00b7 long-press to open \u00b7 swipe left to '
            'delete \u00b7 use the menu to pin.',
        placement: TooltipPlacement.above,
      ),
    ];
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

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: const Text('snipt'),
            actions: [
              IconButton(
                key: _settingsKey,
                icon: const Icon(LucideIcons.settings),
                onPressed: () => context.push('/settings'),
                tooltip: 'Settings',
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            key: _fabKey,
            onPressed: _showCaptureSheet,
            icon: const Icon(LucideIcons.plus),
            label: const Text('Capture'),
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                child: ShadInput(
                  key: _searchKey,
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
                _SetupBanner(
                  key: _bannerKey,
                  onTap: () => context.push('/onboarding'),
                ),
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
        ),
        if (_tutorialActive)
          Positioned.fill(
            child: TutorialOverlay(
              steps: _buildSteps(
                settings != null && !settings.captureServiceEnabled,
              ),
              onComplete: _dismissTutorial,
              onSkip: _dismissTutorial,
            ),
          ),
      ],
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
            key: i == 0 ? _firstTileKey : null,
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
  const _SetupBanner({super.key, required this.onTap});

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
