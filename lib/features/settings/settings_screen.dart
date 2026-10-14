import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../../data/repositories/songs_repository.dart';
import '../../data/services/firestore_service.dart';
import '../../domain/models/song.dart' show SongModel;

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isExporting = false;
  bool _isImporting = false;
  bool _isImportingFiles = false;
  bool _isSyncingFromCloud = false;
  bool _isUploadingToCloud = false;

  Future<void> _exportBackup() async {
    setState(() => _isExporting = true);

    try {
      final repository = ref.read(songsRepositoryProvider);
      final songs = await repository.getAllSongs();

      final backup = {
        'version': 1,
        'exportedAt': DateTime.now().toIso8601String(),
        'songs': songs.map((s) => s.toJson()).toList(),
      };

      final jsonString = const JsonEncoder.withIndent('  ').convert(backup);

      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${directory.path}/chordbook_backup_$timestamp.json');
      await file.writeAsString(jsonString);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Backup saved to: ${file.path}'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Future<void> _importBackup() async {
    setState(() => _isImporting = true);

    try {
      final directory = await getApplicationDocumentsDirectory();
      final files = directory
          .listSync()
          .whereType<File>()
          .where((f) => f.path.contains('chordbook_backup_'))
          .toList();

      if (files.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No backup files found')),
          );
        }
        return;
      }

      // Sort by modification time, newest first
      files.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));

      if (!mounted) return;

      final selectedFile = await showDialog<File>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Select Backup'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: files.length,
              itemBuilder: (context, index) {
                final file = files[index];
                final name = file.path.split('/').last;
                final modified = file.statSync().modified;
                return ListTile(
                  title: Text(name, style: const TextStyle(fontSize: 12)),
                  subtitle: Text('Modified: ${modified.toString().split('.')[0]}'),
                  onTap: () => Navigator.of(context).pop(file),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );

      if (selectedFile == null) return;

      final jsonString = await selectedFile.readAsString();
      final backup = jsonDecode(jsonString) as Map<String, dynamic>;
      final songsJson = backup['songs'] as List<dynamic>;

      final repository = ref.read(songsRepositoryProvider);
      int imported = 0;

      for (final songJson in songsJson) {
        final song = SongModel.fromJson(songJson as Map<String, dynamic>);
        final existing = await repository.getSongById(song.id);

        if (existing == null) {
          await repository.createSong(
            title: song.title,
            content: song.content,
            album: song.album,
            year: song.year,
            key: song.key,
            capo: song.capo,
            tempo: song.tempo,
            artistNames: song.artistNames,
          );
          imported++;
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Imported $imported new songs')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isImporting = false);
      }
    }
  }

  Future<void> _importFromFiles() async {
    setState(() => _isImportingFiles = true);

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: true,
      );

      if (result == null || result.files.isEmpty) {
        return;
      }

      final repository = ref.read(songsRepositoryProvider);
      int imported = 0;
      int failed = 0;

      for (final platformFile in result.files) {
        try {
          final file = File(platformFile.path!);
          final content = await file.readAsString();
          final fileName = platformFile.name;
          final extension = fileName.split('.').last.toLowerCase();

          if (extension == 'json') {
            // Try to parse as ChordBook backup JSON
            final data = jsonDecode(content);
            if (data is Map && data.containsKey('songs')) {
              // It's a backup file
              final songsJson = data['songs'] as List<dynamic>;
              for (final songJson in songsJson) {
                final song = SongModel.fromJson(songJson as Map<String, dynamic>);
                final existing = await repository.getSongById(song.id);
                if (existing == null) {
                  await repository.createSong(
                    title: song.title,
                    content: song.content,
                    album: song.album,
                    year: song.year,
                    key: song.key,
                    capo: song.capo,
                    tempo: song.tempo,
                    artistNames: song.artistNames,
                  );
                  imported++;
                }
              }
            } else if (data is Map && data.containsKey('title')) {
              // Single song JSON
              final song = SongModel.fromJson(data as Map<String, dynamic>);
              await repository.createSong(
                title: song.title,
                content: song.content,
                album: song.album,
                year: song.year,
                key: song.key,
                capo: song.capo,
                tempo: song.tempo,
                artistNames: song.artistNames,
              );
              imported++;
            }
          } else {
            // ChordPro or text file - import as song content
            final title = _extractTitle(content) ?? 
                fileName.replaceAll(RegExp(r'\.(txt|cho|chopro|chordpro)$'), '');
            final artist = _extractArtist(content);
            
            await repository.createSong(
              title: title,
              content: content,
              artistNames: artist != null ? [artist] : [],
            );
            imported++;
          }
        } catch (e) {
          failed++;
          debugPrint('Failed to import ${platformFile.name}: $e');
        }
      }

      if (mounted) {
        String message = 'Imported $imported song(s)';
        if (failed > 0) {
          message += ', $failed failed';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isImportingFiles = false);
      }
    }
  }

  /// Parses text content to extract title, artist, and clean content
  /// Supports formats:
  /// 1. ChordPro: {title: Song Name} {artist: Artist Name}
  /// 2. Plain text first line: "Song Name - Artist Name"
  /// 3. Plain text first line: "Song Name" (no artist)
  Map<String, String?> _parseTextContent(String content) {
    String? title;
    String? artist;
    String cleanContent = content;
    
    // First try ChordPro format
    final chordProTitle = RegExp(r'\{(?:title|t):\s*([^}]+)\}', caseSensitive: false)
        .firstMatch(content);
    final chordProArtist = RegExp(r'\{(?:artist|a):\s*([^}]+)\}', caseSensitive: false)
        .firstMatch(content);
    
    if (chordProTitle != null) {
      title = chordProTitle.group(1)?.trim();
    }
    if (chordProArtist != null) {
      artist = chordProArtist.group(1)?.trim();
    }
    
    // If no ChordPro title found, try parsing first line as "Title - Artist"
    if (title == null) {
      final lines = content.split('\n');
      if (lines.isNotEmpty) {
        final firstLine = lines.first.trim();
        
        // Check for "Title - Artist" format
        if (firstLine.contains(' - ')) {
          final parts = firstLine.split(' - ');
          title = parts[0].trim();
          if (parts.length > 1 && artist == null) {
            artist = parts.sublist(1).join(' - ').trim();
          }
        } else if (firstLine.isNotEmpty && !firstLine.startsWith('[') && 
                   !RegExp(r'^[A-G][#b]?m?\s').hasMatch(firstLine) &&
                   !firstLine.toLowerCase().startsWith('capo')) {
          // First line looks like a title (not a chord line, section marker, or capo)
          title = firstLine;
        }
      }
    }
    
    return {
      'title': title,
      'artist': artist,
      'content': cleanContent,
    };
  }

  String? _extractTitle(String content) {
    return _parseTextContent(content)['title'];
  }

  String? _extractArtist(String content) {
    return _parseTextContent(content)['artist'];
  }

  Future<void> _syncFromCloud() async {
    setState(() => _isSyncingFromCloud = true);

    try {
      final firestoreService = ref.read(firestoreServiceProvider);
      final result = await firestoreService.syncFromCloud();
      final added = result['added'] ?? 0;
      final updated = result['updated'] ?? 0;

      if (mounted) {
        String message = '';
        if (added > 0 && updated > 0) {
          message = 'Added $added, updated $updated songs';
        } else if (added > 0) {
          message = 'Added $added new songs';
        } else if (updated > 0) {
          message = 'Updated $updated songs';
        } else {
          message = 'All songs are up to date';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sync failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncingFromCloud = false);
      }
    }
  }

  Future<void> _uploadToCloud() async {
    // Request PIN first
    final pinController = TextEditingController();
    bool? pinEntered;
    
    try {
      pinEntered = await showDialog<bool>(
        context: context,
        barrierDismissible: true,
        builder: (context) => AlertDialog(
          title: const Text('Enter PIN'),
          content: TextField(
            controller: pinController,
            keyboardType: TextInputType.number,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'PIN',
              hintText: 'Enter PIN to upload',
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (pinController.text == '1915') {
                  Navigator.of(context).pop(true);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Incorrect PIN')),
                  );
                  Navigator.of(context).pop(false);
                }
              },
              child: const Text('Verify'),
            ),
          ],
        ),
      );
    } finally {
      pinController.dispose();
    }

    if (pinEntered != true) return;

    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Upload to Cloud'),
        content: const Text(
          'This will upload all your local songs to the cloud database. '
          'Other users will be able to sync these songs. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Upload'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isUploadingToCloud = true);

    try {
      final firestoreService = ref.read(firestoreServiceProvider);
      final uploaded = await firestoreService.uploadAllLocalSongs();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Uploaded $uploaded songs to cloud')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingToCloud = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          const _SectionHeader(title: 'Backup & Restore'),
          ListTile(
            leading: const Icon(Icons.upload),
            title: const Text('Export Backup'),
            subtitle: const Text('Save all songs to a JSON file'),
            trailing: _isExporting
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.chevron_right),
            onTap: _isExporting ? null : _exportBackup,
          ),
          ListTile(
            leading: const Icon(Icons.download),
            title: const Text('Import Backup'),
            subtitle: const Text('Restore from app backup file'),
            trailing: _isImporting
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.chevron_right),
            onTap: _isImporting ? null : _importBackup,
          ),
          const Divider(),
          const _SectionHeader(title: 'Import'),
          ListTile(
            leading: const Icon(Icons.file_open),
            title: const Text('Import from Files'),
            subtitle: const Text('Import .json, .txt, .cho, .chopro files'),
            trailing: _isImportingFiles
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.chevron_right),
            onTap: _isImportingFiles ? null : _importFromFiles,
          ),
          const Divider(),
          const _SectionHeader(title: 'Cloud Sync'),
          ListTile(
            leading: const Icon(Icons.cloud_download),
            title: const Text('Sync from Cloud'),
            subtitle: const Text('Download new songs from cloud database'),
            trailing: _isSyncingFromCloud
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.chevron_right),
            onTap: _isSyncingFromCloud ? null : _syncFromCloud,
          ),
          ListTile(
            leading: const Icon(Icons.cloud_upload),
            title: const Text('Upload to Cloud'),
            subtitle: const Text('Share your songs with all users'),
            trailing: _isUploadingToCloud
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.chevron_right),
            onTap: _isUploadingToCloud ? null : _uploadToCloud,
          ),
          const Divider(),
          const _SectionHeader(title: 'About'),
          const ListTile(
            leading: Icon(Icons.info),
            title: Text('ChordBook'),
            subtitle: Text('Version 1.0.0'),
          ),
          const ListTile(
            leading: Icon(Icons.code),
            title: Text('Developed by Rajat Garg'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}
