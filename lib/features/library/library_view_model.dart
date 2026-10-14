import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/songs_repository.dart';
import '../../domain/models/song.dart';

class LibraryFilters {
  final String? searchText;
  final int? yearFrom;
  final int? yearTo;
  final int? capo;
  final int? category;
  final String sortBy;
  final bool ascending;

  const LibraryFilters({
    this.searchText,
    this.yearFrom,
    this.yearTo,
    this.capo,
    this.category,
    this.sortBy = 'lastOpenedAt',
    this.ascending = false,
  });

  LibraryFilters copyWith({
    String? searchText,
    int? yearFrom,
    int? yearTo,
    int? capo,
    bool clearCapo = false,
    int? category,
    bool clearCategory = false,
    String? sortBy,
    bool? ascending,
  }) {
    return LibraryFilters(
      searchText: searchText ?? this.searchText,
      yearFrom: yearFrom ?? this.yearFrom,
      yearTo: yearTo ?? this.yearTo,
      capo: clearCapo ? null : (capo ?? this.capo),
      category: clearCategory ? null : (category ?? this.category),
      sortBy: sortBy ?? this.sortBy,
      ascending: ascending ?? this.ascending,
    );
  }
}

final libraryFiltersProvider =
    StateProvider<LibraryFilters>((ref) => const LibraryFilters());

final filteredSongsProvider = FutureProvider<List<SongModel>>((ref) async {
  final filters = ref.watch(libraryFiltersProvider);
  final repository = ref.watch(songsRepositoryProvider);

  return repository.searchSongs(
    searchText: filters.searchText,
    yearFrom: filters.yearFrom,
    yearTo: filters.yearTo,
    capo: filters.capo,
    category: filters.category,
    orderBy: filters.sortBy,
    ascending: filters.ascending,
  );
});
