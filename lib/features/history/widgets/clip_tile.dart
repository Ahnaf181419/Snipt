import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/format.dart';
import '../../../data/db/database.dart';
import '../../../domain/models/clip_type.dart';

/// A single clipboard entry in the history list. Tap to copy, use the trailing
/// menu for pin/delete/open.
class ClipTile extends StatelessWidget {
  const ClipTile({
    super.key,
    required this.clip,
    required this.onCopy,
    required this.onTogglePin,
    required this.onDelete,
    required this.onOpen,
  });

  final Clip clip;
  final VoidCallback onCopy;
  final VoidCallback onTogglePin;
  final VoidCallback onDelete;
  final VoidCallback onOpen;

  IconData get _typeIcon => switch (clip.type) {
        ClipType.url => Icons.link,
        ClipType.richText => Icons.article_outlined,
        ClipType.text => Icons.notes,
        ClipType.image => Icons.image_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: InkWell(
        onTap: onCopy,
        onLongPress: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2, right: 10),
                child: Icon(_typeIcon, size: 20, color: scheme.primary),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (clip.type == ClipType.image && clip.mediaPath != null)
                      _ImageThumb(path: clip.mediaPath!)
                    else
                      Text(
                        clip.content,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (clip.isPinned) ...[
                          Icon(Icons.push_pin,
                              size: 13, color: scheme.secondary),
                          const SizedBox(width: 4),
                        ],
                        Text(
                          timeAgo(clip.createdAt),
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(color: scheme.outline),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (value) => switch (value) {
                  'copy' => onCopy(),
                  'pin' => onTogglePin(),
                  'open' => onOpen(),
                  'delete' => onDelete(),
                  _ => null,
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'copy', child: Text('Copy')),
                  PopupMenuItem(
                    value: 'pin',
                    child: Text(clip.isPinned ? 'Unpin' : 'Pin'),
                  ),
                  const PopupMenuItem(value: 'open', child: Text('Open')),
                  const PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A compact thumbnail for image clips in the history list. Uses
/// [Image.file] with a small cache width to keep memory low — the full-
/// resolution decode would OOM the list on large camera-roll photos.
class _ImageThumb extends StatelessWidget {
  const _ImageThumb({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.file(
        File(path),
        width: double.infinity,
        height: 120,
        fit: BoxFit.cover,
        cacheWidth: 300, // decode at ~300px wide to save memory
        errorBuilder: (context, error, stack) => Container(
          width: double.infinity,
          height: 120,
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: const Center(child: Icon(Icons.broken_image_outlined)),
        ),
      ),
    );
  }
}
