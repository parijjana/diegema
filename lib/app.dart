import 'package:flutter/material.dart';
import 'database/app_database.dart';
import 'main.dart';
import 'services/librivox_service.dart';

/// Root widget. [database] and [libriVoxService] are optional injection
/// points so tests can supply an in-memory database and a mocked HTTP
/// client instead of the real path_provider-backed database and live
/// librivox.org network calls that the defaults use.
class AudiobookApp extends StatefulWidget {
  final AppDatabase? database;
  final LibriVoxService? libriVoxService;

  const AudiobookApp({super.key, this.database, this.libriVoxService});

  @override
  State<AudiobookApp> createState() => _AudiobookAppState();
}

class _AudiobookAppState extends State<AudiobookApp> {
  late final AppDatabase _db;
  bool _isDarkMode = false;

  @override
  void initState() {
    super.initState();
    _db = widget.database ?? AppDatabase();
  }

  @override
  void dispose() {
    _db.close();
    super.dispose();
  }

  ThemeData _buildTheme(bool isDark) {
    if (!isDark) {
      return ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF8F8F5),
        fontFamily: 'Inter',
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF2E6D7D),
          secondary: Color(0xFFCC4D22),
          onPrimary: Colors.white,
          surface: Colors.white,
          onSurface: Color(0xFF222222),
          outline: Color(0xFFE0DED6),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: Color(0xFFE0DED6)),
          ),
        ),
      );
    } else {
      return ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF101417),
        fontFamily: 'Inter',
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF2E6D7D),
          secondary: Color(0xFFCC4D22),
          onPrimary: Colors.white,
          surface: Color(0xFF181C20),
          onSurface: Color(0xFFE6E4DF),
          outline: Color(0xFF2E6D7D),
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF181C20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LibriVox Audiobook Player',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(_isDarkMode),
      home: HomeScreen(
        db: _db,
        isDarkMode: _isDarkMode,
        onToggleTheme: () => setState(() => _isDarkMode = !_isDarkMode),
        libriVoxService: widget.libriVoxService,
      ),
    );
  }
}
