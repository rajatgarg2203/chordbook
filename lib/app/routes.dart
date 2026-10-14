import 'package:flutter/material.dart';
import '../features/library/library_screen.dart';
import '../features/song_detail/song_detail_screen.dart';
import '../features/editor/editor_screen.dart';
import '../features/settings/settings_screen.dart';

class AppRoutes {
  static const String library = '/';
  static const String songDetail = '/song';
  static const String editor = '/editor';
  static const String settings = '/settings';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case library:
        return MaterialPageRoute(builder: (_) => const LibraryScreen());

      case songDetail:
        final songId = settings.arguments as String?;
        return MaterialPageRoute(
          builder: (_) => SongDetailScreen(songId: songId),
        );

      case editor:
        final songId = settings.arguments as String?;
        return MaterialPageRoute(
          builder: (_) => EditorScreen(songId: songId),
        );

      case AppRoutes.settings:
        return MaterialPageRoute(builder: (_) => const SettingsScreen());

      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(
              child: Text('No route defined for ${settings.name}'),
            ),
          ),
        );
    }
  }
}
