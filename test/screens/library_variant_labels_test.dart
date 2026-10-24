// ignore_for_file: prefer_const_constructors
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:diegema/core/app_settings.dart';
import 'package:diegema/core/ui_preferences.dart';
import 'package:diegema/database/app_database.dart';
import 'package:diegema/domain/models/audiobook.dart';
import 'package:diegema/screens/library_screen.dart';
import 'package:diegema/services/audio_playback_service.dart';
import 'package:diegema/services/hidden_books_store.dart';
import 'package:diegema/theme/app_theme.dart';

import '../support/test_harness.dart';

/// Same-titled recordings and volumes must be tellable apart in every layout.
void main() {
  late AppDatabase db;
  late AudioPlaybackService audio;
  late AppSettings settings;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    audio = AudioPlaybackService(db: db);
    settings = AppSettings(
      preferences: UiPreferences(overrides: <String, Object>{}),
    );
  });

  tearDown(() async {
    await audio.dispose().catchError((_) {});
    await db.close();
  });

  const titles = {
    'a': 'The Happy Prince and Other Tales',
    'b': 'The Happy Prince and Other Tales, Version 2',
    'c': 'The Happy Prince and Other Tales (version 5)',
    'd': 'Short Science Fiction Collection Vol. 001',
    'e': 'Short Science Fiction Collection 032',
    'f': 'Short Science Fiction Collection 041',
    'g': 'Twenty Thousand Leagues Under the Sea',
  };

  Future<void> seed(AppDatabase db) async {
    for (final e in titles.entries) {
      await db.saveAudiobook(
        UnifiedAudiobook(
          id: e.key,
          title: e.value,
          author: 'Author',
          description: '',
          source: 'LibriVox',
          origin: 'librivox',
          chapters: [
            AudiobookChapter(
              id: '${e.key}-c0',
              title: 'C1',
              audioPathOrUrl: 'https://example.invalid/${e.key}.mp3',
              durationSeconds: 100,
              isStream: true,
            ),
          ],
        ),
      );
    }
  }

  Widget wrap(double scale) => SettingsScope(
        settings: settings,
        child: MaterialApp(
          theme: AppTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: Scaffold(
            body: LibraryScreen(
              db: db,
              audioService: audio,
              onGoToDiscover: () {},
              hiddenStore:
                  HiddenBooksStore(overrides: <String, List<String>>{}),
              scanLibrary: seed,
            ),
          ),
        ),
      );

  for (final layout in LibraryLayout.values) {
    for (final scale in [1.0, 2.0]) {
      for (final size in [const Size(390, 844), const Size(1200, 800)]) {
        testWidgets('${layout.name} @ ${size.width.toInt()}px x$scale', (
          tester,
        ) async {
          await settings.setLibraryLayout(layout);
          await setSurface(tester, size);
          await tester.pumpWidget(wrap(scale));
          await pumpFrames(tester);
          // Scroll each label into existence (lists build lazily).
          for (final label in [
            'Original',
            'Version 2',
            'Version 5',
            'Vol. 001',
            'Vol. 032',
            'Vol. 041',
          ]) {
            await tester.scrollUntilVisible(
              find.text(label),
              200,
              scrollable: find.byType(Scrollable).first,
            );
            expect(find.text(label), findsOneWidget, reason: label);
          }
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}
