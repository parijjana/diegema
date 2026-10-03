import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:diegema/database/app_database.dart';
import 'package:diegema/domain/models/audiobook.dart';
import 'package:diegema/services/book_removal.dart';
import 'package:diegema/theme/app_theme.dart';
import 'package:diegema/widgets/library_book_detail_overlay.dart';

import '../support/fake_playback_service.dart';

void main() {
  Future<bool?> open(WidgetTester tester, BookRemovalPlan plan) async {
    bool? result;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async => result =
                await showRemoveBookDialog(context, title: 'Emma', plan: plan),
            child: const Text('go'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('library-folder book says its files are not touched',
      (tester) async {
    await open(tester, const BookRemovalPlan(filesUntouched: true));
    expect(find.textContaining('Files in your library folder are not touched'),
        findsOneWidget);
    expect(find.textContaining('Downloaded files are deleted'), findsNothing);
  });

  testWidgets('download says files are deleted with their size',
      (tester) async {
    await open(tester,
        const BookRemovalPlan(deletePaths: ['/x'], bytes: 5 * 1024 * 1024));
    expect(find.textContaining('Downloaded files are deleted (5.0 MB)'),
        findsOneWidget);
  });

  testWidgets('cancel returns false, remove returns true', (tester) async {
    bool? result;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async => result = await showRemoveBookDialog(context,
                title: 'Emma', plan: const BookRemovalPlan()),
            child: const Text('go'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(result, isFalse);

    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });

  testWidgets('overlay: confirming removes the book from the DB',
      (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final book = UnifiedAudiobook(
      id: 'emma',
      title: 'Emma',
      author: 'Austen',
      description: '',
      chapters: [
        AudiobookChapter(
            id: 'c0',
            title: 'one',
            audioPathOrUrl: 'https://x/y.mp3',
            durationSeconds: 1,
            isStream: true),
      ],
    );
    await tester.runAsync(() => db.saveAudiobook(book));
    final audio = FakePlaybackService();
    var removed = false;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: Navigator(
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            builder: (_) => Scaffold(
              body: LibraryBookDetailOverlay(
                book: book,
                audioService: audio,
                db: db,
                documentsPath: '/nonexistent-docs',
                onRemoved: () => removed = true,
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.byTooltip('More actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove from library…'));
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pumpAndSettle();
    expect(find.textContaining('Remove "Emma"?'), findsOneWidget);
    await tester.tap(find.text('Remove'));
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pumpAndSettle();
    expect(removed, isTrue);
    expect(await tester.runAsync(() => db.getAudiobook('emma')), isNull);
    unawaited(audio.dispose().catchError((_) {}));
  });
}
