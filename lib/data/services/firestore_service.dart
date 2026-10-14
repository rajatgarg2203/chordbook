import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/songs_repository.dart';
import '../../domain/models/song.dart';

final firestoreServiceProvider = Provider<FirestoreService>((ref) {
  return FirestoreService(ref.watch(songsRepositoryProvider));
});

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final SongsRepository _localRepository;

  FirestoreService(this._localRepository);

  CollectionReference<Map<String, dynamic>> get _songsCollection =>
      _firestore.collection('songs');

  /// Sync songs from Firestore to local database
  /// Returns a map with counts: {added: X, updated: Y}
  Future<Map<String, int>> syncFromCloud() async {
    final snapshot = await _songsCollection.get();
    int addedCount = 0;
    int updatedCount = 0;

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final cloudSongId = doc.id;

      // Parse cloud data
      final artistNames = (data['artistNames'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [];

      // Get cloud timestamps
      final cloudUpdatedAt = (data['updatedAt'] as Timestamp?)?.toDate();
      final cloudCreatedAt = (data['createdAt'] as Timestamp?)?.toDate();

      // Check if song already exists locally
      final existingSong = await _localRepository.getSongById(cloudSongId);
      
      if (existingSong == null) {
        // Add new song from cloud
        await _localRepository.createSongWithId(
          id: cloudSongId,
          title: data['title'] ?? 'Untitled',
          content: data['content'] ?? '',
          album: data['album'],
          year: data['year'],
          key: data['key'],
          capo: data['capo'],
          tempo: data['tempo'],
          category: data['category'],
          artistNames: artistNames,
        );
        addedCount++;
      } else {
        // Check if cloud version is newer OR if createdAt differs
        final shouldUpdate = (cloudUpdatedAt != null && 
                              cloudUpdatedAt.isAfter(existingSong.updatedAt)) ||
                             (cloudCreatedAt != null && 
                              cloudCreatedAt.millisecondsSinceEpoch != existingSong.createdAt);
        
        if (shouldUpdate) {
          // Update existing song if cloud version is newer or createdAt changed
          await _localRepository.updateSong(
            id: cloudSongId,
            title: data['title'] ?? existingSong.title,
            content: data['content'] ?? existingSong.content,
            album: data['album'],
            year: data['year'],
            key: data['key'],
            capo: data['capo'],
            tempo: data['tempo'],
            category: data['category'],
            artistNames: artistNames,
            createdAt: cloudCreatedAt,
          );
          updatedCount++;
        }
      }
    }

    return {'added': addedCount, 'updated': updatedCount};
  }

  /// Upload a song to Firestore (for admin use)
  Future<void> uploadSong(SongModel song) async {
    // Check if song already exists in Firestore
    final doc = await _songsCollection.doc(song.id).get();
    
    // Convert local createdAt to Timestamp
    final createdAtTimestamp = Timestamp.fromDate(song.createdAt);
    
    if (doc.exists) {
      // Update existing song - use local createdAt
      await _songsCollection.doc(song.id).update({
        'title': song.title,
        'artistNames': song.artistNames,
        'album': song.album,
        'year': song.year,
        'content': song.content,
        'key': song.key,
        'capo': song.capo,
        'tempo': song.tempo,
        'category': song.category,
        'createdAt': createdAtTimestamp,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      // Create new song - use local createdAt
      await _songsCollection.doc(song.id).set({
        'title': song.title,
        'artistNames': song.artistNames,
        'album': song.album,
        'year': song.year,
        'content': song.content,
        'key': song.key,
        'capo': song.capo,
        'tempo': song.tempo,
        'category': song.category,
        'createdAt': createdAtTimestamp,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  /// Upload multiple songs to Firestore (for admin use)
  Future<int> uploadAllLocalSongs() async {
    final localSongs = await _localRepository.getAllSongs();
    int uploadedCount = 0;

    for (final song in localSongs) {
      try {
        await uploadSong(song);
        uploadedCount++;
      } catch (e) {
        // Skip failed uploads
      }
    }

    return uploadedCount;
  }

  /// Get count of songs in cloud
  Future<int> getCloudSongCount() async {
    final snapshot = await _songsCollection.count().get();
    return snapshot.count ?? 0;
  }
}
