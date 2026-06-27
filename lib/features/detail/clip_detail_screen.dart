import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../data/db/database.dart';
import '../../data/providers.dart';
import '../../domain/models/clip_type.dart';

/// Full view of a single clip with its metadata and actions.
///
/// For text clips the primary action is "Copy" (re-copy to system clipboard).
/// For image clips the primary actions are "Copy image", "Save to gallery",
/// and "Share" — all routed through the native side because Flutter's
/// [Clipboard.setData] cannot carry images on Android.
class ClipDetailScreen extends ConsumerWidget {
  const ClipDetailScreen({super.key, required this.clip});

  final Clip clip;

  bool get _isImage => clip.type == ClipType.image && clip.mediaPath != null;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = ref.read(clipActionsProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Clip'),
        actions: [
          IconButton(
            tooltip: clip.isPinned ? 'Unpin' : 'Pin',
            icon:
                Icon(clip.isPinned ? Icons.push_pin : Icons.push_pin_outlined),
            onPressed: () async {
              await actions.togglePin(clip);
              if (context.mounted) context.pop();
            },
          ),
          IconButton(
            tooltip: 'Delete',
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              await actions.delete(clip.id);
              if (context.mounted) context.pop();
            },
          ),
        ],
      ),
      floatingActionButton: _isImage
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton.extended(
                  heroTag: 'copyImg',
                  onPressed: () => _copyImage(context, actions),
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy'),
                ),
                const SizedBox(width: 12),
                FloatingActionButton.extended(
                  heroTag: 'saveImg',
                  onPressed: () => _saveImage(context, actions),
                  icon: const Icon(Icons.save_alt),
                  label: const Text('Save'),
                ),
              ],
            )
          : FloatingActionButton.extended(
              onPressed: () async {
                await actions.copy(clip);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Copied')),
                  );
                }
              },
              icon: const Icon(Icons.copy),
              label: const Text('Copy'),
            ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          if (_isImage) ...[
            _FullImagePreview(path: clip.mediaPath!),
            const SizedBox(height: 16),
          ] else
            SelectableText(
              clip.content,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          const SizedBox(height: 24),
          Divider(color: scheme.outlineVariant),
          _meta(context, 'Type', clip.type.name),
          _meta(context, 'Saved', timeAgo(clip.createdAt)),
          _meta(context, 'Used', '${clip.usageCount}\u00d7'),
          _meta(context, 'Size', formatBytes(clip.byteSize)),
          if (clip.sourceApp != null) _meta(context, 'Source', clip.sourceApp!),
          if (_isImage && clip.mimeType != null)
            _meta(context, 'Format', clip.mimeType!),
        ],
      ),
    );
  }

  Future<void> _copyImage(
      BuildContext context, ClipActions actions) async {
    final ok = await actions.copyImage(clip);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ok ? 'Image copied' : 'Copy failed')),
      );
    }
  }

  Future<void> _saveImage(
      BuildContext context, ClipActions actions) async {
    final uri = await actions.saveImageToGallery(clip);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(uri != null ? 'Saved to gallery' : 'Save failed'),
        ),
      );
    }
  }

  Widget _meta(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 88,
            child: Text(label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    )),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

/// Full-resolution image preview for the detail screen, with tap-to-share.
class _FullImagePreview extends StatelessWidget {
  const _FullImagePreview({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: () {
        final container = ProviderScope.containerOf(context);
        container.read(clipActionsProvider).shareImage(
              context.findAncestorWidgetOfExactType<ClipDetailScreen>()!.clip,
            );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.file(
          File(path),
          fit: BoxFit.contain,
          errorBuilder: (context, error, stack) => Container(
            height: 200,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: const Center(child: Icon(Icons.broken_image_outlined, size: 48)),
          ),
        ),
      ),
    );
  }
}
