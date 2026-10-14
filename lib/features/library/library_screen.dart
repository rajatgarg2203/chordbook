import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/routes.dart';
import '../../common/widgets/empty_state.dart';
import '../../common/widgets/confirm_dialog.dart';
import '../../data/repositories/songs_repository.dart';
import 'library_view_model.dart';
import 'widgets/song_list_item.dart';
import 'widgets/filters_sheet.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  final Set<String> _selectedSongIds = {};
  bool _selectionMode = false;

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _toggleSelectionMode() {
    setState(() {
      _selectionMode = !_selectionMode;
      if (!_selectionMode) {
        _selectedSongIds.clear();
      }
    });
  }

  void _toggleSongSelection(String songId) {
    setState(() {
      if (_selectedSongIds.contains(songId)) {
        _selectedSongIds.remove(songId);
      } else {
        _selectedSongIds.add(songId);
      }
      if (_selectedSongIds.isEmpty) {
        _selectionMode = false;
      }
    });
  }

  void _selectAll(List<dynamic> songs) {
    setState(() {
      _selectedSongIds.clear();
      for (final song in songs) {
        _selectedSongIds.add(song.id);
      }
    });
  }

  Future<void> _deleteSelected() async {
    if (_selectedSongIds.isEmpty) return;
    
    final confirmed = await ConfirmDialog.show(
      context: context,
      title: 'Delete ${_selectedSongIds.length} song(s)?',
      content: 'This action cannot be undone.',
      confirmText: 'Delete',
      isDestructive: true,
    );
    
    if (confirmed == true) {
      final count = _selectedSongIds.length;
      final repository = ref.read(songsRepositoryProvider);
      for (final id in _selectedSongIds) {
        await repository.deleteSong(id);
      }
      setState(() {
        _selectedSongIds.clear();
        _selectionMode = false;
      });
      ref.invalidate(filteredSongsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Deleted $count song(s)')),
        );
      }
    }
  }

  void _onSearchChanged(String value) {
    ref.read(libraryFiltersProvider.notifier).update(
          (state) => state.copyWith(searchText: value.isEmpty ? null : value),
        );
  }

  void _clearSearch() {
    _searchController.clear();
    _searchFocusNode.unfocus();
    ref.read(libraryFiltersProvider.notifier).update(
          (state) => state.copyWith(searchText: null),
        );
  }

  void _showFilters() {
    final filters = ref.read(libraryFiltersProvider);
    FiltersSheet.show(
      context: context,
      searchText: filters.searchText,
      yearFrom: filters.yearFrom,
      yearTo: filters.yearTo,
      capo: filters.capo,
      category: filters.category,
      sortBy: filters.sortBy,
      ascending: filters.ascending,
      onApply: (searchText, yearFrom, yearTo, capo, category, sortBy, ascending) {
        ref.read(libraryFiltersProvider.notifier).state = LibraryFilters(
          searchText: searchText,
          yearFrom: yearFrom,
          yearTo: yearTo,
          capo: capo,
          category: category,
          sortBy: sortBy,
          ascending: ascending,
        );
      },
    );
  }

  Future<void> _openRandomSong() async {
    final filteredSongs = ref.read(filteredSongsProvider).valueOrNull;
    
    if (filteredSongs == null || filteredSongs.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No songs available')),
        );
      }
      return;
    }
    
    final random = Random();
    final randomSong = filteredSongs[random.nextInt(filteredSongs.length)];
    
    if (mounted) {
      Navigator.pushNamed(
        context,
        AppRoutes.songDetail,
        arguments: randomSong.id,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final songsAsync = ref.watch(filteredSongsProvider);

    return Scaffold(
      appBar: AppBar(
        leading: _selectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: _toggleSelectionMode,
              )
            : null,
        title: _selectionMode
            ? Text('${_selectedSongIds.length} selected')
            : const Text('ChordBook'),
        actions: _selectionMode
            ? [
                IconButton(
                  icon: const Icon(Icons.select_all),
                  tooltip: 'Select All',
                  onPressed: () {
                    final songs = ref.read(filteredSongsProvider).valueOrNull;
                    if (songs != null) _selectAll(songs);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  tooltip: 'Delete Selected',
                  onPressed: _selectedSongIds.isNotEmpty ? _deleteSelected : null,
                ),
              ]
            : [
                IconButton(
                  icon: const Icon(Icons.shuffle),
                  tooltip: 'Random Song',
                  onPressed: _openRandomSong,
                ),
                IconButton(
                  icon: const Icon(Icons.filter_list),
                  onPressed: _showFilters,
                ),
                IconButton(
                  icon: const Icon(Icons.settings),
                  onPressed: () => Navigator.pushNamed(context, AppRoutes.settings),
                ),
              ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              decoration: InputDecoration(
                hintText: 'Search songs...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: _clearSearch,
                      )
                    : null,
              ),
              onChanged: _onSearchChanged,
            ),
          ),
          Expanded(
            child: songsAsync.when(
              data: (songs) {
                if (songs.isEmpty) {
                  return EmptyState(
                    icon: Icons.music_note,
                    title: 'No songs yet',
                    subtitle: 'Tap the + button to add your first song',
                    action: FilledButton.icon(
                      onPressed: () =>
                          Navigator.pushNamed(context, AppRoutes.editor),
                      icon: const Icon(Icons.add),
                      label: const Text('Add Song'),
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(filteredSongsProvider);
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 80),
                    itemCount: songs.length,
                    itemBuilder: (context, index) {
                      final song = songs[index];
                      return SongListItem(
                        song: song,
                        selectionMode: _selectionMode,
                        isSelected: _selectedSongIds.contains(song.id),
                        onSelectionChanged: (selected) {
                          _toggleSongSelection(song.id);
                        },
                        onTap: _selectionMode
                            ? () => _toggleSongSelection(song.id)
                            : () async {
                                _searchFocusNode.unfocus();
                                await Navigator.pushNamed(
                                  context,
                                  AppRoutes.songDetail,
                                  arguments: song.id,
                                );
                              },
                        onLongPress: !_selectionMode
                            ? () {
                                setState(() {
                                  _selectionMode = true;
                                  _selectedSongIds.add(song.id);
                                });
                              }
                            : null,
                      );
                    },
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => EmptyState(
                icon: Icons.error_outline,
                title: 'Error loading songs',
                subtitle: error.toString(),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.pushNamed(context, AppRoutes.editor);
          ref.invalidate(filteredSongsProvider);
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Song'),
      ),
    );
  }
}
