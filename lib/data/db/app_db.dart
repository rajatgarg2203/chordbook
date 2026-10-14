import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'tables.dart';

part 'app_db.g.dart';

@DriftDatabase(tables: [Songs, Artists, SongArtists, Tags, SongTags])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 4;

  static QueryExecutor _openConnection() {
    return driftDatabase(
      name: 'chordbook',
      web: DriftWebOptions(
        sqlite3Wasm: Uri.parse('sqlite3.wasm'),
        driftWorker: Uri.parse('drift_worker.js'),
      ),
    );
  }

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from == 1) {
          // Add category column to songs table
          await m.addColumn(songs, songs.category);
        }
        if (from <= 2) {
          // Add lastOpenedAt column to songs table
          await m.addColumn(songs, songs.lastOpenedAt);
        }
        if (from <= 3) {
          // Set all existing songs with null category to 10
          await customStatement(
            'UPDATE songs SET category = 10 WHERE category IS NULL',
          );
        }
      },
    );
  }

  // Song CRUD operations
  Future<List<Song>> getAllSongs() => select(songs).get();

  Stream<List<Song>> watchAllSongs() => select(songs).watch();

  Future<Song?> getSongById(String id) =>
      (select(songs)..where((s) => s.id.equals(id))).getSingleOrNull();

  Future<int> insertSong(SongsCompanion song) => into(songs).insert(song);

  Future<bool> updateSong(SongsCompanion song) => update(songs).replace(song);

  Future<int> deleteSong(String id) =>
      (delete(songs)..where((s) => s.id.equals(id))).go();

  Future<void> updateLastOpenedAt(String id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (update(songs)..where((s) => s.id.equals(id)))
        .write(SongsCompanion(lastOpenedAt: Value(now)));
  }

  // Artist operations
  Future<List<Artist>> getAllArtists() => select(artists).get();

  Future<Artist?> getArtistByName(String name) =>
      (select(artists)..where((a) => a.name.equals(name))).getSingleOrNull();

  Future<int> insertArtist(ArtistsCompanion artist) =>
      into(artists).insert(artist);

  Future<Artist> getOrCreateArtist(String id, String name) async {
    final existing = await getArtistByName(name);
    if (existing != null) return existing;

    await insertArtist(ArtistsCompanion.insert(id: id, name: name));
    return (await getArtistByName(name))!;
  }

  // Song-Artist relationship
  Future<List<Artist>> getArtistsForSong(String songId) async {
    final query = select(songArtists).join([
      innerJoin(artists, artists.id.equalsExp(songArtists.artistId)),
    ])
      ..where(songArtists.songId.equals(songId))
      ..orderBy([OrderingTerm.asc(songArtists.position)]);

    final results = await query.get();
    return results.map((row) => row.readTable(artists)).toList();
  }

  Future<void> setSongArtists(String songId, List<String> artistIds) async {
    await (delete(songArtists)..where((sa) => sa.songId.equals(songId))).go();

    for (var i = 0; i < artistIds.length; i++) {
      await into(songArtists).insert(SongArtistsCompanion.insert(
        songId: songId,
        artistId: artistIds[i],
        position: Value(i),
      ));
    }
  }

  // Search songs with filters
  Future<List<Song>> searchSongs({
    String? searchText,
    int? yearFrom,
    int? yearTo,
    int? capo,
    int? category,
    String? orderBy,
    bool ascending = true,
  }) async {
    // If searching by text, need to join with artists table
    if (searchText != null && searchText.isNotEmpty) {
      final pattern = '%$searchText%';

      // Query with join to search artist names
      final joinQuery = select(songs).join([
        leftOuterJoin(songArtists, songArtists.songId.equalsExp(songs.id)),
        leftOuterJoin(artists, artists.id.equalsExp(songArtists.artistId)),
      ]);

      // Build where clause for text search (title, album, content, artist name)
      Expression<bool> textSearch = songs.title.like(pattern) |
          songs.album.like(pattern) |
          songs.content.like(pattern) |
          artists.name.like(pattern);

      // Add other filters
      if (yearFrom != null) {
        textSearch = textSearch & songs.year.isBiggerOrEqualValue(yearFrom);
      }
      if (yearTo != null) {
        textSearch = textSearch & songs.year.isSmallerOrEqualValue(yearTo);
      }
      if (capo != null) {
        textSearch = textSearch & songs.capo.equals(capo);
      }
      if (category != null) {
        textSearch = textSearch & songs.category.equals(category);
      }

      joinQuery.where(textSearch);

      // Build order by for join query
      switch (orderBy) {
        case 'title':
          joinQuery.orderBy([
            ascending
                ? OrderingTerm.asc(songs.title)
                : OrderingTerm.desc(songs.title)
          ]);
          break;
        case 'year':
          joinQuery.orderBy([
            ascending
                ? OrderingTerm.asc(songs.year)
                : OrderingTerm.desc(songs.year)
          ]);
          break;
        case 'createdAt':
          joinQuery.orderBy([
            ascending
                ? OrderingTerm.asc(songs.createdAt)
                : OrderingTerm.desc(songs.createdAt)
          ]);
          break;
        case 'category':
          joinQuery.orderBy([
            ascending
                ? OrderingTerm.asc(songs.category)
                : OrderingTerm.desc(songs.category)
          ]);
          break;
        case 'lastOpenedAt':
          joinQuery.orderBy([
            ascending
                ? OrderingTerm.asc(songs.lastOpenedAt)
                : OrderingTerm.desc(songs.lastOpenedAt)
          ]);
          break;
        case 'updatedAt':
        default:
          joinQuery.orderBy([
            ascending
                ? OrderingTerm.asc(songs.updatedAt)
                : OrderingTerm.desc(songs.updatedAt)
          ]);
          break;
      }

      // Get results and extract unique songs (since join may return duplicates)
      final results = await joinQuery.get();
      final uniqueSongs = <String, Song>{};
      for (final row in results) {
        final song = row.readTable(songs);
        uniqueSongs[song.id] = song;
      }
      return uniqueSongs.values.toList();
    } else {
      // No text search, use simple query
      final query = select(songs);
      Expression<bool>? whereClause;

      if (yearFrom != null) {
        final yearCondition = songs.year.isBiggerOrEqualValue(yearFrom);
        whereClause =
            whereClause == null ? yearCondition : whereClause & yearCondition;
      }

      if (yearTo != null) {
        final yearCondition = songs.year.isSmallerOrEqualValue(yearTo);
        whereClause =
            whereClause == null ? yearCondition : whereClause & yearCondition;
      }

      if (capo != null) {
        final capoCondition = songs.capo.equals(capo);
        whereClause =
            whereClause == null ? capoCondition : whereClause & capoCondition;
      }

      if (category != null) {
        final categoryCondition = songs.category.equals(category);
        whereClause = whereClause == null
            ? categoryCondition
            : whereClause & categoryCondition;
      }

      if (whereClause != null) {
        query.where((s) => whereClause!);
      }

      // Build order by
      OrderingTerm Function(Songs) orderingTerm;
      switch (orderBy) {
        case 'title':
          orderingTerm = (s) => ascending
              ? OrderingTerm.asc(s.title)
              : OrderingTerm.desc(s.title);
          break;
        case 'year':
          orderingTerm = (s) =>
              ascending ? OrderingTerm.asc(s.year) : OrderingTerm.desc(s.year);
          break;
        case 'createdAt':
          orderingTerm = (s) => ascending
              ? OrderingTerm.asc(s.createdAt)
              : OrderingTerm.desc(s.createdAt);
          break;
        case 'category':
          orderingTerm = (s) => ascending
              ? OrderingTerm.asc(s.category)
              : OrderingTerm.desc(s.category);
          break;
        case 'lastOpenedAt':
          orderingTerm = (s) => ascending
              ? OrderingTerm.asc(s.lastOpenedAt)
              : OrderingTerm.desc(s.lastOpenedAt);
          break;
        case 'updatedAt':
        default:
          orderingTerm = (s) => ascending
              ? OrderingTerm.asc(s.updatedAt)
              : OrderingTerm.desc(s.updatedAt);
          break;
      }

      query.orderBy([orderingTerm]);

      return query.get();
    }
  }

  // Tag operations
  Future<List<Tag>> getAllTags() => select(tags).get();

  Future<int> insertTag(TagsCompanion tag) => into(tags).insert(tag);

  Future<List<Tag>> getTagsForSong(String songId) async {
    final query = select(songTags).join([
      innerJoin(tags, tags.id.equalsExp(songTags.tagId)),
    ])
      ..where(songTags.songId.equals(songId));

    final results = await query.get();
    return results.map((row) => row.readTable(tags)).toList();
  }

  Future<void> setSongTags(String songId, List<String> tagIds) async {
    await (delete(songTags)..where((st) => st.songId.equals(songId))).go();

    for (final tagId in tagIds) {
      await into(songTags).insert(SongTagsCompanion.insert(
        songId: songId,
        tagId: tagId,
      ));
    }
  }
}
