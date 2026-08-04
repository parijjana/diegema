import 'package:flutter/material.dart';
import 'database/app_database.dart';
import 'main.dart';

class AudiobookApp extends StatefulWidget {
  const AudiobookApp({super.key});

  @override
  State<AudiobookApp> createState() => _AudiobookAppState();
}

class _AudiobookAppState extends State<AudiobookApp> {
  late final AppDatabase _db;
  bool _isDarkMode = false;

  @override
  void initState() {
    super.initState();
    _db = AppDatabase();
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
      ),
    );
  }
}
