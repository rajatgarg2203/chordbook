import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../domain/models/song.dart';
import '../db/app_db.dart' as db;

final databaseProvider = Provider<db.AppDatabase>((ref) {
  final database = db.AppDatabase();
  ref.onDispose(() => database.close());
  return database;
});

final songsRepositoryProvider = Provider<SongsRepository>((ref) {
  return SongsRepository(ref.watch(databaseProvider));
});

class SongsRepository {
  final db.AppDatabase _db;
  final _uuid = const Uuid();

  SongsRepository(this._db);

  Future<List<SongModel>> getAllSongs() async {
    final dbSongs = await _db.getAllSongs();
    return Future.wait(dbSongs.map(_mapToSongModel));
  }

  Stream<List<SongModel>> watchAllSongs() {
    return _db.watchAllSongs().asyncMap((dbSongs) async {
      return Future.wait(dbSongs.map(_mapToSongModel));
    });
  }

  Future<SongModel?> getSongById(String id) async {
    final dbSong = await _db.getSongById(id);
    if (dbSong == null) return null;
    return _mapToSongModel(dbSong);
  }

  Future<List<SongModel>> searchSongs({
    String? searchText,
    int? yearFrom,
    int? yearTo,
    int? capo,
    int? category,
    String? orderBy,
    bool ascending = true,
  }) async {
    final dbSongs = await _db.searchSongs(
      searchText: searchText,
      yearFrom: yearFrom,
      yearTo: yearTo,
      capo: capo,
      category: category,
      orderBy: orderBy,
      ascending: ascending,
    );
    return Future.wait(dbSongs.map(_mapToSongModel));
  }

  Future<String> createSong({
    required String title,
    required String content,
    String? album,
    int? year,
    String? key,
    int? capo,
    int? tempo,
    int? category,
    List<String> artistNames = const [],
  }) async {
    return createSongWithId(
      id: _uuid.v4(),
      title: title,
      content: content,
      album: album,
      year: year,
      key: key,
      capo: capo,
      tempo: tempo,
      category: category,
      artistNames: artistNames,
    );
  }

  Future<String> createSongWithId({
    required String id,
    required String title,
    required String content,
    String? album,
    int? year,
    String? key,
    int? capo,
    int? tempo,
    int? category,
    List<String> artistNames = const [],
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    await _db.insertSong(db.SongsCompanion.insert(
      id: id,
      title: title,
      content: content,
      album: Value(album),
      year: Value(year),
      songKey: Value(key),
      capo: Value(capo),
      tempo: Value(tempo),
      category: Value(category ?? 10),
      createdAt: now,
      updatedAt: now,
    ));

    // Handle artists
    final artistIds = <String>[];
    for (final name in artistNames) {
      if (name.trim().isEmpty) continue;
      final artist = await _db.getOrCreateArtist(_uuid.v4(), name.trim());
      artistIds.add(artist.id);
    }
    await _db.setSongArtists(id, artistIds);

    return id;
  }

  Future<void> updateSong({
    required String id,
    required String title,
    required String content,
    String? album,
    int? year,
    String? key,
    int? capo,
    int? tempo,
    int? category,
    List<String> artistNames = const [],
    DateTime? createdAt,
  }) async {
    final existing = await _db.getSongById(id);
    if (existing == null) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    final createdAtMs = createdAt?.millisecondsSinceEpoch ?? existing.createdAt;

    await _db.updateSong(db.SongsCompanion(
      id: Value(id),
      title: Value(title),
      content: Value(content),
      album: Value(album),
      year: Value(year),
      songKey: Value(key),
      capo: Value(capo),
      tempo: Value(tempo),
      category: Value(category ?? existing.category),
      createdAt: Value(createdAtMs),
      updatedAt: Value(now),
    ));

    // Handle artists
    final artistIds = <String>[];
    for (final name in artistNames) {
      if (name.trim().isEmpty) continue;
      final artist = await _db.getOrCreateArtist(_uuid.v4(), name.trim());
      artistIds.add(artist.id);
    }
    await _db.setSongArtists(id, artistIds);
  }

  Future<void> deleteSong(String id) async {
    await _db.setSongArtists(id, []);
    await _db.setSongTags(id, []);
    await _db.deleteSong(id);
  }

  Future<SongModel> _mapToSongModel(db.Song dbSong) async {
    final artists = await _db.getArtistsForSong(dbSong.id);
    return SongModel(
      id: dbSong.id,
      title: dbSong.title,
      album: dbSong.album,
      year: dbSong.year,
      content: dbSong.content,
      key: dbSong.songKey,
      capo: dbSong.capo,
      tempo: dbSong.tempo,
      category: dbSong.category,
      createdAt: DateTime.fromMillisecondsSinceEpoch(dbSong.createdAt),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(dbSong.updatedAt),
      artistNames: artists.map((a) => a.name).toList(),
    );
  }
}
