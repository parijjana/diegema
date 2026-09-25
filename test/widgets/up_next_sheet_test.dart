import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:diegema/domain/models/audiobook.dart';
import 'package:diegema/services/audio_playback_service.dart';
import 'package:diegema/widgets/up_next_sheet.dart';

import '../support/fake_playback_service.dart';
import '../support/test_harness.dart';

/// Widget coverage for the redesigned "Up next" sheet: the played/current/
/// upcoming row states, the header summary and the sticky footer's
/// skip-to-next behaviour.
///
/// Deliberately uses plain `tester.pump()`, not the `pumpFrames` helper
/// most screen tests share: `pumpFrames` runs a real async delay on every
/// step so drift's futures can resolve, but that same delay is enough for
/// `FakePlaybackService`'s *inherited*, un-faked `_player.positionStream`
/// subscription to deliver a real (zero) position and silently clobber the
/// `positionNotifier.value` this file sets up by hand. Nothing here reads
/// the database, so there is nothing for a real async gap to wait on.
void main() {
  late FakePlaybackService audio;
  late UnifiedAudiobook book;

  setUp(() {
    audio = FakePlaybackService();
    book = UnifiedAudiobook(
      id: 'b',
      title: 'Frankenstein',
      author: 'Mary Shelley',
      description: 'desc',
      source: 'LibriVox',
      origin: 'librivox',
      chapters: [
        AudiobookChapter(
          id: 'b-0',
          title: 'Letter 1',
          audioPathOrUrl: 'https://example.invalid/0.mp3',
          durationSeconds: 552, // 09:12
          isStream: true,
        ),
        AudiobookChapter(
          id: 'b-1',
          title: 'Letter 2',
          audioPathOrUrl: 'https://example.invalid/1.mp3',
          durationSeconds: 1500,
          isStream: true,
        ),
        AudiobookChapter(
          id: 'b-2',
          title: 'Letter 3',
          audioPathOrUrl: 'https://example.invalid/2.mp3',
          durationSeconds: 185,
          isStream: true,
        ),
      ],
    );
    // Chapter 2 (index 1) is current, 38% through a 1500s chapter.
    audio.currentBookNotifier.value = book;
    audio.chapterIndexNotifier.value = 1;
    audio.positionNotifier.value = const Duration(seconds: 570);
    audio.durationNotifier.value = const Duration(seconds: 1500);
  });

  tearDown(() async {
    await audio.dispose().catchError((_) {});
  });

  Widget wrap() => MaterialApp(
        home: Scaffold(
          body: UpNextSheet(book: book, audioService: audio),
        ),
      );

  testWidgets('shows played, current and upcoming rows with the right state',
      (tester) async {
    await setSurface(tester, const Size(390, 844));
    await tester.pumpWidget(wrap());
    await tester.pump();

    // Played: dimmed with its duration.
    expect(find.text('Played · 09:12'), findsOneWidget);

    // Current: highlighted, "Playing · <mm:ss> left".
    expect(find.text('Playing · 15:30 left'), findsOneWidget);
    expect(find.byIcon(Icons.graphic_eq_rounded), findsOneWidget);

    // Upcoming: plain number and duration.
    expect(find.text('3'), findsOneWidget);
    expect(find.text('03:05'), findsOneWidget);
  });

  testWidgets('header summarises what is left', (tester) async {
    await setSurface(tester, const Size(390, 844));
    await tester.pumpWidget(wrap());
    await tester.pump();

    // One chapter (Letter 3, 185s) left after the current one.
    expect(find.text('1 of 3 left · 3 min'), findsOneWidget);
  });

  testWidgets('skip-to-next advances the queue without closing the sheet',
      (tester) async {
    await setSurface(tester, const Size(390, 844));
    await tester.pumpWidget(wrap());
    await tester.pump();

    final skip = find.widgetWithText(FilledButton, 'Skip to Letter 3');
    expect(skip, findsOneWidget);
    await tester.tap(skip);
    await tester.pump();

    expect(audio.chapterIndexNotifier.value, 2);
    // Still open — Up Next moved the queue, it did not dismiss.
    expect(find.text('Up next'), findsOneWidget);
    // Skip is gone now: chapter 3 (index 2) is the last chapter.
    expect(find.textContaining('Skip to'), findsNothing);
  });

  testWidgets('close dismisses the sheet', (tester) async {
    // Opened through `showUpNext` (a real pushed route), unlike the other
    // cases here: `Navigator.pop()` needs somewhere to pop *to*.
    Widget openable(BuildContext c, AudioPlaybackService svc) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => showUpNext(c, book: book, audioService: svc),
              child: const Text('Open'),
            ),
          ),
        );

    await setSurface(tester, const Size(390, 844));
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (context) => openable(context, audio)),
    ));
    await tester.pump();

    await tester.tap(find.text('Open'));
    // The modal bottom-sheet's own slide-in transition needs settling time,
    // beyond which the footer (holding Close) can still sit off the 844px
    // test surface and fail the tap's hit test.
    await tester.pumpAndSettle();
    expect(find.text('Up next'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Close'));
    await tester.pumpAndSettle();

    expect(find.text('Up next'), findsNothing);
  });

  testWidgets('a played chapter can be jumped back to', (tester) async {
    await setSurface(tester, const Size(390, 844));
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () =>
                  showUpNext(context, book: book, audioService: audio),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Letter 1'));
    await tester.pumpAndSettle();

    expect(audio.loadCalls, 1);
    expect(audio.chapterIndexNotifier.value, 0);
    expect(find.text('Up next'), findsNothing);
  });
}
