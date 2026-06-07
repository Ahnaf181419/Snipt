import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../data/db/database.dart';
import '../../data/providers.dart';

/// Full view of a single clip with its metadata and actions.
class ClipDetailScreen extends ConsumerWidget {
  const ClipDetailScreen({super.key, required this.clip});

  final Clip clip;

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
            icon: Icon(clip.isPinned ? Icons.push_pin : Icons.push_pin_outlined),
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
      floatingActionButton: FloatingActionButton.extended(
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
          SelectableText(
            clip.content,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 24),
          Divider(color: scheme.outlineVariant),
          _meta(context, 'Type', clip.type.name),
          _meta(context, 'Saved', timeAgo(clip.createdAt)),
          _meta(context, 'Used', '${clip.usageCount}×'),
          _meta(context, 'Size', formatBytes(clip.byteSize)),
          if (clip.sourceApp != null) _meta(context, 'Source', clip.sourceApp!),
        ],
      ),
    );
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
