import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/routes.dart';
import '../../common/widgets/confirm_dialog.dart';
import '../../data/repositories/songs_repository.dart';
import '../../data/repositories/songs_repository.dart' as repo;
import '../../domain/models/song.dart';

final songDetailProvider =
    FutureProvider.family<SongModel?, String>((ref, songId) async {
  final repository = ref.watch(songsRepositoryProvider);
  return repository.getSongById(songId);
});

class SongDetailScreen extends ConsumerStatefulWidget {
  final String? songId;

  const SongDetailScreen({super.key, this.songId});

  @override
  ConsumerState<SongDetailScreen> createState() => _SongDetailScreenState();
}

class _SongDetailScreenState extends ConsumerState<SongDetailScreen> {
  @override
  void initState() {
    super.initState();
    // Update lastOpenedAt when song is opened
    if (widget.songId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final db = ref.read(repo.databaseProvider);
        db.updateLastOpenedAt(widget.songId!);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.songId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Song')),
        body: const Center(child: Text('Song not found')),
      );
    }

    final songAsync = ref.watch(songDetailProvider(widget.songId!));

    return songAsync.when(
      data: (song) {
        if (song == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Song')),
            body: const Center(child: Text('Song not found')),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(song.title),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () async {
                  await Navigator.pushNamed(
                    context,
                    AppRoutes.editor,
                    arguments: song.id,
                  );
                  ref.invalidate(songDetailProvider(widget.songId!));
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () async {
                  final confirmed = await ConfirmDialog.show(
                    context: context,
                    title: 'Delete Song',
                    content:
                        'Are you sure you want to delete "${song.title}"? This action cannot be undone.',
                    confirmText: 'Delete',
                    isDestructive: true,
                  );

                  if (confirmed && context.mounted) {
                    final repository = ref.read(songsRepositoryProvider);
                    await repository.deleteSong(song.id);
                    if (context.mounted) {
                      Navigator.of(context).pop();
                    }
                  }
                },
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Song metadata
                if (song.artistNames.isNotEmpty) ...[
                  Text(
                    song.artistNames.join(', '),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                ],
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (song.album != null)
                      _MetadataChip(
                        icon: Icons.album,
                        label: song.album!,
                      ),
                    if (song.year != null)
                      _MetadataChip(
                        icon: Icons.calendar_today,
                        label: song.year.toString(),
                      ),
                    if (song.key != null)
                      _MetadataChip(
                        icon: Icons.music_note,
                        label: 'Key: ${song.key}',
                      ),
                    if (song.capo != null)
                      _MetadataChip(
                        icon: Icons.straighten,
                        label: 'Capo: ${song.capo}',
                      ),
                    if (song.tempo != null)
                      _MetadataChip(
                        icon: Icons.speed,
                        label: '${song.tempo} BPM',
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),
                // Song content (ChordPro format)
                SelectableText(
                  song.content,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontFamily: 'monospace',
                        height: 1.8,
                      ),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Loading...')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(child: Text('Error: $error')),
      ),
    );
  }
}

class _MetadataChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetadataChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 6),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
