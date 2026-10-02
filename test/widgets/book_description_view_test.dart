import 'package:diegema/theme/app_theme.dart';
import 'package:diegema/widgets/book_description_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fixtures/librivox_description_fixtures.dart';

Widget _host(Widget child) {
  return MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(
      body: SingleChildScrollView(child: child),
    ),
  );
}

void main() {
  group('BookDescriptionView', () {
    testWidgets(
        'renders About / Narrated by / Summary by for a normal '
        'novel (castleRackrent)', (tester) async {
      await tester.pumpWidget(_host(BookDescriptionView(
        description: libriVoxDescriptionFixtures['castleRackrent']!,
      )));

      expect(find.text('About'), findsOneWidget);
      expect(find.text('Narrated by'), findsOneWidget);
      expect(find.textContaining('NoelBadrian'), findsOneWidget);
      expect(find.textContaining('Summary by Noel Badrian'), findsOneWidget);

      // No boilerplate leaks into the rendered tree.
      expect(find.textContaining('LibriVox recording of'), findsNothing);
      expect(find.textContaining('For further information'), findsNothing);
    });

    testWidgets(
        'renders Contents as bullets, collapsed to 6 with a '
        '"Show all N" button, and expands on tap '
        '(multilingualShortWorks035)', (tester) async {
      await tester.pumpWidget(_host(BookDescriptionView(
        description: libriVoxDescriptionFixtures['multilingualShortWorks035']!,
      )));

      expect(find.text('Contents'), findsOneWidget);
      // Item #1 (French/Voyelles) is within the first 6 and should be
      // visible; item #20 (Yiddish/Wuhin) is not, until expanded.
      expect(find.textContaining('Voyelles'), findsOneWidget);
      expect(find.textContaining('Wuhin'), findsNothing);

      final showAllButton = find.widgetWithText(TextButton, 'Show all 20');
      expect(showAllButton, findsOneWidget);

      await tester.ensureVisible(showAllButton);
      await tester.tap(showAllButton);
      await tester.pumpAndSettle();

      expect(find.textContaining('Wuhin'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Show all 20'), findsNothing);
    });

    testWidgets(
        'renders "Narrated by" with the language suffix for a '
        'non-English recording (historiaDeHerodoto3)', (tester) async {
      await tester.pumpWidget(_host(BookDescriptionView(
        description: libriVoxDescriptionFixtures['historiaDeHerodoto3']!,
      )));

      expect(find.textContaining('Tux (Spanish)'), findsOneWidget);
    });

    testWidgets(
        'omits the language suffix for an English recording '
        '(castleRackrent)', (tester) async {
      await tester.pumpWidget(_host(BookDescriptionView(
        description: libriVoxDescriptionFixtures['castleRackrent']!,
      )));

      expect(find.textContaining('NoelBadrian (English)'), findsNothing);
    });

    testWidgets(
        'falls back to plain paragraphs with no section headings '
        'when nothing structured was found', (tester) async {
      await tester.pumpWidget(_host(const BookDescriptionView(
        description: 'Just a short, unstructured description with no '
            'LibriVox template fields at all in it whatsoever here.',
      )));

      expect(find.text('About'), findsNothing);
      expect(find.text('Narrated by'), findsNothing);
      expect(find.text('Contents'), findsNothing);
      expect(find.textContaining('Just a short, unstructured'), findsOneWidget);
    });

    testWidgets('renders nothing for an empty description', (tester) async {
      await tester
          .pumpWidget(_host(const BookDescriptionView(description: '')));
      expect(find.byType(BookDescriptionView), findsOneWidget);
      expect(find.text('About'), findsNothing);
    });

    testWidgets('section headings are exposed as accessibility headers',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_host(BookDescriptionView(
        description: libriVoxDescriptionFixtures['castleRackrent']!,
      )));

      final aboutNode = tester.getSemantics(find.text('About'));
      expect(aboutNode.flagsCollection.isHeader, isTrue);

      handle.dispose();
    });

    testWidgets('compact mode still renders the same sections', (tester) async {
      await tester.pumpWidget(_host(BookDescriptionView(
        description: libriVoxDescriptionFixtures['castleRackrent']!,
        compact: true,
      )));

      expect(find.text('About'), findsOneWidget);
      expect(find.text('Narrated by'), findsOneWidget);
    });
  });
}
