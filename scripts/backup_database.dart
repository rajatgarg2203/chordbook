import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;
import '../lib/data/db/app_db.dart';
import '../lib/data/repositories/songs_repository.dart';

Future<void> main() async {
  print('Starting database backup...');
  
  // Initialize database
  final db = AppDatabase();
  final repository = SongsRepository(db);
  
  try {
    // Get all songs with their relationships
    final songs = await repository.getAllSongs();
    
    print('Found ${songs.length} songs to backup');
    
    // Convert to JSON format
    final songsJson = songs.map((song) {
      return {
        'id': song.id,
        'title': song.title,
        'artistNames': song.artistNames,
        'album': song.album,
        'year': song.year,
        'content': song.content,
        'key': song.key,
        'capo': song.capo,
        'tempo': song.tempo,
        'createdAt': song.createdAt.millisecondsSinceEpoch,
        'updatedAt': song.updatedAt.millisecondsSinceEpoch,
      };
    }).toList();
    
    // Create backup directory if it doesn't exist
    final backupDir = Directory('backups');
    if (!await backupDir.exists()) {
      await backupDir.create();
    }
    
    // Generate filename with timestamp
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.')[0];
    final filename = 'database_backup_$timestamp.json';
    final filePath = path.join(backupDir.path, filename);
    
    // Write to file
    final file = File(filePath);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(songsJson),
    );
    
    print('✓ Backup completed successfully!');
    print('Backup saved to: $filePath');
    print('Total songs backed up: ${songs.length}');
    
  } catch (e) {
    print('✗ Error during backup: $e');
    exit(1);
  } finally {
    await db.close();
  }
}
