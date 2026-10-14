import 'package:flutter/material.dart';
import '../../../domain/models/song.dart';

class SongListItem extends StatelessWidget {
  final SongModel song;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool isSelected;
  final bool selectionMode;
  final ValueChanged<bool?>? onSelectionChanged;

  const SongListItem({
    super.key,
    required this.song,
    required this.onTap,
    this.onLongPress,
    this.isSelected = false,
    this.selectionMode = false,
    this.onSelectionChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        onTap: onTap,
        onLongPress: onLongPress,
        title: Text(
          song.title,
          style: Theme.of(context).textTheme.titleMedium,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (song.artistNames.isNotEmpty)
              Text(
                song.artistNames.join(', '),
                style: Theme.of(context).textTheme.bodyMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            if (song.album != null || song.year != null)
              Text(
                [
                  if (song.album != null) song.album,
                  if (song.year != null) song.year.toString(),
                ].join(' • '),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        leading: selectionMode
            ? Checkbox(
                value: isSelected,
                onChanged: onSelectionChanged,
              )
            : null,
        trailing: _buildTrailing(context),
      ),
    );
  }

  Widget? _buildTrailing(BuildContext context) {
    final hasKey = song.key != null;
    final hasCapo = song.capo != null;
    
    if (!hasKey && !hasCapo) return null;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        [
          if (hasKey) song.key!,
          if (hasCapo) 'Capo ${song.capo}',
        ].join(' • '),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
      ),
    );
  }
}
