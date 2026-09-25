import 'package:diegema/core/utils/librivox_description.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fixtures/librivox_description_fixtures.dart';

String _fixture(String key) => libriVoxDescriptionFixtures[key]!;

void main() {
  group('parseLibriVoxDescription — edge cases', () {
    test('empty input returns an empty result and never throws', () {
      final result = parseLibriVoxDescription('');
      expect(result.summary, isEmpty);
      expect(result.contents, isEmpty);
      expect(result.readBy, isNull);
      expect(result.summaryBy, isNull);
      expect(result.formats, isNull);
      expect(result.hasStructure, isFalse);
    });

    test('whitespace-only input returns an empty result', () {
      final result = parseLibriVoxDescription(_fixture('whitespaceOnly'));
      expect(result.summary, isEmpty);
      expect(result.hasStructure, isFalse);
    });

    test('never throws on adversarial input', () {
      final adversarial = <String>[
        '.' * 500,
        'Read by',
        'Read in by',
        '((((',
        '1. 2. 3.',
        'LibriVox recording of',
        '\n\n\n\n',
        'Read in English by ${'X;' * 500}',
      ];
      for (final input in adversarial) {
        expect(() => parseLibriVoxDescription(input), returnsNormally,
            reason: 'input: $input');
      }
    });

    test('a single short sentence is not fragmented', () {
      final result = parseLibriVoxDescription('A short book.');
      expect(result.summary, ['A short book.']);
    });
  });

  group('parseLibriVoxDescription — readBy / language', () {
    test(
        'extracts a single narrator with no period after the name '
        '(castleRackrent)', () {
      final result = parseLibriVoxDescription(_fixture('castleRackrent'));
      expect(result.readBy, 'NoelBadrian');
      expect(result.language, 'English');
    });

    test('extracts a single narrator, plain "Read by" form (typeWriterGirl)',
        () {
      final result = parseLibriVoxDescription(_fixture('typeWriterGirl'));
      expect(result.readBy, 'Grant Hurlock');
      expect(result.language, isNull);
    });

    test('extracts a long semicolon-separated narrator list (toTheClouds)', () {
      final result = parseLibriVoxDescription(_fixture('toTheClouds'));
      expect(result.readBy, contains('Alan Mapstone'));
      expect(result.readBy, contains('Stacey Malcolm'));
      expect(result.language, 'English');
    });

    test(
        '"LibriVox Volunteers" / multi-reader placeholder is captured '
        '(shortPoetryCollection277)', () {
      final result =
          parseLibriVoxDescription(_fixture('shortPoetryCollection277'));
      expect(result.readBy, 'LibriVox Volunteers');
      expect(result.language, 'English');
    });

    test(
        'non-English "Read in <Lang> by" with no period after the name '
        '(historiaDeHerodoto3)', () {
      final result = parseLibriVoxDescription(_fixture('historiaDeHerodoto3'));
      expect(result.readBy, 'Tux');
      expect(result.language, 'Spanish');
    });

    test(
        'a fully localized (Dutch) opener has no "Read...by" clause to '
        'find, so readBy/language stay null (zesNovellenEmants)', () {
      final result = parseLibriVoxDescription(_fixture('zesNovellenEmants'));
      expect(result.readBy, isNull);
      expect(result.language, isNull);
    });

    test(
        'narrators only named in free prose are not misdetected as a '
        '"Read...by" clause (lettersOfTwoBrides)', () {
      final result = parseLibriVoxDescription(_fixture('lettersOfTwoBrides'));
      expect(result.readBy, isNull);
    });

    test(
        'a description with no LibriVox template at all has no readBy '
        '(historyOfEngland05)', () {
      final result = parseLibriVoxDescription(_fixture('historyOfEngland05'));
      expect(result.readBy, isNull);
      expect(result.language, isNull);
    });
  });

  group('parseLibriVoxDescription — summaryBy', () {
    test('parenthesised "(Summary by X)" is extracted (typeWriterGirl)', () {
      final result = parseLibriVoxDescription(_fixture('typeWriterGirl'));
      expect(result.summaryBy, 'Grant Hurlock');
    });

    test(
        'parenthesised "(Summary from Wikipedia)" is extracted '
        '(toTheClouds)', () {
      final result = parseLibriVoxDescription(_fixture('toTheClouds'));
      expect(result.summaryBy, 'Wikipedia');
    });

    test('trailing "- Summary by X" with no parentheses (castleRackrent)', () {
      final result = parseLibriVoxDescription(_fixture('castleRackrent'));
      expect(result.summaryBy, 'Noel Badrian');
    });

    test(
        'trailing "Summary by X" with no dash and no parentheses '
        '(historyOfEngland05)', () {
      final result = parseLibriVoxDescription(_fixture('historyOfEngland05'));
      expect(result.summaryBy, 'Jim Mowatt');
    });

    test('missing entirely, no summaryBy is invented (lettersOfTwoBrides)', () {
      final result = parseLibriVoxDescription(_fixture('lettersOfTwoBrides'));
      expect(result.summaryBy, isNull);
    });
  });

  group('parseLibriVoxDescription — contents', () {
    test(
        'a numbered list of 20 items is fully captured '
        '(multilingualShortWorks035)', () {
      final result =
          parseLibriVoxDescription(_fixture('multilingualShortWorks035'));
      expect(result.contents, hasLength(20));
      expect(result.contents.first, contains('Voyelles'));
      expect(result.contents.last, contains('Wuhin'));
    });

    test(
        'an "includes:" semicolon-separated list is captured '
        '(firstChapterCollection002)', () {
      final result =
          parseLibriVoxDescription(_fixture('firstChapterCollection002'));
      expect(result.contents, hasLength(5));
      expect(result.contents, contains(contains('Anna Karenina')));
      expect(result.contents, contains(contains('Book of Mormon')));
    });

    test('a normal novel has no contents list (castleRackrent)', () {
      final result = parseLibriVoxDescription(_fixture('castleRackrent'));
      expect(result.contents, isEmpty);
    });

    test('a year ("...in 1800.") never triggers a false numbered list', () {
      final result = parseLibriVoxDescription(_fixture('castleRackrent'));
      expect(result.contents, isEmpty);
    });
  });

  group('parseLibriVoxDescription — formats', () {
    test('"M4B Audiobook (141MB)" is parsed (castleRackrent)', () {
      final result = parseLibriVoxDescription(_fixture('castleRackrent'));
      expect(result.formats, 'M4B audiobook · 141 MB');
    });

    test('lower-case "M4B audio book (155mb)" is parsed (typeWriterGirl)', () {
      final result = parseLibriVoxDescription(_fixture('typeWriterGirl'));
      expect(result.formats, 'M4B audiobook · 155 MB');
    });

    test(
        'missing entirely for a feed description with no tail '
        '(countOfMonteCristo)', () {
      final result = parseLibriVoxDescription(_fixture('countOfMonteCristo'));
      expect(result.formats, isNull);
    });
  });

  group('parseLibriVoxDescription — boilerplate stripping', () {
    test(
        'the "LibriVox recording of X by Y." opener never appears in the '
        'summary (castleRackrent)', () {
      final result = parseLibriVoxDescription(_fixture('castleRackrent'));
      final joined = result.summary.join(' ');
      expect(joined, isNot(contains('LibriVox recording of')));
    });

    test(
        'the "For further information..." tail never appears anywhere '
        '(typeWriterGirl)', () {
      final result = parseLibriVoxDescription(_fixture('typeWriterGirl'));
      final joined = result.summary.join(' ');
      expect(joined, isNot(contains('For further information')));
      expect(joined, isNot(contains('LibriVox catalog page')));
      expect(joined, isNot(contains('become a volunteer reader')));
    });

    test(
        'real prose that merely starts with the word "LibriVox" is kept '
        '(toTheClouds)', () {
      final result = parseLibriVoxDescription(_fixture('toTheClouds'));
      final joined = result.summary.join(' ');
      expect(joined, contains('15 recordings of To The Clouds'));
    });

    test('nothing is lost: every fixture round-trips to a non-empty result',
        () {
      for (final entry in libriVoxDescriptionFixtures.entries) {
        if (entry.key == 'empty' || entry.key == 'whitespaceOnly') continue;
        final result = parseLibriVoxDescription(entry.value);
        final totalLength = result.summary.join().length +
            result.contents.join().length +
            (result.readBy?.length ?? 0) +
            (result.summaryBy?.length ?? 0);
        expect(totalLength, greaterThan(0), reason: entry.key);
      }
    });
  });

  group('parseLibriVoxDescription — paragraph splitting', () {
    test(
        'existing blank-line paragraph breaks are honoured '
        '(countOfMonteCristo)', () {
      final result = parseLibriVoxDescription(_fixture('countOfMonteCristo'));
      expect(result.summary.length, greaterThanOrEqualTo(3));
    });

    test(
        'a long single block is re-chunked into readable paragraphs '
        '(historyOfEngland05)', () {
      final result = parseLibriVoxDescription(_fixture('historyOfEngland05'));
      expect(result.summary.length, greaterThan(1));
      for (final paragraph in result.summary) {
        expect(paragraph, isNotEmpty);
      }
    });

    test('"Mr."/"St."/initials never split a paragraph mid-name', () {
      const text =
          'Dr. J. R. Smith met St. Peter and Mrs. Jones in the market. '
          'They all agreed it was a fine day. Later, Mr. Smith went home. '
          'It had been a long journey for everyone involved that week.';
      final result = parseLibriVoxDescription(text);
      final joined = result.summary.join(' ');
      expect(joined, contains('Dr. J. R. Smith met St. Peter'));
    });
  });
}
