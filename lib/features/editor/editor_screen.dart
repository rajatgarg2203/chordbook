import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/songs_repository.dart';
import '../../domain/models/song.dart';
import '../library/library_view_model.dart';

final editingSongProvider =
    FutureProvider.autoDispose.family<SongModel?, String?>((ref, songId) async {
  if (songId == null) return null;
  final repository = ref.watch(songsRepositoryProvider);
  return repository.getSongById(songId);
});

class EditorScreen extends ConsumerStatefulWidget {
  final String? songId;

  const EditorScreen({super.key, this.songId});

  @override
  ConsumerState<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends ConsumerState<EditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _artistsController = TextEditingController();
  final _albumController = TextEditingController();
  final _yearController = TextEditingController();
  final _keyController = TextEditingController();
  final _capoController = TextEditingController();
  final _tempoController = TextEditingController();
  final _contentController = TextEditingController();

  bool _isLoading = false;
  bool _isInitialized = false;
  DateTime? _createdAt;
  int? _selectedCategory = 10; // Default to 10

  @override
  void dispose() {
    _titleController.dispose();
    _artistsController.dispose();
    _albumController.dispose();
    _yearController.dispose();
    _keyController.dispose();
    _capoController.dispose();
    _tempoController.dispose();
    _contentController.dispose();
    super.dispose();
  }


  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final repository = ref.read(songsRepositoryProvider);
      final artistNames = _artistsController.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      if (widget.songId != null) {
        await repository.updateSong(
          id: widget.songId!,
          title: _titleController.text.trim(),
          content: _contentController.text,
          album: _albumController.text.trim().isEmpty
              ? null
              : _albumController.text.trim(),
          year: int.tryParse(_yearController.text),
          key: _keyController.text.trim().isEmpty
              ? null
              : _keyController.text.trim(),
          capo: int.tryParse(_capoController.text),
          tempo: int.tryParse(_tempoController.text),
          category: _selectedCategory,
          artistNames: artistNames,
          createdAt: _createdAt,
        );
      } else {
        await repository.createSong(
          title: _titleController.text.trim(),
          content: _contentController.text,
          album: _albumController.text.trim().isEmpty
              ? null
              : _albumController.text.trim(),
          year: int.tryParse(_yearController.text),
          key: _keyController.text.trim().isEmpty
              ? null
              : _keyController.text.trim(),
          capo: int.tryParse(_capoController.text),
          tempo: int.tryParse(_tempoController.text),
          category: _selectedCategory,
          artistNames: artistNames,
        );
      }

      if (mounted) {
        // Refresh the library list
        ref.invalidate(filteredSongsProvider);
        Navigator.of(context).pop(true); // Return true to indicate changes were made
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving song: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.songId != null;
    final songAsync = ref.watch(editingSongProvider(widget.songId));

    // Show loading while fetching song data for editing
    if (isEditing && songAsync.isLoading && !_isInitialized) {
      return Scaffold(
        appBar: AppBar(title: const Text('Edit Song')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (isEditing) {
      songAsync.whenData((song) {
        if (song != null && !_isInitialized) {
          _isInitialized = true;
          // Use post-frame callback to avoid setState during build
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _titleController.text = song.title;
                _artistsController.text = song.artistNames.join(', ');
                _albumController.text = song.album ?? '';
                _yearController.text = song.year?.toString() ?? '';
                _keyController.text = song.key ?? '';
                _capoController.text = song.capo?.toString() ?? '';
                _tempoController.text = song.tempo?.toString() ?? '';
                _contentController.text = song.content;
                _createdAt = song.createdAt;
                _selectedCategory = song.category;
              });
            }
          });
        }
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Song' : 'New Song'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _save,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title *',
                hintText: 'Enter song title',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Title is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _artistsController,
              decoration: const InputDecoration(
                labelText: 'Artists',
                hintText: 'Artist 1, Artist 2, ...',
                helperText: 'Separate multiple artists with commas',
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _albumController,
                    decoration: const InputDecoration(
                      labelText: 'Album',
                      hintText: 'Album name',
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _yearController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Year',
                      hintText: 'e.g. 2024',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Created At'),
              subtitle: Text(
                _createdAt != null
                    ? '${_createdAt!.day}/${_createdAt!.month}/${_createdAt!.year} ${_createdAt!.hour}:${_createdAt!.minute.toString().padLeft(2, '0')}'
                    : 'Not set',
              ),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _createdAt ?? DateTime.now(),
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now(),
                );
                if (date != null) {
                  final time = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.fromDateTime(_createdAt ?? DateTime.now()),
                  );
                  if (time != null) {
                    setState(() {
                      _createdAt = DateTime(
                        date.year,
                        date.month,
                        date.day,
                        time.hour,
                        time.minute,
                      );
                    });
                  }
                }
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _keyController,
                    decoration: const InputDecoration(
                      labelText: 'Key',
                      hintText: 'e.g. C, Am',
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _capoController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Capo',
                      hintText: 'e.g. 2',
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _tempoController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Tempo',
                      hintText: 'BPM',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              initialValue: _selectedCategory?.toString() ?? '10',
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Number',
                hintText: 'Enter number (1-10)',
                helperText: 'Use for custom sorting and filtering',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) return null;
                final num = int.tryParse(value);
                if (num == null) return 'Please enter a valid number';
                if (num < 1 || num > 10) return 'Number must be between 1 and 10';
                return null;
              },
              onChanged: (value) {
                setState(() {
                  final num = int.tryParse(value);
                  if (num != null && num >= 1 && num <= 10) {
                    _selectedCategory = num;
                  }
                });
              },
            ),
            const SizedBox(height: 24),
            Text(
              'Lyrics & Chords',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _contentController,
              maxLines: 20,
              decoration: const InputDecoration(
                hintText: '''[Verse 1]
[C]Amazing [G]grace, how [Am]sweet the [F]sound
That [C]saved a [G]wretch like [C]me

[Chorus]
...''',
                alignLabelWithHint: true,
              ),
              style: const TextStyle(
                fontFamily: 'monospace',
                height: 1.5,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Content is required';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }
}
